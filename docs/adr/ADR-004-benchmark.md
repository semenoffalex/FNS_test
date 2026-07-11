# ADR-004: Definition of "abnormal" = sector-relative robust statistics

- **Status:** Accepted
- **Date:** 2026-07-10
- **Context:** Thresholds must respect sector economics (margins differ wildly by industry).
  500 firms across many `okved_section`s means some sector cells are small and unstable.

## Decision

- **Continuous ratios** (ETR, gross/operating margin, revenue-per-head, payroll-per-head)
  are flagged **relative to `okved_section` peers using robust statistics** (median / MAD,
  and IQR fences), NOT mean/SD (which the outliers themselves distort).
- **Minimum cell size:** if a sector has fewer than N companies (default N=8, tunable),
  fall back up a hierarchy: `okved_section` → broader grouping → global.
- **Arithmetic-impossibility checks are absolute**, not sector-relative:
  e.g. `dividends_paid > net_profit`, or P&L identity violations
  (`revenue − cost_of_goods ≠ gross_profit`). These are data-integrity flags, valid regardless of sector.

## Consequences

- Two flagging mechanisms coexist: robust sector-relative z-equivalents for continuous
  metrics, and hard boolean rules for impossibilities.
- Fallback logic must be implemented and the fallback level recorded per flag for auditability.

## Alternatives considered

- **Plain within-sector z-scores** — rejected: mean/SD distorted by target outliers; small cells explode.
- **Absolute cutoffs only** — rejected: sector-blind and arbitrary for continuous ratios.
