import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeModeController extends ValueNotifier<ThemeMode> {
  ThemeModeController({
    ThemeMode initialMode = ThemeMode.system,
    SharedPreferences? preferences,
  })  : _preferences = preferences,
        super(initialMode);

  static const preferenceKey = 'theme_mode';

  SharedPreferences? _preferences;

  Future<void> loadPreference() async {
    final preferences = await SharedPreferences.getInstance();
    _preferences = preferences;
    value = fromPreference(preferences.getString(preferenceKey));
  }

  Future<void> setMode(ThemeMode mode) async {
    value = mode;
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    _preferences = preferences;
    await preferences.setString(preferenceKey, mode.preferenceValue);
  }

  Future<void> toggleFromBrightness(Brightness brightness) {
    return setMode(
      brightness == Brightness.dark ? ThemeMode.light : ThemeMode.dark,
    );
  }

  static ThemeMode fromPreference(String? value) {
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }
}

extension ThemeModePreference on ThemeMode {
  String get preferenceValue {
    return switch (this) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
  }
}

class ThemeModeScope extends InheritedNotifier<ThemeModeController> {
  const ThemeModeScope({
    super.key,
    required ThemeModeController controller,
    required super.child,
  }) : super(notifier: controller);

  static ThemeModeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeModeScope>();
    assert(scope?.notifier != null, 'ThemeModeScope not found in context.');
    return scope!.notifier!;
  }
}
