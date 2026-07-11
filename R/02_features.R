# ------------------------------------------------------------------
# 02_features.R  -- company-year ratios and company-panel features
# ------------------------------------------------------------------

suppressPackageStartupMessages({
  library(dplyr)
})

safe_ratio <- function(num, den, den_positive_only = TRUE) {
  out <- num / den
  bad <- if (den_positive_only) den <= 0 | is.na(den) else den == 0 | is.na(den)
  out[bad] <- NA_real_
  out
}

# --- company-year level ratios ---
build_company_year_features <- function(dat, config = CONFIG) {
  dat %>%
    mutate(
      company_age      = year - ogrn_year,
      etr              = safe_ratio(taxes_paid, operating_profit),          # ADR-005 primary, NA if op<=0
      tax_to_revenue   = safe_ratio(taxes_paid, revenue),                   # secondary corroborator
      gross_margin     = safe_ratio(gross_profit, revenue),
      operating_margin = safe_ratio(operating_profit, revenue),
      net_margin       = safe_ratio(net_profit, revenue),
      revenue_per_head = safe_ratio(revenue, headcount),
      payroll_per_head = safe_ratio(payroll_fund, headcount),
      dividend_payout  = safe_ratio(dividends_paid, net_profit),            # NA if net<=0
      # accounting-identity residuals (relative), see ADR-004 / Tier-2
      id_gross_resid   = safe_ratio(abs((revenue - cost_of_goods) - gross_profit), abs(revenue), FALSE),
      id_op_resid      = safe_ratio(abs((gross_profit - opex) - operating_profit), abs(revenue), FALSE)
    )
}

# --- company-panel (across 2023-2025) features ---
build_company_panel_features <- function(cy) {
  cy %>%
    arrange(company_id, year) %>%
    group_by(company_id) %>%
    mutate(
      revenue_yoy = (revenue - dplyr::lag(revenue)) / dplyr::lag(revenue)
    ) %>%
    summarise(
      n_years            = dplyr::n(),
      max_abs_revenue_yoy = suppressWarnings(max(abs(revenue_yoy), na.rm = TRUE)),
      revenue_cv         = if (mean(revenue, na.rm = TRUE) > 0)
                             stats::sd(revenue, na.rm = TRUE) / mean(revenue, na.rm = TRUE)
                           else NA_real_,
      .groups = "drop"
    ) %>%
    mutate(max_abs_revenue_yoy = ifelse(is.finite(max_abs_revenue_yoy),
                                        max_abs_revenue_yoy, NA_real_))
}
