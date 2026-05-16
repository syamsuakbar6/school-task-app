import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kTasksCacheKey = 'cached_tasks_for_notification';
const _kDeadlineNotificationStateKey = 'deadline_notification_state';
const _kDeadlineWarningHours = 24;
const _kDeadlineCooldownHours = 6;

class NotificationService {
  NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    debugPrint('NotificationService: initialized');
  }

  static void _onNotificationTap(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
  }

  static Future<void> showSubmitSuccess(String taskTitle) async {
    await _plugin.show(
      1001,
      'Tugas berhasil dikirim',
      'Kamu sudah mengumpulkan "$taskTitle". Tunggu penilaian dari guru.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'submit_channel',
          'Pengumpulan Tugas',
          channelDescription: 'Notifikasi konfirmasi pengumpulan tugas',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  static Future<void> showDeadlineWarning({
    required int taskId,
    required String taskTitle,
    required String deadlineText,
  }) async {
    await _plugin.show(
      taskId,
      'Deadline mendekat',
      '"$taskTitle" batas waktu: $deadlineText',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'deadline_channel',
          'Deadline Tugas',
          channelDescription: 'Notifikasi tugas yang mendekati deadline',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: Color(0xFFFFA000),
        ),
      ),
      payload: taskId.toString(),
    );
  }

  static Future<void> cacheTasks(List<Map<String, dynamic>> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTasksCacheKey, jsonEncode(tasks));
    await _cleanupInactiveDeadlineNotifications(prefs, tasks);
    debugPrint('NotificationService: cached ${tasks.length} tasks');
  }

  static Future<List<Map<String, dynamic>>> getCachedTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kTasksCacheKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  static Future<void> checkAndNotifyDeadlines() async {
    final tasks = await getCachedTasks();
    if (tasks.isEmpty) {
      debugPrint('NotificationService: no cached tasks to check');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final notificationState = _decodeNotificationState(
      prefs.getString(_kDeadlineNotificationStateKey),
    );
    final now = DateTime.now().toUtc();
    final warningThreshold = now.add(
      const Duration(hours: _kDeadlineWarningHours),
    );
    final activeTaskIds = <String>{};

    var notifCount = 0;

    for (final task in tasks) {
      final deadlineStr = task['deadline'] as String?;
      final submitted = task['submitted'] as bool? ?? false;
      final hidden = task['hidden'] as bool? ?? false;
      final taskId = task['id'] as int?;
      final taskTitle = task['title'] as String? ?? 'Tugas';

      if (deadlineStr == null || submitted || hidden || taskId == null) {
        await _plugin.cancel(taskId ?? 0);
        if (taskId != null) notificationState.remove(taskId.toString());
        continue;
      }
      final taskKey = taskId.toString();
      activeTaskIds.add(taskKey);

      final deadline = DateTime.tryParse(deadlineStr)?.toUtc();
      if (deadline == null) continue;

      if (deadline.isBefore(now)) {
        await _plugin.cancel(taskId);
        notificationState.remove(taskKey);
        continue;
      }
      if (deadline.isAfter(warningThreshold)) continue;
      if (!_canSendDeadlineWarning(notificationState[taskKey], now)) continue;

      final difference = deadline.difference(now);
      final hoursLeft = difference.inHours;
      final minutesLeft = difference.inMinutes % 60;

      final deadlineText = hoursLeft == 0
          ? '$minutesLeft menit lagi'
          : minutesLeft == 0
              ? '$hoursLeft jam lagi'
              : '$hoursLeft jam $minutesLeft menit lagi';

      await showDeadlineWarning(
        taskId: taskId,
        taskTitle: taskTitle,
        deadlineText: deadlineText,
      );
      notificationState[taskKey] = now.toIso8601String();
      notifCount++;
    }

    notificationState
        .removeWhere((taskId, _) => !activeTaskIds.contains(taskId));
    await prefs.setString(
      _kDeadlineNotificationStateKey,
      jsonEncode(notificationState),
    );
    debugPrint('NotificationService: sent $notifCount deadline notifications');
  }

  static bool _canSendDeadlineWarning(String? lastSentRaw, DateTime now) {
    if (lastSentRaw == null || lastSentRaw.isEmpty) return true;
    final lastSentAt = DateTime.tryParse(lastSentRaw)?.toUtc();
    if (lastSentAt == null) return true;
    return now.difference(lastSentAt) >=
        const Duration(hours: _kDeadlineCooldownHours);
  }

  static Map<String, String> _decodeNotificationState(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return {};
      return decoded.map((key, value) => MapEntry(key, value.toString()));
    } catch (_) {
      return {};
    }
  }

  static Future<void> _cleanupInactiveDeadlineNotifications(
    SharedPreferences prefs,
    List<Map<String, dynamic>> tasks,
  ) async {
    final notificationState = _decodeNotificationState(
      prefs.getString(_kDeadlineNotificationStateKey),
    );
    var changed = false;

    for (final task in tasks) {
      final taskId = task['id'] as int?;
      if (taskId == null) continue;
      final submitted = task['submitted'] as bool? ?? false;
      final hidden = task['hidden'] as bool? ?? false;
      final deadlineStr = task['deadline'] as String?;
      if (!submitted && !hidden && deadlineStr != null) continue;

      await _plugin.cancel(taskId);
      changed = notificationState.remove(taskId.toString()) != null || changed;
    }

    if (changed) {
      await prefs.setString(
        _kDeadlineNotificationStateKey,
        jsonEncode(notificationState),
      );
    }
  }
}
