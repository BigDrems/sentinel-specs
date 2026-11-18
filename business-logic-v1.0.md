# Business Logic

> v1.0: the team's first draft, ported into the course template.

## Project Details

- Company/Team Name: Makersphere
- Project Code Name: Sentinel
- Project Short Code: sentinel
- Short Description: BioMap Leyte, a geospatial wildlife documentation platform where Contributors record Observations in the field, Reviewers validate them, and the public explores approved Observations on a map, with AI giving preliminary species suggestions.
- Long Description:
  BioMap Leyte lets community members, students, and researchers in Leyte (starting with Baybay City) record wildlife Observations with photos, field notes, and GPS coordinates, even without connectivity on Android. Reviewers validate each Observation against a curated Taxon list before it becomes public. Gemini 2.5 Flash provides an unverified species suggestion to help Contributors and Reviewers, but it never decides anything. The platform protects Sensitive Records (for example nests or threatened species) by publishing only a generalized ~5 km grid location instead of the Exact Location.

## User Levels

| User Level | Description |
| ----------------------- | ----------- |
| A. Administrator | Holds all Reviewer capabilities and can unclaim any claimed Observation. Changes roles and Taxa via SQL script (no Admin UI). |
| B. Reviewer | Claims other Contributors' Observations from the Review Queue, inspects the Exact Location and AI Analysis, links or corrects the Taxon and sensitivity, and approves, requests changes, or rejects. |
| C. Contributor | Registered user who creates Observations (Web or offline on Android), marks them sensitive, edits or withdraws them before review, and tracks their status and AI suggestion. |
| D. Public Visitor | Unauthenticated person who explores approved Observations on the map, list, and detail pages. |

## System Requirements

1. The app shall allow users to register and sign in with email and password, accepting the CC BY-NC 4.0 license at sign-up.
2. The app shall allow users to explore approved Observations on a clustered map and a synced list, filtered by category and date range.
3. The app shall allow users to view an approved Observation's photos, Reviewer-confirmed Taxon, date, Public Location, attribution, and license.
4. The app shall allow Contributors to submit an Observation on Web with a location (browser GPS, map pin, or manual lat/lng), photos, field notes, an optional Taxon or Claimed Name, and a "sensitive" flag.
5. The app shall allow Contributors to capture Observations offline on Android as Drafts that sync automatically and idempotently when a connection returns.
6. The app shall allow Contributors to see an AI-assisted species suggestion, labeled "not verified", for their own Observations.
7. The app shall allow Contributors to track their Observations' status, edit those in Needs Changes, withdraw before a Claim, and retry a failed AI Analysis.
8. The app shall allow Reviewers to claim an Observation, inspect its Exact Location and AI suggestion, link a Taxon, change sensitivity, and approve, request changes, or reject (reason required for the last two).
9. The app shall allow Contributors to set a display name and turn public attribution on or off ("Anonymous Contributor").

## Required Solution Layers

1. Security and privacy by design. Data Privacy Act compliance, location protection, retention limits, no per-user trails, aggregation thresholds, and consent for any data resale.
   - Location protection: Sensitive Records publish only a deterministic ~5 km grid centroid, and public endpoints never return `exact_location` or AI output.
   - EXIF/GPS metadata is stripped from every photo on the server. Media is stored in a private bucket and served through short-lived signed URLs.
   - Authorization is enforced in the API, with RLS as defense in depth.
2. AI is decision support, never authority. AI failures never block submission or review.
3. Offline-resilient field capture on Android.

## MVP Features and Access

> See the User Levels table for reference.

| Feature | Access |
| --------------------- | ----------- |
| 1. Explore approved Observations (map, list, details) | A,B,C,D |
| 2. Register / sign in (email + password, license acceptance) | A,B,C |
| 3. Profile: display name, attribution toggle | A,B,C |
| 4. Submit Observation (Web) | A,B,C |
| 5. Offline field capture and Draft sync (Android) | A,B,C |
| 6. My Observations: status, AI suggestion, edit, withdraw, AI retry | A,B,C |
| 7. View AI Analysis of any Observation | A,B |
| 8. Review Queue, Claim, and decision (approve / request changes / reject) | A,B |
| 9. Flag or unflag sensitivity on any Observation | A,B |
| 10. Unclaim any claimed Observation | A |
| 11. Role and Taxa changes (SQL script, no UI) | A |

## Notes

- Course project for 4 developers (2 Web, 2 Android; API shared under one API Lead). Deployed live and graded by the professor, with no real end users. Submission: second week of December 2026.
- Monorepo with pnpm workspaces: Hono API, React Web, native Kotlin Android, shared Zod contracts.
- Android is Contributor-only; Reviewer and Admin work happens on Web.
- Deferred: Admin UI, Android Explore tab, iOS, AI note summaries, species/keyword filters, rate limiting, email verification, self-serve account deletion, offline editing.
