import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';

import 'screens/admin_dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'screens/task_list_screen.dart';
import 'services/api_service.dart';
import 'services/auth_session.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';
import 'theme/theme_mode_scope.dart';

// ── Background Task Name ───────────────────────────────────────────────────────
const _kDeadlineCheckTask = 'deadline_check_task';

/// Callback yang dijalankan oleh Workmanager di background isolate.
/// HARUS top-level function (tidak boleh di dalam class).
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName == _kDeadlineCheckTask) {
      // Inisialisasi notifikasi dulu karena ini isolate baru
      await NotificationService.init();
      await NotificationService.checkAndNotifyDeadlines();
    }
    return Future.value(true);
  });
}

// ── Theme Controller ───────────────────────────────────────────────────────────
final ThemeModeController themeModeNotifier = ThemeModeController();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Init notifikasi
  await NotificationService.init();

  // Init workmanager untuk background task
  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: false,
  );

  // Daftarkan background task: cek deadline setiap 1 jam
  await Workmanager().registerPeriodicTask(
    _kDeadlineCheckTask,
    _kDeadlineCheckTask,
    frequency: const Duration(hours: 1),
    constraints: Constraints(
      networkType: NetworkType.not_required,
    ),
    existingWorkPolicy: ExistingWorkPolicy.keep,
  );

  await themeModeNotifier.loadPreference();
  runApp(const SchoolTaskApp());
}

class SchoolTaskApp extends StatefulWidget {
  const SchoolTaskApp({super.key});

  @override
  State<SchoolTaskApp> createState() => _SchoolTaskAppState();
}

class _SchoolTaskAppState extends State<SchoolTaskApp> {
  late final AuthSession session;
  late final Future<bool> _restoreSessionFuture;

  @override
  void initState() {
    super.initState();
    session = AuthSession(ApiService());
    _restoreSessionFuture = session.restoreSession();
  }

  @override
  Widget build(BuildContext context) {
    return ThemeModeScope(
      controller: themeModeNotifier,
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: themeModeNotifier,
        builder: (context, themeMode, child) {
          return MaterialApp(
            title: 'Tugas Sekolah',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeMode,
            home: FutureBuilder<bool>(
              future: _restoreSessionFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const _SessionRestoreScreen();
                }

                if (snapshot.data == true) {
                  // Routing berdasarkan role
                  if (session.user?.isAdmin == true) {
                    return AdminDashboardScreen(session: session);
                  }
                  return TaskListScreen(session: session);
                }

                return LoginScreen(session: session);
              },
            ),
          );
        },
      ),
    );
  }
}

class _SessionRestoreScreen extends StatelessWidget {
  const _SessionRestoreScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
