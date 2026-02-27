import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/core/constants/data_source_mode.dart';
import 'package:relay/features/home/presentation/providers/data_source_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('data source falls back to local when api config is invalid', () async {
    SharedPreferences.setMockInitialValues({'data_source_mode': 'api', 'data_source_api_base_url': '', 'data_source_api_style': 'rest'});

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final state = await container.read(dataSourceStateNotifierProvider.future);

    expect(state.mode, DataSourceMode.local);
    expect(state.config.baseUrl, '');
  });

  test('setMode returns false for api when config is invalid', () async {
    SharedPreferences.setMockInitialValues({'data_source_mode': 'local', 'data_source_api_base_url': '', 'data_source_api_style': 'rest'});

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(dataSourceStateNotifierProvider.future);
    final changed = await container.read(dataSourceStateNotifierProvider.notifier).setMode(DataSourceMode.api);
    final latest = await container.read(dataSourceStateNotifierProvider.future);

    expect(changed, isFalse);
    expect(latest.mode, DataSourceMode.local);
  });
}
