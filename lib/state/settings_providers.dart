import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themeModeKey = 'settings.themeMode';
const _activeEnvironmentKey = 'settings.activeEnvironmentId';

/// Overridden in main() once SharedPreferences.getInstance() resolves.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden before use');
});

const _themeModeCycle = [ThemeMode.dark, ThemeMode.light, ThemeMode.system];

IconData themeModeIcon(ThemeMode mode) => switch (mode) {
  ThemeMode.dark => Icons.dark_mode_outlined,
  ThemeMode.light => Icons.light_mode_outlined,
  ThemeMode.system => Icons.brightness_auto_outlined,
};

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(_themeModeKey);
    return ThemeMode.values.firstWhere((m) => m.name == raw, orElse: () => ThemeMode.dark);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await ref.read(sharedPreferencesProvider).setString(_themeModeKey, mode.name);
  }

  Future<void> cycleThemeMode() {
    final next = _themeModeCycle[(_themeModeCycle.indexOf(state) + 1) % _themeModeCycle.length];
    return setThemeMode(next);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ActiveEnvironmentNotifier extends Notifier<String?> {
  @override
  String? build() {
    return ref.watch(sharedPreferencesProvider).getString(_activeEnvironmentKey);
  }

  Future<void> setActiveEnvironment(String? environmentId) async {
    state = environmentId;
    final prefs = ref.read(sharedPreferencesProvider);
    if (environmentId == null) {
      await prefs.remove(_activeEnvironmentKey);
    } else {
      await prefs.setString(_activeEnvironmentKey, environmentId);
    }
  }
}

final activeEnvironmentIdProvider = NotifierProvider<ActiveEnvironmentNotifier, String?>(ActiveEnvironmentNotifier.new);
