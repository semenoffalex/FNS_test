# ADR-003: Typology portfolio and tiering

- **Status:** Accepted
- **Date:** 2026-07-10
- **Context:** Eight tax-risk typologies are computable from one shared feature table.
  The deliverable caps visualizations at 3–5 and the summary at 1 page, so attention
  (not compute) is the scarce resource. We must tier.

## Decision

All eight typologies are **computed as detectors**. They are tiered by narrative priority:

**Tier 1 — lead findings (sharp thresholds, own the 3–5 charts, headline the summary):**
1. **Low effective tax rate** — `taxes_paid` abnormally low vs. profit base.
2. **Shell / transit** — large `revenue` with `headcount` 1–5 and tiny `payroll_fund`.
3. **Dividend stripping** — `dividends_paid` high vs. `net_profit` (or exceeding it), esp. with low tax.
4. **Margin anomalies vs. sector** — gross/operating margin far from `okved_section` peers.

**Tier 2 — background (computed, folded into composite risk score):**
5. Accounting-identity violations (P&L chain inconsistencies).
6. Sudden YoY jumps/collapses (2023–2025).
7. Young firm (`ogrn_year`) with very large revenue.
8. Wage anomalies (`payroll_fund`/`headcount` implausibly low/high).

## Consequences

- A **composite risk score** aggregates flags across all eight typologies per company.
- Tier 1 typologies drive the visualizations and the priority findings list.
- Tier 2 typologies act as corroborating evidence and catch cases Tier 1 misses.

## Alternatives considered

- **All eight as equal headliners** — rejected: exceeds the 3–5 chart / 1-page budget and dilutes.
