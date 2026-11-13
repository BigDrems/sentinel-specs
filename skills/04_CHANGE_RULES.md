# 04 — Change rules

**Purpose:** Identify mirrored contracts and coordinated edits that can drift.

**Confidence note:** Inventory checked across available repository files on 2026-11-13. No application source, schemas, or generated artifacts exist in this snapshot. The code wins (see 16).

## Lockstep inventory

| Set | Known locations | Required coordination | Miss → consequence |
|---|---|---|---|
| API/database/client contracts | None available | Unknown; inspect API schemas, Supabase migrations, and web/Android models once present | Miss → incompatible clients, rejected writes, or incorrect displays are possible; no specific failure is verified. |
| Release identifiers | `sentinel-specs/git-guidelines.md`; component tags/branches unavailable | Keep annotated release tags aligned with the specified product prefix and chronological weekly build rules | Miss → tags can misidentify the tested commit or break release traceability. |

No constants, enums, registries, column lists, error codes, or mirrored types could be inventoried. Add each as a numbered row with exact paths and test targets when code is available.

## High-risk areas and retest

The only evidenced high-risk coordinated area is release metadata and branch promotion; follow `10_DEPLOYMENT.md`. Retest scope for application changes is unknown until build and test instructions are recovered. Record any discovered lockstep set here and link its incident in 06.
