#!/usr/bin/env Rscript
# ------------------------------------------------------------------
# run.R  -- orchestrate the tax-risk pipeline end to end.
# Usage: Rscript run.R [--render]
#   --render  also renders report.Rmd to HTML (needs the rmarkdown package)
# ------------------------------------------------------------------

args <- commandArgs(trailingOnly = TRUE)
do_render <- "--render" %in% args

source("R/00_config.R")
setup_locale()
source("R/01_load.R")
source("R/02_features.R")
source("R/03_typologies.R")
source("R/04_scoring.R")
source("R/05_groups.R")

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(scales)
})

run_pipeline <- function(config = CONFIG) {
  dat <- load_data(config)

  cy        <- build_company_year_features(dat, config)
  panel     <- build_company_panel_features(cy)
  cy        <- left_join(cy, panel, by = "company_id")

  typ       <- run_typologies(cy, config)
  typ       <- score_company_year(typ, config)

  comp      <- score_company(typ, cy, config)
  comp      <- bucket_findings(comp, config)

  groups    <- build_groups(cy, comp, config)

  list(dat = dat, cy = cy, typ = typ, comp = comp, groups = groups,
       is_sample = isTRUE(attr(dat, "is_sample")))
}

save_outputs <- function(res, config = CONFIG) {
  # machine-readable prioritized findings (no row index, per house rule)
  findings <- res$comp %>%
    select(company_id, company_name, okved_section, bucket, composite,
           n_flags, n_tier1, materiality, revenue_max, taxes_paid_total,
           flag_low_etr, flag_shell, flag_dividend, flag_margin,
           flag_identity, flag_yoy, flag_young_big, flag_wage)
  readr::write_csv(findings, file.path(config$out_dir, "findings.csv"))

  if (nrow(res$groups) > 0) {
    readr::write_csv(res$groups, file.path(config$out_dir, "groups.csv"))
  }

  # ---- figures ----
  # Fig 1: likelihood x materiality scatter (the prioritization map)
  plot_dat <- res$comp %>% filter(n_flags > 0)
  if (nrow(plot_dat) > 0) {
    p1 <- ggplot(plot_dat, aes(composite, materiality, color = bucket)) +
      geom_point(alpha = 0.7, size = 2) +
      scale_y_continuous(labels = label_number(scale_cut = cut_short_scale())) +
      labs(title = "Prioritization map: likelihood x materiality",
           x = "Composite risk score (likelihood)",
           y = "Materiality (max operating profit, RUB)", color = "Bucket") +
      theme_minimal(base_size = 12)
    ggsave(file.path(config$out_dir, "fig1_priority_map.png"), p1,
           width = 8, height = 5, dpi = 120)
  }

  # Fig 2: flag frequency by typology
  flag_cols <- c(TIER1_FLAGS, TIER2_FLAGS)
  freq <- tibble::tibble(
    typology = flag_cols,
    n = sapply(flag_cols, function(f) sum(res$comp[[f]], na.rm = TRUE)),
    tier = ifelse(flag_cols %in% TIER1_FLAGS, "Tier 1", "Tier 2")
  )
  p2 <- ggplot(freq, aes(reorder(typology, n), n, fill = tier)) +
    geom_col() + coord_flip() +
    labs(title = "Companies flagged per typology", x = NULL, y = "Companies") +
    theme_minimal(base_size = 12)
  ggsave(file.path(config$out_dir, "fig2_typology_freq.png"), p2,
         width = 8, height = 5, dpi = 120)

  # Fig 3: bipartite affiliation graph (founders = circles, companies = squares)
  aff_graph <- build_affiliation_graph(res$cy, res$groups, res$comp)
  if (!is.null(aff_graph)) {
    plot_affiliation_graph(
      aff_graph,
      file = file.path(config$out_dir, "fig3_affiliation_graph.png"),
      title = "Группы аффилированности (двудольный граф)"
    )
  }

  invisible(findings)
}

res <- run_pipeline(CONFIG)
save_outputs(res, CONFIG)

cat("\n==== PIPELINE SUMMARY ====\n")
cat(sprintf("Source: %s%s\n", attr(res$dat, "source_path"),
            if (res$is_sample) "  [SAMPLE -- smoke test only]" else ""))
cat(sprintf("Companies: %d | Company-years: %d\n",
            dplyr::n_distinct(res$comp$company_id), nrow(res$cy)))
print(as.data.frame(table(bucket = res$comp$bucket)))
cat(sprintf("Multi-company founder groups: %d\n", nrow(res$groups)))
cat("Outputs written to: ", CONFIG$out_dir, "/\n", sep = "")

if (do_render && requireNamespace("rmarkdown", quietly = TRUE)) {
  saveRDS(res, file.path(CONFIG$out_dir, "pipeline_result.rds"))
  rmarkdown::render("report.Rmd",
                    output_dir = CONFIG$out_dir,
                    quiet = TRUE)
  out_html <- file.path(CONFIG$out_dir, "report.html")
  root_html <- "report.html"
  file.copy(out_html, root_html, overwrite = TRUE)
  if (!identical(readBin(out_html, "raw", file.info(out_html)$size),
                 readBin(root_html, "raw", file.info(root_html)$size))) {
    stop("report.html copies are not identical: ", root_html, " vs ", out_html)
  }
  cat("Report rendered to ", out_html, " and ", root_html, " (identical)\n", sep = "")
}
