# PrepNotes — Project Rules

## What this is
PrepNotes: a student platform to browse/buy university-wise notes (University → Semester → Subject → Module → Notes),
free Resource Room, Study Zone (Pomodoro/Stopwatch), Student Voice (feedback), Profile, and an Admin Panel.
Targets: Flutter Web + Android + iOS. Backend: Firebase (Auth, Firestore, Storage, Functions, Hosting, App Check).

## Stack
- Flutter (latest stable), Dart null-safety, Riverpod (with code generation), go_router, freezed + json_serializable.
- Cloud Functions in TypeScript (2nd gen), Node 22.
- Payments: Razorpay (INR). Server verifies everything.

## Architecture rules
- Feature-first folders: lib/features/<feature>/{presentation,data,domain}. Shared code in lib/core and lib/data.
- UI widgets NEVER call Firebase directly. Use repositories exposed via Riverpod providers.
- Models are immutable (freezed). No business logic in widgets.
- All Firestore collection/field names live in lib/core/constants/firestore_paths.dart. No magic strings.
- Every screen must handle: loading, error, empty, and data states.
- Responsive: mobile (<600), tablet (600–1024), desktop (>1024). Use a shared responsive helper; no hard-coded pixel layouts.
- Paginate all lists (limit + startAfter). No unbounded Firestore listeners.
- Use Material 3 with a central theme (light + dark). No hard-coded colors in widgets.
- User-facing strings in one place so they can be localized later.

## Security rules (non-negotiable)
- Clients can NEVER write to `orders` or `users/{uid}/entitlements`. Only Cloud Functions do.
- Private PDFs are served only through a callable Function returning a short-lived signed URL after entitlement check.
- Admin = custom claim `admin: true`. Enforce in firestore.rules, storage.rules and in every admin Function.
- Never commit secrets. Use Functions secrets / .env files ignored by git.

## Workflow rules
- Before coding a phase: write a short plan and list the files you will create/change. Wait for approval.
- After coding: run `flutter analyze`, `dart format .`, relevant tests, and fix all issues.
- Keep commits small, with conventional commit messages.
- When unsure about a requirement, ask instead of guessing.
- Do not add packages without stating why.

## Definition of done (per feature)
Works on web + mobile layout, handles loading/error/empty states, rules updated + tested in emulator, no analyzer warnings.

## Teaching Mode (VERY IMPORTANT)
The user is a learner and wants to understand everything. Always:
- Work on ONE phase at a time, and inside it ONE small step at a time. Never leave work half-done and never jump ahead.
- Before coding: explain in simple English what you are about to build and why.
- After each step, give a report with these headings:
  1. What was built (file by file, in simple words)
  2. How it works
  3. What the user must do (exact, numbered manual steps: commands to run, Firebase console clicks, API keys to add, packages to install)
  4. How to test it
  5. What the next step is
- If something needs the user (Firebase console, API keys, logins), STOP and say exactly what to do. Do not fake or skip it.
- Never mark a step as done until it actually works and `flutter analyze` is clean.
- Wait for the user to say "next" before continuing.