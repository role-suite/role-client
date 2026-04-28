import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/constants/data_source_mode.dart';
import 'package:relay/core/models/data_source_config.dart';
import 'package:relay/core/services/relay_api/auth_api_client.dart';
import 'package:relay/features/home/presentation/providers/data_source_providers.dart';
import 'package:relay/features/home/presentation/providers/profile_providers.dart';

class _FakeAuthApiClient extends AuthApiClient {
  _FakeAuthApiClient(this.meResponse) : super(baseUrl: 'https://example.com');

  final Map<String, dynamic> meResponse;

  @override
  Future<Map<String, dynamic>> me(String accessToken) async => meResponse;
}

ProviderContainer _containerWithMePayload(Map<String, dynamic> payload) {
  return ProviderContainer(
    overrides: [
      currentDataSourceStateProvider.overrideWithValue(
        (
          mode: DataSourceMode.api,
          config: const DataSourceConfig(baseUrl: 'https://example.com', apiKey: 'token'),
        ),
      ),
      profileApiClientProvider.overrideWithValue(_FakeAuthApiClient(payload)),
    ],
  );
}

void main() {
  test('userProfileProvider parses profile from data.user shape', () async {
    final container = _containerWithMePayload({
      'data': {
        'user': {
          'id': 'u-1',
          'name': 'Ada Lovelace',
          'email': 'ada@example.com',
          'accountType': 'team',
        },
      },
    });
    addTearDown(container.dispose);

    final profile = await container.read(userProfileProvider.future);
    expect(profile, isNotNull);
    expect(profile?.id, 'u-1');
    expect(profile?.name, 'Ada Lovelace');
  });

  test('userProfileProvider parses profile from result.user shape', () async {
    final container = _containerWithMePayload({
      'result': {
        'user': {
          'id': 'u-2',
          'displayName': 'Grace Hopper',
          'email': 'grace@example.com',
        },
      },
    });
    addTearDown(container.dispose);

    final profile = await container.read(userProfileProvider.future);
    expect(profile, isNotNull);
    expect(profile?.id, 'u-2');
    expect(profile?.displayName, 'Grace Hopper');
  });

  test('userProfileProvider returns null when payload is empty', () async {
    final container = _containerWithMePayload(const {});
    addTearDown(container.dispose);

    final profile = await container.read(userProfileProvider.future);
    expect(profile, isNull);
  });
}
