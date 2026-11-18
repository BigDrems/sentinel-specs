# Business Logic

> **v1.1**: the agreed business logic, built from [business-logic-v1.0.md](./business-logic-v1.0.md) and the revisions the team agreed on. This is the source of truth for the database schema and for the succeeding tasks.

## Project Details

- Company/Team Name: Makersphere
- Project Code Name: Sentinel
- Project Short Code: sentinel
- Short Description: BioMap Leyte, a privacy-first wildlife observation map for Leyte with offline field capture, Reviewer validation, and AI-assisted species suggestions.
- Long Description:
  BioMap Leyte lets community members, students, and researchers in Leyte (starting with Baybay City) record wildlife Observations with photos, field notes, and GPS coordinates, even without connectivity on Android. Reviewers validate each Observation against a curated Taxon list before it becomes public, and Gemini 2.5 Flash offers an unverified species suggestion that never decides anything.
  Privacy is built in: Sensitive Records publish only a ~5 km grid location, contributors cannot be tracked through their records, personal data is kept only as long as needed and never sold, and every Contributor gives informed Consent under the Data Privacy Act of 2012 (RA 10173).

### Positioning

- **Problem:** Leyte's biodiversity records are scattered across personal phones and social media posts. They carry no validation and expose exact locations of vulnerable species to poachers.
- **Target users:** Field Contributors (students, local guides, LGU/DENR field staff), Reviewers (biology faculty and researchers), and the public.
- **Value:** Capture that works offline in the field, a human-validated public record, and location protection by default.
- **MVP success:** the end-to-end acceptance flows work on the deployed system.

## User Levels

| User Level | Description |
| ----------------------- | ----------- |
| A. System Administrator | Team member with Supabase and API-host console access. Maintains configuration and backups, changes roles and seeds Taxa via SQL, reads the Audit Log, and fulfils data-subject requests. Not an in-app role; uses an Administrator account inside the app. |
| B. Administrator | Views on-demand Reports and exports them to CSV. Holds all Reviewer capabilities and can unclaim any claimed Observation. |
| C. Reviewer | Claims other Contributors' Observations, inspects the Exact Location and AI Analysis, links or corrects the Taxon and sensitivity, and approves, requests changes, or rejects. Sees Contributors by display name only. |
| D. Contributor | Signed-in user who has given Consent. Creates Observations (Web, or offline on Android), marks them sensitive, edits or withdraws them before review, and tracks their status and AI suggestion. |
| E. Public Visitor | Unauthenticated person who explores approved Observations and reads the Privacy Notice. |

## System Requirements

1. The app shall allow users to authenticate using Google Sign-In integration. Public registration is Google-only; email/password accounts exist only for seeded test accounts.
2. The app shall require users, on first sign-in and whenever the Privacy Notice version changes, to give Consent to the current Privacy Notice and the CC BY-NC 4.0 license, and to set a display name (pre-filled from their Google given name) and an attribution preference, before they can contribute.
3. The app shall allow users to explore approved Observations on a clustered map and a synced list, filtered by category and date range, showing only the Public Location and a date-only observation date.
4. The app shall allow users to view an approved Observation's photos, Reviewer-confirmed Taxon, date, Public Location, attribution (display name or "Anonymous Contributor"), and license.
5. The app shall allow Contributors to submit an Observation on Web with a location (browser GPS, map pin, or manual lat/lng), photos, field notes, an optional Taxon or Claimed Name, and a "sensitive" flag.
6. The app shall allow Contributors to capture Observations offline on Android as Drafts that sync automatically and idempotently when a connection returns.
7. The app shall allow Contributors to see an AI-assisted species suggestion, labeled "not verified", for their own Observations.
8. The app shall allow Contributors to track their Observations' status, edit those in Needs Changes, withdraw before a Claim, and retry a failed AI Analysis.
9. The app shall allow Reviewers to claim another Contributor's Observation, inspect its Exact Location and AI suggestion, link a Taxon, change sensitivity, and approve, request changes, or reject (reason required for the last two).
10. The app shall allow Administrators to view on-demand Reports of Observation counts by status, category, and month, plus total Contributors, for a chosen date range, and export them to CSV, with small counts suppressed.
11. The app shall allow users to read the Privacy Notice and to request access to, correction of, or erasure of their personal data through the Data Protection Contact.
12. The app shall allow users to change their display name and attribution preference, and to sign out.

## Required Solution Layers

1. Security and privacy by design. Data Privacy Act compliance, location protection, retention limits, no per-user trails, aggregation thresholds, and consent for any data resale.
   - **Data Privacy Act (RA 10173):** a public, versioned Privacy Notice; recorded Consent (Privacy Notice version and license acceptance time); a named Data Protection Contact. Access, correction, and erasure requests are handled manually by email. On erasure, approved Observations are kept as "Anonymous Contributor" and everything else is hard-deleted. Until Consent is recorded, every Contributor action is refused.
   - **Location protection:** Sensitive Records publish only a deterministic ~5 km grid centroid. Public endpoints never return the Exact Location or AI output. EXIF/GPS is stripped on the server. Media lives in a private bucket and is served through short-lived signed URLs.
   - **Retention limits:** a daily purge job:
     - hard-deletes rejected and withdrawn Observations after 90 days, together with their media, AI Analysis, and Review Events;
     - deletes uploads never attached to an Observation after 24 hours;
     - deletes Audit Logs after 1 year.

     Approved Observations are kept indefinitely. Audit Logs hold only actor, action, and entity identifiers, never Observation content. Application logs exclude IP addresses, request bodies, and tokens, and expire under the host's default log retention.
   - **No per-user trails:** public responses carry the display name only, never a contributor ID. There is no public contributor profile or contributor filter. The observation date is published at date precision. Reviewers see Contributors by display name only, with no email, ID, or per-person history. Android reads location only at capture time, never in the background.
   - **Aggregation thresholds:** there are no public aggregate statistics. In Reports and CSV exports, any breakdown count below 5 is shown as `<5`.
   - **Consent for data resale:** no data is sold. The CC BY-NC 4.0 license forbids commercial reuse by third parties, and any future resale would require a separate, explicit opt-in.
   - **Authorization** is enforced in the API on every route, with RLS as defense in depth.
2. AI is decision support, never authority. AI output is labeled "AI-assisted suggestion — not verified", is never public, and its failures never block submission or review.
3. Offline-resilient field capture. Android Drafts persist locally and sync idempotently, so Observations are never lost.

## MVP Features and Access

> See the User Levels table for reference. A (System Administrator) uses an Administrator account in-app; feature 13 is console-only.

| Feature | Access |
| --------------------- | ----------- |
| 1. Explore approved Observations (map, list, details) | A,B,C,D,E |
| 2. Privacy Notice page | A,B,C,D,E |
| 3. Google Sign-In and Consent onboarding | A,B,C,D |
| 4. Profile: display name, attribution toggle, sign out | A,B,C,D |
| 5. Submit Observation (Web) | A,B,C,D |
| 6. Offline field capture and Draft sync (Android) | A,B,C,D |
| 7. My Observations: status, own AI suggestion, edit, withdraw, AI retry | A,B,C,D |
| 8. Review Queue, Claim, and decision (with AI Analysis of any Observation) | A,B,C |
| 9. Flag or unflag sensitivity on any Observation | A,B,C |
| 10. Unclaim any claimed Observation | A,B |
| 11. Reports with date range and CSV export | A,B |
| 12. Daily retention purge (automated) | System |
| 13. Roles, Taxa seeding, backups, Audit Log access, data-subject request fulfilment (console) | A |

## Notes

- Course project for 4 developers (2 Web, 2 Android; API shared under one API Lead). Deployed live and graded by the professor, with no real end users. Submission: second week of December 2026.
- Four public repositories: `sentinel-api` (Hono), `sentinel-web` (React), `sentinel-android` (Kotlin), and `sentinel-specs` (this repository). The API's `GET /v1/openapi.json` is the contract.
- Android is Contributor-only; Reviewer and Admin work happens on Web.
- All data in the MVP is synthetic test data; there are no real users.
- Deferred: Admin UI for roles and Taxa, Android Explore tab, iOS, AI note summaries, species/keyword filters, rate limiting, self-serve account deletion and data export, offline editing, Gemini paid tier.
