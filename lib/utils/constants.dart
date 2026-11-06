class AppConstants {
  static const String appName = 'FitTrack Pro';

  /// Supplied at build/run time, never committed:
  /// flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  static const int defaultWaterGoalMl = 2500;
  static const int waterStepMl = 250;
  static const int defaultWorkoutsPerWeek = 4;

  /// How far back a workout can be logged. WorkoutProvider.load fetches the
  /// last 366 days, so anything older would vanish on the next reload.
  static const int maxBackdateDays = 365;

  static const int defaultStepsGoal = 8000;

  /// Rest-timer presets in seconds.
  static const List<int> restPresets = [30, 60, 90, 120, 180];

  /// Supabase Storage bucket for profile pictures (supabase/schema.sql).
  static const String avatarBucket = 'avatars';
  static const int maxAvatarBytes = 5 * 1024 * 1024;

  /// Where Supabase sends the user back after Google sign-in. Must be listed
  /// under Authentication > URL Configuration > Redirect URLs, and matches the
  /// intent filter / URL type added by tool/patch_android.py and
  /// tool/patch_ios.py. (URL schemes cannot contain "_", so this is not the
  /// package name.)
  static const String authRedirectUrl = 'fittrackpro://login-callback';

  static const List<String> muscleGroups = [
    'Chest',
    'Back',
    'Shoulders',
    'Arms',
    'Legs',
    'Core',
    'Full body',
    'Cardio',
  ];

  static const List<String> fitnessLevels = [
    'beginner',
    'intermediate',
    'advanced',
  ];

  static const List<String> dailyChallenges = [
    'Do 30 squats before lunch',
    'Take a 20-minute brisk walk',
    'Hold a plank for 60 seconds',
    'Drink a glass of water right now',
    'Stretch for 10 minutes tonight',
    'Try one new exercise today',
    'Finish 3 sets of push-ups',
  ];
}

class GoalType {
  static const String workoutsPerWeek = 'workouts_per_week';
  static const String waterDaily = 'water_daily';
  static const String stepsDaily = 'steps_daily';
}
