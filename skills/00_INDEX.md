# 00 — Index

**Purpose:** Find the relevant engineering notes by task and keep this set current.

**Confidence note:** Verified against the available workspace snapshot on 2026-11-13. The component repositories have no commits or application files in this snapshot. The code wins (see 16).

## Reading order by task

| Task | Read |
|---|---|
| Understand available system boundaries | 01, then 02 |
| Change or review code | 03, 04, then the component documents 07–09 |
| Investigate a failure | 05, 06, then 07–09 |
| Prepare or ship a release | 10 |
| Add confidence before merging | 11, 12 |
| Update dependencies or local setup | 13, 14 |
| Assess current gaps | 15 |
| Apply shared engineering rules | 16 |

## Documents

All documents were checked against the available workspace on 2026-11-13. Topics that require absent source code are explicitly marked unavailable; they are not verified implementation guidance.

| File | Topic | Last verified |
|---|---|---|
| 01_ARCHITECTURE.md | System model and boundaries | 2026-11-13 |
| 02_PROJECT_STRUCTURE.md | Repository layout | 2026-11-13 |
| 03_CODE_STYLE.md | Code and commit conventions | 2026-11-13 |
| 04_CHANGE_RULES.md | Lockstep change inventory | 2026-11-13 |
| 05_DEBUGGING_PLAYBOOK.md | Diagnostics | 2026-11-13 |
| 06_FAILURE_STORIES.md | Verified incidents | 2026-11-13 |
| 07_DATABASE.md | Data model and migrations | 2026-11-13 |
| 08_API.md | HTTP/API contracts | 2026-11-13 |
| 09_SECURITY.md | Security controls | 2026-11-13 |
| 10_DEPLOYMENT.md | Release and promotion guidance | 2026-11-13 |
| 11_TESTING.md | Test strategy and coverage | 2026-11-13 |
| 12_PERFORMANCE.md | Performance characteristics | 2026-11-13 |
| 13_DEPENDENCIES.md | Dependency inventory and policy | 2026-11-13 |
| 14_DEVELOPER_WORKFLOWS.md | Contributor workflows | 2026-11-13 |
| 15_KNOWN_LIMITATIONS.md | Known gaps and risks | 2026-11-13 |
| 16_ENGINEERING_PRINCIPLES.md | Evidence-based principles | 2026-11-13 |
| INBOX.md | Contributor knowledge queue | 2026-11-13 |

## Contribute and refresh

Add observations to `INBOX.md` or directly to the relevant document with evidence and confidence. Keep contributor substance and credit. Recheck a whole document if any cited path or behavior changes. Retire outdated knowledge with a dated explanation rather than silently deleting it. Append numbered principles; do not renumber them. Update this index and its changelog on every refresh.

## Changelog

- 2026-11-13: Create the initial skills set. Repository source, history, manifests, tests, schema, and CI were unavailable, so implementation-specific claims remain explicitly unverified.
