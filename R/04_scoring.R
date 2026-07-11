# ------------------------------------------------------------------
# 04_scoring.R  -- composite risk score, materiality, and buckets (ADR-005)
# ------------------------------------------------------------------

suppressPackageStartupMessages({
  library(dplyr)
})

# Company-year composite = sum of tier-weighted severities across typologies.
score_company_year <- function(typ, config = CONFIG) {
  w1 <- config$tier_weights[["1"]]
  w2 <- config$tier_weights[["2"]]

  tier1_sev <- rowSums(sapply(TIER1_FLAGS, function(f) typ[[FLAG_SEV_MAP[[f]]]]))
  tier2_sev <- rowSums(sapply(TIER2_FLAGS, function(f) typ[[FLAG_SEV_MAP[[f]]]]))
  n_flags   <- rowSums(sapply(c(TIER1_FLAGS, TIER2_FLAGS), function(f) as.integer(typ[[f]])))
  n_tier1   <- rowSums(sapply(TIER1_FLAGS, function(f) as.integer(typ[[f]])))

  typ$cy_score  <- w1 * tier1_sev + w2 * tier2_sev
  typ$n_flags   <- n_flags
  typ$n_tier1   <- n_tier1
  typ
}

# Roll company-year scores up to one row per company; attach materiality.
score_company <- function(typ_scored, cy, config = CONFIG) {
  mat <- cy %>%
    group_by(company_id) %>%
    summarise(
      materiality      = max(pmax(operating_profit, 0, na.rm = TRUE), na.rm = TRUE),
      revenue_max      = max(revenue, na.rm = TRUE),
      taxes_paid_total = sum(taxes_paid, na.rm = TRUE),
      revenue_cv       = dplyr::first(revenue_cv),
      .groups = "drop"
    )

  flag_cols <- c(TIER1_FLAGS, TIER2_FLAGS)
  comp <- typ_scored %>%
    group_by(company_id, company_name) %>%
    summarise(
      okved_section = dplyr::first(.data[[config$group_col]]),
      composite     = sum(cy_score, na.rm = TRUE),
      n_flags       = sum(n_flags, na.rm = TRUE),
      n_tier1       = sum(n_tier1, na.rm = TRUE),
      across(all_of(flag_cols), ~ as.integer(any(.x))),
      .groups = "drop"
    ) %>%
    left_join(mat, by = "company_id")

  comp
}

# Assign priority buckets on the likelihood x materiality plane (ADR-005).
bucket_findings <- function(comp, config = CONFIG) {
  flagged <- comp$n_flags > 0
  lik_cut <- stats::quantile(comp$composite[flagged], config$likelihood_hi_q, na.rm = TRUE)
  mat_cut <- stats::quantile(comp$materiality, config$materiality_hi_q, na.rm = TRUE)
  if (!is.finite(lik_cut)) lik_cut <- 0
  if (!is.finite(mat_cut)) mat_cut <- 0

  hi_lik <- comp$composite >= lik_cut & flagged
  hi_mat <- comp$materiality >= mat_cut

  # "consistent" = low revenue volatility (stable trajectory), used for the signal bucket
  consistent <- !is.na(comp$revenue_cv) & comp$revenue_cv < 0.25

  bucket <- rep("not_flagged", nrow(comp))
  bucket[flagged & !hi_lik] <- "background"
  bucket[flagged & hi_lik & !hi_mat] <- "background"
  bucket[flagged & hi_lik & hi_mat]  <- "urgent"
  # high materiality but clean & stable => genuine economic signal, not anomaly
  bucket[!flagged & hi_mat & consistent] <- "economic_signal"

  comp$likelihood_high <- hi_lik
  comp$materiality_high <- hi_mat
  comp$bucket <- factor(bucket,
                        levels = c("urgent", "background", "economic_signal", "not_flagged"))
  comp %>% arrange(desc(bucket == "urgent"), desc(composite), desc(materiality))
}
