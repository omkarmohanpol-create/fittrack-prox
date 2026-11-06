import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Local-only reminders (no push service), per the project's decisions.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const int workoutReminderId = 1;
  static const int _waterBaseId = 100; // 100 + hour

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));

      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await _plugin.initialize(settings);
      _ready = true;
    } catch (e) {
      debugPrint('Notifications unavailable: $e');
    }
  }

  Future<bool> requestPermission() async {
    if (!_ready) return false;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final a = await android?.requestNotificationsPermission();
    final i = await ios?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    return (a ?? i ?? true);
  }

  NotificationDetails _details(String channelId, String channelName) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: const DarwinNotificationDetails(),
    );
  }

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var next =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
    return next;
  }

  Future<void> _scheduleDaily({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
    required NotificationDetails details,
  }) async {
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      _nextInstanceOf(hour, minute),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> scheduleWorkoutReminder(TimeOfDay time) async {
    if (!_ready) return;
    await _scheduleDaily(
      id: workoutReminderId,
      hour: time.hour,
      minute: time.minute,
      title: 'Time to move',
      body: 'Your workout is waiting. Log it when you are done.',
      details: _details('workout_reminders', 'Workout reminders'),
    );
  }

  Future<void> cancelWorkoutReminder() async {
    if (!_ready) return;
    await _plugin.cancel(workoutReminderId);
  }

  /// Daily water nudges every [everyHours] between [startHour] and [endHour].
  Future<void> scheduleWaterReminders({
    int startHour = 9,
    int endHour = 21,
    int everyHours = 2,
  }) async {
    if (!_ready) return;
    await cancelWaterReminders();
    for (var h = startHour; h <= endHour; h += everyHours) {
      await _scheduleDaily(
        id: _waterBaseId + h,
        hour: h,
        minute: 0,
        title: 'Hydration check',
        body: 'Time for a glass of water.',
        details: _details('water_reminders', 'Water reminders'),
      );
    }
  }

  Future<void> cancelWaterReminders() async {
    if (!_ready) return;
    for (var h = 0; h < 24; h++) {
      await _plugin.cancel(_waterBaseId + h);
    }
  }
}
