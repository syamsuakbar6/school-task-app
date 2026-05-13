import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
/// Key untuk menyimpan daftar task di SharedPreferences
/// supaya background service bisa baca tanpa harus hit API.
const _kTasksCacheKey = 'cached_tasks_for_notification';

/// Berapa jam sebelum deadline kita kirim notifikasi.
const _kDeadlineWarningHours = 24;

class NotificationService {
  NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();

  // ── Init ─────────────────────────────────────────────────────────────────

  static Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Minta permission notifikasi (Android 13+)
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    debugPrint('NotificationService: initialized');
  }

  static void _onNotificationTap(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    // Bisa tambah navigasi ke task detail di sini kalau mau nanti
  }

  // ── Show Notifications ────────────────────────────────────────────────────

  /// Tampilkan notifikasi sukses submit tugas — dipanggil dari UI.
  static Future<void> showSubmitSuccess(String taskTitle) async {
    await _plugin.show(
      1001,
      '✅ Tugas Berhasil Dikirim!',
      'Kamu sudah submit "$taskTitle". Tunggu penilaian dari guru.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'submit_channel',
          'Submit Tugas',
          channelDescription: 'Notifikasi konfirmasi submit tugas',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  /// Tampilkan notifikasi deadline — dipanggil dari background task.
  static Future<void> showDeadlineWarning({
    required int taskId,
    required String taskTitle,
    required String deadlineText,
  }) async {
    await _plugin.show(
      taskId, // pakai task ID supaya tidak duplikat
      '⏰ Deadline Mendekat!',
      '"$taskTitle" — batas waktu: $deadlineText',
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

  // ── Cache Tasks ───────────────────────────────────────────────────────────

  /// Simpan daftar task ke SharedPreferences setelah fetch dari API.
  /// Format: list of {id, title, deadline (ISO string), submitted}
  static Future<void> cacheTasks(List<Map<String, dynamic>> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTasksCacheKey, jsonEncode(tasks));
    debugPrint('NotificationService: cached ${tasks.length} tasks');
  }

  /// Baca task dari cache (dipakai oleh background service).
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

  // ── Check Deadlines ───────────────────────────────────────────────────────

  /// Cek task mana yang deadlinenya < 24 jam dan belum disubmit,
  /// lalu kirim notifikasi untuk masing-masing.
  /// Dipanggil dari background isolate (workmanager) ATAU saat app dibuka.
  static Future<void> checkAndNotifyDeadlines() async {
    final tasks = await getCachedTasks();
    if (tasks.isEmpty) {
      debugPrint('NotificationService: no cached tasks to check');
      return;
    }

    final now = DateTime.now().toUtc();
    final warningThreshold = now.add(
      const Duration(hours: _kDeadlineWarningHours),
    );

    int notifCount = 0;

    for (final task in tasks) {
      final deadlineStr = task['deadline'] as String?;
      final submitted = task['submitted'] as bool? ?? false;
      final taskId = task['id'] as int?;
      final taskTitle = task['title'] as String? ?? 'Tugas';

      if (deadlineStr == null || submitted || taskId == null) continue;

      final deadline = DateTime.tryParse(deadlineStr)?.toUtc();
      if (deadline == null) continue;

      // Sudah lewat deadline → skip
      if (deadline.isBefore(now)) continue;

      // Deadline masih > 24 jam → skip
      if (deadline.isAfter(warningThreshold)) continue;

      // Dalam rentang 0–24 jam → kirim notifikasi
      final hoursLeft = deadline.difference(now).inHours;
      final minutesLeft = deadline.difference(now).inMinutes % 60;

      String deadlineText;
      if (hoursLeft == 0) {
        deadlineText = '$minutesLeft menit lagi!';
      } else if (minutesLeft == 0) {
        deadlineText = '$hoursLeft jam lagi';
      } else {
        deadlineText = '$hoursLeft jam $minutesLeft menit lagi';
      }

      await showDeadlineWarning(
        taskId: taskId,
        taskTitle: taskTitle,
        deadlineText: deadlineText,
      );
      notifCount++;
    }

    debugPrint('NotificationService: sent $notifCount deadline notifications');
  }
}
