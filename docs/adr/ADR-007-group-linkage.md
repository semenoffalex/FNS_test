# ADR-007: Related-party group linkage = founder_id primary, address_hash corroborating

- **Status:** Accepted
- **Date:** 2026-07-10
- **Context:** Stage-2 groups (ADR-002) need a linkage rule. Two columns available:
  `founder_id` (control signal) and `address_hash` (co-location, weaker/noisier).

## Decision

- A **Group** = set of companies sharing a `founder_id`.
- If members **also** share an `address_hash`, the link is marked **`strong`**;
  otherwise `founder_only`.
- Group-level typology hunted: **profit shifting** — a wide spread of effective tax
  rates / operating margins across members of the same group (profit parked in low-tax members).

## Consequences

- `address_hash` is a confidence booster, not a standalone linker (avoids business-center collisions).
- Linkage density must be validated on the real data; synthetic data may yield few multi-company founders.

## Alternatives considered

- **Either founder OR address** — rejected: address-only links create false groups.
- **Both required** — rejected: likely near-empty in synthetic data.
- **founder only, ignore address** — rejected: discards a free corroborating signal.
