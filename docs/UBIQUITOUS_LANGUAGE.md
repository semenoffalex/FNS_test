# Ubiquitous Language

Domain glossary for the tax-risk anomaly analysis. Updated live as the grilling session
crystallizes terms.

## Entities

| Term          | Definition                                                                 | Aliases to avoid        |
| ------------- | -------------------------------------------------------------------------- | ----------------------- |
| **Company**   | A single legal entity, keyed by `company_id` / `inn`                       | firm, org, taxpayer     |
| **Company-year** | One observation: a company in one of 2023–2025 (a row in the dataset)   | record, row             |
| **Group**     | A set of companies linked by a shared attribute (e.g. `founder_id`, `address_hash`) suspected to be related parties | cluster, network        |
| **Finding**   | A specific company or group flagged under a hypothesis, with evidence      | hit, alert              |

## Analytical concepts

| Term              | Definition                                                                        | Aliases to avoid |
| ----------------- | --------------------------------------------------------------------------------- | ---------------- |
| **Lens**          | The primary framing of the analysis. Here: tax-risk / compliance (see ADR-001)    | angle, view      |
| **Typology**      | A named category of tax-risk behavior with a testable rule (a hypothesis)         | pattern, type    |
| **Effective tax rate (ETR)** | `taxes_paid / operating_profit` (primary). Undefined when `operating_profit <= 0` (routed to loss/margin track). `taxes_paid / revenue` kept as secondary corroborator. | tax burden |
| **Flag**          | A single company-year (or group) that triggers a typology's rule                  | anomaly, outlier |
| **Materiality**   | The economic size of a flag (e.g. rubles of profit or tax at stake)               | importance       |

## Typologies (see ADR-003)

| Term | Rule sketch | Tier |
| ---- | ----------- | ---- |
| **Low ETR** | `taxes_paid` abnormally low vs. profit base | 1 |
| **Shell / transit** | large `revenue`, `headcount` 1–5, tiny `payroll_fund` | 1 |
| **Dividend stripping** | `dividends_paid` high vs. `net_profit` (or exceeding it) | 1 |
| **Margin anomaly** | gross/operating margin far from `okved_section` peers | 1 |
| **Identity violation** | P&L chain arithmetic inconsistency | 2 |
| **YoY jump** | large revenue/profit change across years | 2 |
| **Young-big** | recent `ogrn_year` + very large revenue | 2 |
| **Wage anomaly** | `payroll_fund`/`headcount` implausible | 2 |

| Term | Definition | Aliases to avoid |
| ---- | ---------- | ---------------- |
| **Composite risk score** | Per-company aggregate of flags across all typologies, used to rank findings | risk index |

## Relationships

- A **Company** has one or more **Company-year** observations (up to 3: 2023–2025).
- A **Group** contains one or more **Companies** sharing a linking attribute.
- A **Typology** produces zero or more **Flags**; a curated **Finding** references the flag(s) + evidence.

## Flagged ambiguities

- "Company or group of companies" in TASK.md — we distinguish **Company** (single entity)
  from **Group** (related-party set). Which linking attributes define a Group is TBD (see grilling).
- "Profit" is ambiguous across `gross_profit`, `operating_profit`, `net_profit` — the ETR
  denominator must be pinned down (see grilling).
