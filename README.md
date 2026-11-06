# FitTrack Pro

Cross-platform (Android + iOS) fitness tracker built with Flutter and Supabase.

- **Connecting the database, Google sign-in, account deletion, release builds:** [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)
- **Running the tests:** [docs/TESTING.md](docs/TESTING.md)
- **What is done and what is left:** [docs/FEATURE-TICKETS.md](docs/FEATURE-TICKETS.md), [docs/MEMORY.md](docs/MEMORY.md)

## Features

- Email sign-up / sign-in, **Google sign-in**, or **guest mode** (everything saved on the phone, not synced)
- Dashboard: greeting, daily challenge, streak, week strip, steps, active-minutes chart, recent workouts
- Workouts: strength (exercises with sets/reps/weight) or cardio, any date in the last year,
  **tap to edit**, swipe to delete
- **Exercise library**: ~60 built-in exercises by muscle group, plus your own
- **Workout timer** with rest countdown (haptics and sound when rest is over); "Finish" logs the minutes
- Progress charts: 7D / 30D / 90D / 1Y, workouts / calories / minutes / volume, line or bar,
  **pinch to zoom**
- **Body measurements**: weight, body fat, waist, chest, arm, hips, with a weight trend chart
- **Steps**: daily count from the phone's step sensor (opt-in), steps goal
- Water tracking with ring, quick-add and 7-day chart
- Goals (workouts per week, daily water, daily steps), achievements, local reminders
- **Profile picture** (camera or gallery, stored in Supabase Storage)
- **Works offline**: last-loaded data is shown, and new or edited workouts and water entries are saved
  on the phone and uploaded when the connection is back
- Settings: dark/light mode, metric/imperial, CSV export, **delete account**, delete guest data

Without `SUPABASE_URL` / `SUPABASE_ANON_KEY` the app runs in guest-only mode, so it can be tried with no backend.

## Quick start

1. Install Flutter **3.24.5** (the version CI uses).
2. Generate the platform folders and apply the project's config:

   ```bash
   flutter create . --platforms=android,ios --org com.fittrack --project-name fittrack_pro
   git checkout -- lib test pubspec.yaml analysis_options.yaml   # undo the counter app if added
   rm -f test/widget_test.dart
   python3 tool/patch_android.py
   python3 tool/patch_ios.py          # only needed on a Mac
   flutter pub get
   ```

   The patch scripts add the permissions, notification receivers, Google sign-in link and release
   signing. They are safe to run again.
3. Connect Supabase (5 minutes, see [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)), then:

   ```bash
   flutter run \
     --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co \
     --dart-define=SUPABASE_ANON_KEY=YOUR-ANON-KEY
   ```

   Only the public **anon** key belongs in the app. Never put the service-role key in it.

## Building in the cloud

Push to GitHub: `.github/workflows/build.yml` analyzes, tests and builds a debug APK (download it from the
run's **Artifacts**). It also tests the database schema on PostgreSQL and type-checks the Edge Function.
Add the signing secrets from [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) to get a Play Store bundle too.

## Project layout

```
lib/
  main.dart                 app, providers, routes
  data/                     built-in exercise library
  models/                   Workout, WaterLog, Goal, BodyMeasurement, ExerciseDef
  providers/                auth, workouts, water, goals, exercises, measurements, steps, settings, theme
  screens/                  dashboard, workouts, log sheet, timer, exercise picker/library,
                            progress, measurements, water, goals, settings, profile, login, splash
  services/                 Supabase, auth, notifications, charts, local storage, step counter
  utils/  widgets/
supabase/
  schema.sql                tables, security rules, save_workout function, avatar bucket
  functions/delete-account  Edge Function that deletes an account
  tests/                    schema tests for plain PostgreSQL
tool/                       patch_android.py, patch_ios.py
fonts/                      Inter 4.0 (SIL Open Font License)
```
