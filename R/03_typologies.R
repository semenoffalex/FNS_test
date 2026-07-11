# ------------------------------------------------------------------
# 03_typologies.R  -- typology detectors (ADR-003)
# Continuous metrics: robust sector-relative modified z-scores with
# small-cell fallback (ADR-004). Impossibilities: absolute boolean rules.
# ------------------------------------------------------------------

suppressPackageStartupMessages({
  library(dplyr)
})

# Modified z-score = 0.6745 * (x - median) / MAD. Robust to the outliers we hunt.
.modified_z <- function(x, center, spread) {
  z <- 0.6745 * (x - center) / spread
  z[!is.finite(z)] <- NA_real_
  z
}

# Robust z within `group`, falling back to global stats when a group cell is
# too small or degenerate (MAD == 0). Returns z and the fallback level used.
robust_z_by_group <- function(x, group, min_n = CONFIG$min_cell_size) {
  glob_center <- stats::median(x, na.rm = TRUE)
  glob_mad    <- stats::mad(x, na.rm = TRUE)
  if (!is.finite(glob_mad) || glob_mad == 0) {
    glob_mad <- stats::IQR(x, na.rm = TRUE) / 1.349
  }
  if (!is.finite(glob_mad) || glob_mad == 0) glob_mad <- NA_real_

  z     <- rep(NA_real_, length(x))
  level <- rep("global", length(x))

  for (g in unique(group)) {
    idx <- which(group == g)
    xv  <- x[idx]
    n   <- sum(is.finite(xv))
    center <- stats::median(xv, na.rm = TRUE)
    spread <- stats::mad(xv, na.rm = TRUE)
    use_group <- n >= min_n && is.finite(spread) && spread > 0
    if (use_group) {
      z[idx]     <- .modified_z(xv, center, spread)
      level[idx] <- "sector"
    } else {
      z[idx]     <- .modified_z(xv, glob_center, glob_mad)
      level[idx] <- "global"
    }
  }
  list(z = z, level = level)
}

# Each detector returns a logical flag + a severity (|z| or fixed) per company-year.
run_typologies <- function(cy, config = CONFIG) {
  g <- cy[[config$group_col]]
  thr <- config$robust_z_flag

  z_etr    <- robust_z_by_group(cy$etr, g)
  z_taxrev <- robust_z_by_group(cy$tax_to_revenue, g)
  z_rph    <- robust_z_by_group(cy$revenue_per_head, g)
  z_opm    <- robust_z_by_group(cy$operating_margin, g)
  z_gm     <- robust_z_by_group(cy$gross_margin, g)
  z_div    <- robust_z_by_group(cy$dividend_payout, g)
  z_pph    <- robust_z_by_group(cy$payroll_per_head, g)
  z_yoy    <- robust_z_by_group(cy$max_abs_revenue_yoy, g)
  z_rev    <- robust_z_by_group(cy$revenue, g)

  false_na <- function(v) { v[is.na(v)] <- FALSE; v }
  # magnitude severity: |z| capped, NA -> 0
  mag <- function(v) { v <- abs(v); v[!is.finite(v)] <- 0; pmin(v, config$severity_cap) }
  # low-tail severity: magnitude of the negative part only
  lowmag <- function(v) { v <- abs(pmin(v, 0)); v[!is.finite(v)] <- 0; pmin(v, config$severity_cap) }

  out <- cy %>% transmute(company_id, company_name, year, !!config$group_col := .data[[config$group_col]])

  # ---- Tier 1 ----
  # 1. Low effective tax rate (low tail); corroborated by low tax-to-revenue
  out$flag_low_etr <- false_na(z_etr$z <= -thr | z_taxrev$z <= -thr)
  out$sev_low_etr  <- ifelse(out$flag_low_etr, pmax(lowmag(z_etr$z), lowmag(z_taxrev$z)), 0)

  # 2. Shell / transit: high revenue-per-head AND tiny headcount
  out$flag_shell <- false_na(z_rph$z >= thr & cy$headcount <= config$shell_headcount_max)
  out$sev_shell  <- ifelse(out$flag_shell, mag(z_rph$z), 0)

  # 3. Dividend stripping: high payout ratio OR dividends exceed net profit (absolute)
  div_gt_net <- false_na(cy$dividends_paid > cy$net_profit & cy$dividends_paid > 0)
  out$flag_dividend <- false_na(z_div$z >= thr) | div_gt_net
  out$sev_dividend  <- ifelse(out$flag_dividend,
                              pmax(mag(z_div$z), ifelse(div_gt_net, config$robust_z_flag, 0)), 0)

  # 4. Margin anomaly vs sector (either tail, operating or gross)
  out$flag_margin <- false_na(abs(z_opm$z) >= thr | abs(z_gm$z) >= thr)
  out$sev_margin  <- ifelse(out$flag_margin, pmax(mag(z_opm$z), mag(z_gm$z)), 0)

  # ---- Tier 2 ----
  # 5. Accounting-identity violations (absolute, relative tolerance)
  out$flag_identity <- false_na(cy$id_gross_resid > config$identity_tol |
                                cy$id_op_resid    > config$identity_tol)
  out$sev_identity  <- ifelse(out$flag_identity, config$robust_z_flag, 0)

  # 6. Sudden YoY revenue jump/collapse
  out$flag_yoy <- false_na(z_yoy$z >= config$yoy_flag_z)
  out$sev_yoy  <- ifelse(out$flag_yoy, mag(z_yoy$z), 0)

  # 7. Young firm with very large revenue
  out$flag_young_big <- false_na(cy$company_age <= config$young_age_max & z_rev$z >= thr)
  out$sev_young_big  <- ifelse(out$flag_young_big, mag(z_rev$z), 0)

  # 8. Wage anomalies (payroll per head either tail)
  out$flag_wage <- false_na(abs(z_pph$z) >= thr)
  out$sev_wage  <- ifelse(out$flag_wage, mag(z_pph$z), 0)

  # keep benchmark levels for auditability
  out$etr_bench_level <- z_etr$level
  out
}

TIER1_FLAGS <- c("flag_low_etr", "flag_shell", "flag_dividend", "flag_margin")
TIER2_FLAGS <- c("flag_identity", "flag_yoy", "flag_young_big", "flag_wage")
FLAG_SEV_MAP <- c(
  flag_low_etr = "sev_low_etr", flag_shell = "sev_shell",
  flag_dividend = "sev_dividend", flag_margin = "sev_margin",
  flag_identity = "sev_identity", flag_yoy = "sev_yoy",
  flag_young_big = "sev_young_big", flag_wage = "sev_wage"
)
