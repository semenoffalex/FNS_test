# ------------------------------------------------------------------
# 05_groups.R  -- related-party groups (ADR-002, ADR-007)
# founder_id is the group key; shared address_hash upgrades a link to "strong".
# Group typology: profit-shifting -- entities in the same group with a wide
# spread of effective tax rates / margins (profit parked in low-tax members).
# ------------------------------------------------------------------

suppressPackageStartupMessages({
  library(dplyr)
})

build_groups <- function(cy, comp, config = CONFIG) {
  # collapse to company level: founder, address(es), mean ETR / margin, size
  by_company <- cy %>%
    group_by(company_id, founder_id) %>%
    summarise(
      address_hashes  = paste(sort(unique(address_hash)), collapse = "|"),
      mean_etr        = mean(etr, na.rm = TRUE),
      mean_op_margin  = mean(operating_margin, na.rm = TRUE),
      revenue_max     = max(revenue, na.rm = TRUE),
      taxes_total     = sum(taxes_paid, na.rm = TRUE),
      .groups = "drop"
    )

  groups <- by_company %>%
    group_by(founder_id) %>%
    summarise(
      n_companies   = dplyr::n_distinct(company_id),
      companies     = paste(sort(unique(company_id)), collapse = ", "),
      shares_address = any(duplicated(unlist(strsplit(address_hashes, "\\|")))),
      etr_spread    = suppressWarnings(diff(range(mean_etr, na.rm = TRUE))),
      margin_spread = suppressWarnings(diff(range(mean_op_margin, na.rm = TRUE))),
      group_revenue = sum(revenue_max, na.rm = TRUE),
      group_taxes   = sum(taxes_total, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    filter(n_companies >= 2) %>%
    mutate(
      link_strength = ifelse(shares_address, "strong", "founder_only"),
      etr_spread    = ifelse(is.finite(etr_spread), etr_spread, NA_real_),
      margin_spread = ifelse(is.finite(margin_spread), margin_spread, NA_real_)
    ) %>%
    arrange(desc(etr_spread), desc(group_revenue))

  attr(groups, "n_multi_company_founders") <- nrow(groups)
  groups
}
