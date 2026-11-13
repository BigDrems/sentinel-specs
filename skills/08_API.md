# 08 — API

**Purpose:** Describe response contracts, routes, auth, and safe endpoint changes.

**Confidence note:** `sentinel-api/AGENTS.md` describes a backend between Supabase Database API and web/Android clients. No routes, source, validators, or tests are available as of 2026-11-13. The code wins (see 16).

## Contract inventory

Response envelope, endpoint list, HTTP methods, authorization, versioning, error codes, validation library, pagination, and rate limits are **unknown**. No endpoint-adding procedure can be verified.

## Before changing an endpoint

Recover the API implementation and its tests, then inspect web and Android callers plus database schema. Update all mirrored request/response types and validators in one reviewed change (see 04). Add a documented route entry with auth requirements and exact failure behavior only after confirming it in code. Do not assume that a route is public or that a Supabase response is passed through unchanged.
