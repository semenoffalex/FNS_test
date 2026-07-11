# ADR-005: Prioritization = Likelihood x Materiality

- **Status:** Accepted
- **Date:** 2026-07-10
- **Context:** TASK.md requires sorting findings into: first-priority attention, background,
  and "genuine economic signal, not an anomaly." Ranking by extremity alone conflates a
  tiny suspicious firm with a large materially-important one, and can't isolate legit outliers.

## Decision

Rank findings on two axes and bucket them:

- **Likelihood** = **composite risk score** = severity-weighted sum of typology flags.
  Tier-1 flags weighted heavier than Tier-2 (default weight 2 vs 1, tunable).
  Continuous-metric severity uses the robust sector-relative distance (e.g. |robust z|).
- **Materiality** = rubles at stake (magnitude of operating_profit / taxes implicated),
  optionally log-scaled for plotting.

**Buckets:**
- **Urgent** — high likelihood AND high materiality (top-right of the 2x2).
- **Background** — flagged but low likelihood or low materiality.
- **Economic signal (not anomaly)** — high materiality, LOW composite score, and an
  internally consistent trajectory across years ⇒ likely a real business phenomenon.
  These are reported and interpreted, not escalated as risk.

## Consequences

- Need a `materiality` definition and an "explained / consistent" test implemented in R.
- Output includes a likelihood-vs-materiality scatter (a strong candidate visualization).
- Weights and the small-cell N are tunable parameters surfaced at the top of the code.

## Alternatives considered

- **Composite score only / flag count** — rejected: ignore materiality; misrank tiny vs large firms.
- **Manual curation only** — rejected as the ranking mechanism: not reproducible; used only for final human read of the shortlist.
