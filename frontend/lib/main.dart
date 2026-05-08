import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
import 'services/api_service.dart';
import 'services/auth_session.dart';
import 'theme/app_theme.dart';
import 'theme/theme_mode_scope.dart';

final ThemeModeController themeModeNotifier = ThemeModeController();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

  @override
  void initState() {
    super.initState();
    session = AuthSession(ApiService());
  }

  @override
  Widget build(BuildContext context) {
    return ThemeModeScope(
      controller: themeModeNotifier,
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: themeModeNotifier,
        builder: (context, themeMode, child) {
          return MaterialApp(
            title: 'School Tasks',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeMode,
            home: LoginScreen(session: session),
          );
        },
      ),
    );
  }
}
