# 07 — Database

**Purpose:** Explain data identity, integrity, migrations, and dangerous operations.

**Confidence note:** The API instructions describe communication with the Supabase Database API. No schema, SQL, migrations, or database configuration is available as of 2026-11-13. The code wins (see 16).

## Verified scope

Supabase is named in `sentinel-api/AGENTS.md`; the actual database product configuration, project identifiers, access pattern, and ownership are not verifiable here.

## Unavailable details

Identity strategy, tables, constraints, deletes, migration ordering, integrity invariants, indexes, RLS policies, backup/restore, and dangerous operations are unknown. Never infer table names or recommend a destructive SQL operation from this document. Before a schema change, inspect migrations, deployed schema, API validators, and both clients for lockstep fields (see 04). Record exact paths and rollback considerations after verification.
