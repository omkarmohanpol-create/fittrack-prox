# Feature tickets

Status: **Done** = code written, analyzed against Flutter 3.24.5 with no errors, and covered by tests
where it has logic. "Device check" items in docs/TESTING.md still need a real phone.

| # | Feature | Status | Notes |
| --- | --- | --- | --- |
| 1 | Email auth + guest mode | Done | sessions 1–2 |
| 2 | Dashboard, workouts, progress charts, water, goals, reminders, CSV export | Done | session 1 |
| 3 | GitHub Actions build | Done | debug APK, release AAB with secrets, schema + function checks, iOS manual |
| 4 | Android/iOS platform config | Done | `tool/patch_android.py`, `tool/patch_ios.py`, tested on Flutter's templates |
| 5 | Backdate workouts | Done | up to 365 days |
| 6 | Expired session → back to login | Done | |
| 7 | Edit a workout (incl. date) | Done | tap a card; atomic `save_workout` on the server |
| 8 | Exercise library + custom exercises | Done | ~60 built in, custom synced |
| 9 | Workout timer + rest timer with haptics | Done | timestamp-based, survives backgrounding |
| 10 | Body measurements + weight chart | Done | metric/imperial |
| 11 | Steps tracking + steps goal | Done | phone step sensor via `pedometer`, opt-in permission |
| 12 | Avatar upload | Done | Supabase Storage `avatars`, 5 MB, JPEG/PNG |
| 13 | Account deletion | Done | Edge Function `delete-account` (deploy once) |
| 14 | Google sign-in | Done | needs Google Cloud + Supabase setup (DEPLOYMENT.md §5) |
| 15 | Offline cache + sync on reconnect | Done | workouts and water queued; others need a connection to change |
| 16 | Chart pinch-to-zoom | Done | Progress screen, ranges with more than 7 buckets |
| 17 | Inter font | Done | bundled with its OFL licence |
| 18 | Docs: DEPLOYMENT, TESTING, FEATURE-TICKETS | Done | |
| 19 | Release signing | Done (Android) | iOS signing is done in Xcode on a Mac |
| 20 | Store submission | Not started | needs your accounts: see DEPLOYMENT.md §9 |

## Known limits (by design, for now)

- Offline: deleting a synced workout, and adding measurements or custom exercises, need a connection
  (the app says so). Water entries are today-only.
- Steps come from the phone's step sensor while the app has been opened that day or before; steps taken
  after the last reading of an evening may count towards the next day. Health Connect / HealthKit would
  give exact history but needs extra platform setup.
- Pinch zoom is on the Progress screen only; the dashboard's 7-day chart is small enough without it.
- Guest data is not moved into an account when a guest signs up.
- No Sign in with Apple yet (see the iOS store note in DEPLOYMENT.md).
