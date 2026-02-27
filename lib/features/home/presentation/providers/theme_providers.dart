import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/core/services/theme_service.dart';

final themeServiceProvider = Provider<ThemeService>((ref) => ThemeService());

class ThemeModeNotifier extends Notifier<ThemeMode> {
  late final ThemeService _themeService;

  @override
  ThemeMode build() {
    _themeService = ref.watch(themeServiceProvider);
    _loadThemeMode();
    return ThemeMode.system;
  }

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

final themeModeNotifierProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
