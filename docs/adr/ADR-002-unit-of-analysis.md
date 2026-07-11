# ADR-002: Unit of analysis = company panel first, related-party groups second

- **Status:** Accepted
- **Date:** 2026-07-10
- **Context:** TASK.md targets "companies or groups of companies." The dataset has a time
  dimension (2023–2025) and linkage columns (`founder_id`, `address_hash`).

## Decision

Build in two stages:

1. **Company panel (primary):** each company is a short time series across 2023–2025.
   Features include levels, financial ratios, year-over-year changes, and volatility.
2. **Related-party groups (secondary):** cluster companies sharing `founder_id` and/or
   `address_hash`; look for network-level typologies (profit shifting, coordinated behavior).

## Consequences

- Data model is a company-year long table plus a company-level feature table plus a group table.
- Single-firm typologies are scored on the panel; structural typologies on groups.
- Group linkage in synthetic data may be sparse — we validate linkage density before over-investing.

## Alternatives considered

- **Panel only / row only** — rejected: ignores the related-party structure the linkage columns invite.
- **Groups first** — rejected as lead: slower to first result; depends on linkage density we haven't verified.
