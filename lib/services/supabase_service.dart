import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';

/// Thin wrapper over Supabase. When SUPABASE_URL / SUPABASE_ANON_KEY were not
/// supplied via --dart-define, [isConfigured] is false and the app runs in a
/// local-only guest mode (data is kept on the device).
class SupabaseService {
  static bool _configured = false;

  static bool get isConfigured => _configured;

  static SupabaseClient get client => Supabase.instance.client;

  static String? get userId => _configured ? client.auth.currentUser?.id : null;

  /// True when there is a signed-in Supabase user to sync data for.
  static bool get canSync => userId != null;

  static Future<void> initialize() async {
    if (AppConstants.supabaseUrl.isEmpty ||
        AppConstants.supabaseAnonKey.isEmpty) {
      _configured = false;
      return;
    }
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
    );
    _configured = true;
  }

  /// True when [e] means the row already exists (Postgres unique violation),
  /// which for a retried insert means the first attempt went through.
  static bool isDuplicate(Object e) =>
      e is PostgrestException && e.code == '23505';

  // ---------------------------------------------------------------- profile

  static Future<Map<String, dynamic>?> fetchProfile() async {
    final uid = userId;
    if (uid == null) return null;
    return client.from('users').select().eq('id', uid).maybeSingle();
  }

  static Future<void> updateProfile({
    required String fullName,
    required String fitnessLevel,
  }) async {
    final uid = userId;
    if (uid == null) return;
    await client.from('users').update({
      'full_name': fullName,
      'fitness_level': fitnessLevel,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', uid);
  }

  // ----------------------------------------------------------------- avatar

  /// Uploads the picture to `avatars/<user id>/avatar.<ext>`, saves its public
  /// URL on the profile and returns that URL.
  static Future<String> uploadAvatar(Uint8List bytes, {required bool png}) async {
    final uid = userId!;
    final ext = png ? 'png' : 'jpg';
    final path = '$uid/avatar.$ext';
    final bucket = client.storage.from(AppConstants.avatarBucket);
    await bucket.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        contentType: png ? 'image/png' : 'image/jpeg',
        upsert: true,
      ),
    );
    // Remove the other format so only one avatar file is kept.
    await bucket.remove(['$uid/avatar.${png ? 'jpg' : 'png'}']);
    // The query string makes image caches fetch the new picture.
    final url =
        '${bucket.getPublicUrl(path)}?v=${DateTime.now().millisecondsSinceEpoch}';
    await _setAvatarUrl(url);
    return url;
  }

  static Future<void> removeAvatar() async {
    final uid = userId!;
    await client.storage
        .from(AppConstants.avatarBucket)
        .remove(['$uid/avatar.jpg', '$uid/avatar.png']);
    await _setAvatarUrl(null);
  }

  static Future<void> _setAvatarUrl(String? url) async {
    await client.from('users').update({
      'avatar_url': url,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', userId!);
  }

  // ---------------------------------------------------------------- account

  /// Deletes the account and all of its data through the `delete-account`
  /// Edge Function (supabase/functions/delete-account). The service-role key
  /// it needs stays on the server.
  static Future<void> deleteAccount() async {
    final res = await client.functions.invoke('delete-account');
    if (res.status != 200) {
      throw Exception('delete-account returned ${res.status}');
    }
  }

  // --------------------------------------------------------------- workouts

  static Future<List<Workout>> fetchWorkouts({required DateTime since}) async {
    final rows = await client
        .from('workouts')
        .select('*, workout_exercises(*)')
        .gte('date', Formatters.isoDate(since))
        .order('date', ascending: false)
        .order('created_at', ascending: false)
        .order('order_index', referencedTable: 'workout_exercises');
    return (rows as List)
        .map((r) => Workout.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Inserts or updates the workout (matched by id) and replaces its exercises
  /// in one transaction (`save_workout` in supabase/schema.sql). Safe to retry.
  static Future<void> saveWorkout(Workout w) async {
    await client.rpc('save_workout', params: w.toSaveParams());
  }

  static Future<void> deleteWorkout(String id) async {
    await client.from('workouts').delete().eq('id', id);
  }

  // ------------------------------------------------------------------ water

  static Future<List<WaterLog>> fetchWaterLogs({required DateTime since}) async {
    final rows = await client
        .from('water_logs')
        .select()
        .gte('date', Formatters.isoDate(since))
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => WaterLog.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Inserts the entry with the id made on the device. A retry of an entry
  /// that already arrived is ignored instead of creating a duplicate.
  static Future<void> insertWaterLog(WaterLog log) async {
    await client.from('water_logs').upsert(
      {
        'id': log.id,
        'user_id': userId,
        'amount_ml': log.amountMl,
        'date': Formatters.isoDate(log.date),
      },
      onConflict: 'id',
      ignoreDuplicates: true,
    );
  }

  static Future<void> deleteWaterLog(String id) async {
    await client.from('water_logs').delete().eq('id', id);
  }

  // ------------------------------------------------------------------ goals

  static Future<List<Goal>> fetchGoals() async {
    final rows = await client.from('goals').select();
    return (rows as List)
        .map((r) => Goal.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  static Future<void> upsertGoal(Goal g) async {
    await client.from('goals').upsert({
      'user_id': userId,
      'goal_type': g.goalType,
      'target_value': g.targetValue,
      'period': g.period,
      'is_active': g.isActive,
    }, onConflict: 'user_id,goal_type');
  }

  // ------------------------------------------------------- custom exercises

  static Future<List<ExerciseDef>> fetchCustomExercises() async {
    final rows = await client
        .from('custom_exercises')
        .select('id, name, muscle_group')
        .order('name');
    return (rows as List)
        .map((r) => ExerciseDef.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  static Future<void> insertCustomExercise(ExerciseDef e) async {
    await client.from('custom_exercises').insert({
      'id': e.id,
      'user_id': userId,
      'name': e.name,
      'muscle_group': e.muscleGroup,
    });
  }

  static Future<void> deleteCustomExercise(String id) async {
    await client.from('custom_exercises').delete().eq('id', id);
  }

  // ------------------------------------------------------ body measurements

  static Future<List<BodyMeasurement>> fetchMeasurements() async {
    final rows = await client
        .from('body_measurements')
        .select()
        .order('date', ascending: false)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => BodyMeasurement.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  static Future<void> insertMeasurement(BodyMeasurement m) async {
    await client
        .from('body_measurements')
        .upsert(m.toInsertJson(userId!), onConflict: 'id');
  }

  static Future<void> deleteMeasurement(String id) async {
    await client.from('body_measurements').delete().eq('id', id);
  }

  // ------------------------------------------------------------------ steps

  static Future<Map<DateTime, int>> fetchSteps({required DateTime since}) async {
    final rows = await client
        .from('daily_steps')
        .select('date, steps')
        .gte('date', Formatters.isoDate(since));
    return {
      for (final r in (rows as List).cast<Map<String, dynamic>>())
        DateTime.parse(r['date'] as String): (r['steps'] as num).toInt(),
    };
  }

  static Future<void> upsertSteps(DateTime day, int steps) async {
    await client.from('daily_steps').upsert({
      'user_id': userId,
      'date': Formatters.isoDate(day),
      'steps': steps,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id,date');
  }
}
