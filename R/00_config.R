# ------------------------------------------------------------------
# 00_config.R  -- tunable parameters and paths for the tax-risk pipeline
# All knobs live here so reviewers can see and change assumptions in one place.
# See docs/adr/ for the decisions these encode.
# ------------------------------------------------------------------

CONFIG <- list(
  # --- data ---
  data_path          = "test_dataset.csv",      # основной датасет (1500 строк)
  data_path_fallback = "test_dataset_smp.csv",  # 10-row sample for smoke tests
  out_dir            = "output",

  # --- benchmarking (ADR-004) ---
  group_col       = "okved_section",  # sector used for peer comparison
  min_cell_size   = 8,                # sectors smaller than this fall back up the hierarchy
  robust_z_flag   = 3.5,              # |modified z| above which a continuous metric is flagged
  identity_tol    = 0.005,            # relative tolerance for accounting-identity checks (0.5%)

  # --- typology-specific ---
  shell_headcount_max = 5,            # "shell/transit" headcount ceiling
  young_age_max       = 2,            # "young firm" = age (year - ogrn_year) <= this
  yoy_flag_z          = 3.5,          # robust z for YoY revenue change

  # --- scoring (ADR-005) ---
  tier_weights = c("1" = 2, "2" = 1), # Tier-1 flags weigh double
  severity_cap = 8,                   # cap |robust z| contribution so one metric can't dominate

  # --- bucketing (ADR-005) ---
  likelihood_hi_q = 0.80,             # composite-score quantile for "high likelihood"
  materiality_hi_q = 0.80,            # materiality quantile for "high materiality"

  seed = 42
)

dir.create(CONFIG$out_dir, showWarnings = FALSE, recursive = TRUE)
set.seed(CONFIG$seed)
