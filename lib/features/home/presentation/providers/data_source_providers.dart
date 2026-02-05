import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:relay/core/constants/data_source_mode.dart';
import 'package:relay/core/models/data_source_config.dart';
import 'package:relay/core/services/data_source_preferences_service.dart';

/// Current data source mode and API config (loaded from prefs, then mutable).
class DataSourceStateNotifier extends StateNotifier<AsyncValue<({DataSourceMode mode, DataSourceConfig config})>> {
  DataSourceStateNotifier() : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final mode = await DataSourcePreferencesService.loadMode();
      final config = await DataSourcePreferencesService.loadConfig();
      state = AsyncValue.data((mode: mode, config: config));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setMode(DataSourceMode mode) async {
    await DataSourcePreferencesService.saveMode(mode);
    final current = state.asData?.value;
    state = AsyncValue.data((
      mode: mode,
      config: current?.config ?? const DataSourceConfig(baseUrl: '', apiKey: null),
    ));
  }

  Future<void> setConfig(DataSourceConfig config) async {
    await DataSourcePreferencesService.saveConfig(config);
    final current = state.asData?.value;
    state = AsyncValue.data((mode: current?.mode ?? DataSourceMode.local, config: config));
  }
}

final dataSourceStateNotifierProvider =
    StateNotifierProvider<DataSourceStateNotifier, AsyncValue<({DataSourceMode mode, DataSourceConfig config})>>((ref) {
  return DataSourceStateNotifier();
});
