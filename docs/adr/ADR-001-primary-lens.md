# ADR-001: Primary analytical lens = tax-risk / compliance

- **Status:** Accepted
- **Date:** 2026-07-10
- **Context:** TASK.md asks to find companies whose behavior deviates from normal — framed as either "possible risks" or "significant economic patterns." These pull in different directions (accusatory vs. descriptive) and drive different hypotheses, thresholds, and prioritization.

## Decision

The analysis **leads with a tax-risk / compliance lens**: we hunt for evasion-shaped
signals (understated taxes relative to profit, effective-tax-rate outliers, dividend
stripping, wage/headcount mismatches, shell-like profiles, related-party networks).

Statistical-outlier methods and economic-signal interpretation are **secondary** — they
serve the primary lens: statistics is *how* we detect, and economic interpretation is
*how* we screen out legal-but-weird firms to avoid false accusations.

## Consequences

- Hypotheses are organized as tax-risk typologies, each with a testable rule.
- Every flag must survive an economic-plausibility check before it is reported as a risk.
- Prioritization is risk-weighted (likelihood x materiality), not just "how statistically extreme."

## Alternatives considered

- **Pure statistical-outlier lens** — rejected as lead: produces flags with no narrative;
  needs a risk lens anyway to be actionable.
- **Economic-signal lens** — rejected as lead: descriptive, weak as a "catch the bad actor" deliverable.
