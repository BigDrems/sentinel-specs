# 03 — Code style

**Purpose:** Capture verified code conventions and commit-message requirements.

**Confidence note:** Commit rules verified against `../git-guidelines.md` on 2026-11-13. No source code or formatter configuration is present. The code wins (see 16).

## Code conventions

**Unavailable:** Language, formatter, lint rules, naming, logging, error handling, and preferred/banned implementation patterns cannot be determined without source and tool configuration. Do not invent commands or impose a new formatter from this note.

## Commit messages

Use the project rule: `scope: Imperative summary`. Use lowercase product and feature scopes where applicable (`sentinel-api/auth:`, `sentinel-web/auth:`, `sentinel-app/auth:`, `sentinel-specs/auth:`); use `sentinel-*` product names in place of the template's `code-name`. The summary is sentence case, imperative, at most 50 characters, and has no final period. For a breaking change, add `!` after the scope and a `BREAKING CHANGE:` trailer. Wrap explanatory body lines at 72 characters. Do not add an AI agent as author of commits, tags, releases, or PRs.

Before using a scope, check `../git-guidelines.md` and repository conventions for any newer project-specific adjustment. The guide's examples include placeholder product names and should not be copied literally.
