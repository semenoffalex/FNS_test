# ------------------------------------------------------------------
# 01_load.R  -- read the dataset, coerce types, validate schema
# ------------------------------------------------------------------

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
})

EXPECTED_COLS <- c(
  "company_id", "company_name", "inn", "ogrn_year", "region",
  "okved_code", "okved_section", "founder_id", "address_hash", "year",
  "revenue", "cost_of_goods", "gross_profit", "opex", "operating_profit",
  "net_profit", "taxes_paid", "headcount", "payroll_fund", "dividends_paid"
)

NUMERIC_COLS <- c(
  "ogrn_year", "year", "revenue", "cost_of_goods", "gross_profit", "opex",
  "operating_profit", "net_profit", "taxes_paid", "headcount",
  "payroll_fund", "dividends_paid"
)

load_data <- function(config = CONFIG) {
  path <- config$data_path
  if (!file.exists(path)) {
    warning(sprintf("'%s' not found -- falling back to sample '%s' (SMOKE TEST ONLY).",
                    path, config$data_path_fallback))
    path <- config$data_path_fallback
  }
  if (!file.exists(path)) {
    stop(sprintf("No data file found (looked for '%s' and '%s').",
                 config$data_path, config$data_path_fallback))
  }

  dat <- readr::read_csv(path, show_col_types = FALSE, progress = FALSE)

  # schema validation
  missing <- setdiff(EXPECTED_COLS, names(dat))
  if (length(missing) > 0) {
    stop("Dataset is missing expected columns: ", paste(missing, collapse = ", "))
  }
  dat <- dat[, EXPECTED_COLS]

  for (col in NUMERIC_COLS) {
    dat[[col]] <- suppressWarnings(as.numeric(dat[[col]]))
  }

  attr(dat, "source_path") <- path
  attr(dat, "is_sample")   <- identical(basename(path), basename(config$data_path_fallback))
  message(sprintf("Loaded %d rows x %d cols from %s%s",
                  nrow(dat), ncol(dat), path,
                  if (isTRUE(attr(dat, "is_sample"))) "  [SAMPLE]" else ""))
  dat
}
