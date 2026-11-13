# 16 — Engineering principles

**Purpose:** State concise rules supported by available project evidence.

**Confidence note:** Principles below are grounded in `../git-guidelines.md` or this handoff's explicit standards, reviewed 2026-11-13. No implementation-derived principle is verified. The code wins (see 16).

1. **Promote through reviewed gates.** Each branch is a controlled workflow stage; bypassing QA or testing can send unapproved code to independent testers or production. Evidence: `../git-guidelines.md`, promotion rules 1–8.
2. **Tag the artifact that was actually tested.** A moved, reused, or incorrectly sourced tag breaks traceability between the published bundle and its reviewed result. Evidence: `../git-guidelines.md`, promotion rule 7 and release-tag rules.
3. **Treat mirrored contracts as one change.** API, database, and client copies can drift and reject or misinterpret data. This is a risk-based principle, not a verified current lockstep set; document concrete paths in 04 before applying it.
4. **Write reasons beside rules.** Without the failure a rule prevents, maintainers may remove a guard without understanding its purpose. Evidence: `../handoff.md`, Standards.
5. **Label uncertainty.** Presenting an inference as verified behavior teaches false confidence and can cause unsafe changes. Evidence: `../handoff.md`, Standards; this workspace currently has no code history to resolve implementation questions.

Trust the code over any document, including this one.
