# 09 — Security

**Purpose:** Record verified security boundaries, threat surfaces, and review checks.

**Confidence note:** No authentication, authorization, transport, storage, or deployment implementation was available on 2026-11-13. No security control is verified by this note. The code wins (see 16).

## Threat model status

The named components imply web and Android clients, a backend, and Supabase, but actual trust boundaries and data sensitivity are not documented. Authentication, authorization layers, secrets handling, injection surfaces, debug gates, accepted gaps, and security tests remain unknown.

## Review checklist pending source recovery

For changes handling user or regulatory data, establish the data classification, caller identity, authorization check, validation boundary, secret source, logging exposure, and tests from actual code before approval. Never put secret values in these documents. Record environment variable names only. A review checklist is not evidence that a control exists; verify implementation and deployment configuration.
