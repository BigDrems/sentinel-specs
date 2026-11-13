# 05 — Debugging playbook

**Purpose:** Provide reproducible diagnostics for known symptoms.

**Confidence note:** Checked available files and searched project comments on 2026-11-13. No application logs, error strings, runtime config, or source comments were available. The code wins (see 16).

## Logs and commands

Log locations, log formats, observability tools, and run commands are **unavailable**. Do not assume a command such as `npm test`, Gradle, or an API server command; no manifests exist in this snapshot.

## Symptom index

There are no verified application symptoms or exact error messages to document. When an incident is available, add its exact message, causes in frequency order, and a diagnostic shortcut here; link the reconstruction in 06. Preserve relevant identifiers while removing credentials and personal data from shared logs.

For repository-state checks in this workspace, `git -C <component> status --short`, `git -C <component> log --oneline`, and `git -C <component> ls-files` are valid read-only Git diagnostics. All component histories were empty on 2026-11-13.
