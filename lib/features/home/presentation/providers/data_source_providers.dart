import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/core/constants/data_source_mode.dart';
import 'package:relay/core/models/data_source_config.dart';
import 'package:relay/core/services/data_source_preferences_service.dart';

/// Current data source mode and API config (loaded from prefs, then mutable).
class DataSourceStateNotifier extends AsyncNotifier<({DataSourceMode mode, DataSourceConfig config})> {
  @override
  Future<({DataSourceMode mode, DataSourceConfig config})> build() async {
    final mode = await DataSourcePreferencesService.loadMode();
    final config = await DataSourcePreferencesService.loadConfig();
    final resolvedMode = mode == DataSourceMode.api && !config.isValid ? DataSourceMode.local : mode;
    if (resolvedMode != mode) {
      await DataSourcePreferencesService.saveMode(resolvedMode);
    }
    return (mode: resolvedMode, config: config);
  }

  Future<bool> setMode(DataSourceMode mode) async {
    final current = state.asData?.value;
    final config = current?.config ?? await DataSourcePreferencesService.loadConfig();
    final resolvedMode = mode == DataSourceMode.api && !config.isValid ? DataSourceMode.local : mode;

    await DataSourcePreferencesService.saveMode(resolvedMode);
    state = AsyncData((mode: resolvedMode, config: config));

    return resolvedMode == mode;
  }

  Future<void> setConfig(DataSourceConfig config) async {
    await DataSourcePreferencesService.saveConfig(config);
    final current = state.asData?.value;
    state = AsyncData((mode: current?.mode ?? DataSourceMode.local, config: config));
  }
}

final dataSourceStateNotifierProvider = AsyncNotifierProvider<DataSourceStateNotifier, ({DataSourceMode mode, DataSourceConfig config})>(
  DataSourceStateNotifier.new,
);

final currentDataSourceStateProvider = Provider<({DataSourceMode mode, DataSourceConfig config})?>((ref) {
  return ref.watch(dataSourceStateNotifierProvider).asData?.value;
});
