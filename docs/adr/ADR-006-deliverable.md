# ADR-006: Deliverable = modular R scripts + Quarto report

- **Status:** Accepted
- **Date:** 2026-07-10
- **Context:** Tooling is R. Deliverables: 1-page manager summary, 3–5 visualizations,
  prioritized list of companies/groups, reproducibly.

## Decision

Build a small pipeline:

```
R/
  00_config.R      # tunable params: small-cell N, tier weights, thresholds, paths
  01_load.R        # read dataset, type coercion, validate schema
  02_features.R    # company-year ratios + company-panel features (YoY, volatility)
  03_typologies.R  # 8 typology detectors (Tier 1 + Tier 2), robust sector-relative
  04_scoring.R     # composite risk score + materiality + buckets
  05_groups.R      # founder_id groups (address_hash strengthens), group typologies
  report.Rmd         # sources the above, renders 1-page summary + 3-5 figures
run.R              # orchestrator: runs pipeline, writes findings.csv, renders report
findings.csv       # ranked flagged companies/groups (written by the pipeline)
```

> **Toolchain note (2026-07-10):** Quarto is NOT installed; R 4.3.2 with the `rmarkdown`,
> `knitr`, `ggplot2`, `dplyr`, `tidyr`, `readr`, `data.table`, `scales` packages IS available.
> The report is therefore authored as **`report.Rmd` (R Markdown)** rather than Quarto `.qmd`.
> Same content and intent; renders with the installed `rmarkdown` package.

## Consequences

- Each stage is independently testable.
- `report.qmd` renders to HTML/PDF with the exec summary + visualizations.
- `findings.csv` is the machine-readable prioritized output (no row index written).
- Pipeline points at `test_dataset.csv`; falls back to `test_dataset_smp.csv` for smoke tests.

## Open items

- Real `test_dataset.csv` (1500 rows) is NOT yet in the workspace; only the 10-row sample is.
  Pipeline is built and smoke-tested on the sample; real findings await the full file.

## Alternatives considered

- **Single monolithic .Rmd** — rejected: hard to test in pieces.
- **Scripts + hand-written summary** — rejected: summary not auto-derived from data.
- **Analysis-only, defer report** — rejected: leaves no polished deliverable.
