import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:relay/core/services/theme_service.dart';

final themeServiceProvider = Provider<ThemeService>((ref) => ThemeService());

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(this._themeService) : super(ThemeMode.system) {
    _loadThemeMode();
  }

  final ThemeService _themeService;

  Future<void> _loadThemeMode() async {
    final storedMode = await _themeService.loadThemeMode();
    if (storedMode != null) {
      state = storedMode;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await _themeService.saveThemeMode(mode);
  }
}

final themeModeNotifierProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(ref.watch(themeServiceProvider)),
);

