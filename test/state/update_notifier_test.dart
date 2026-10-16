import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:relay/core/updates/release_checker.dart';
import 'package:relay/state/settings_providers.dart';
import 'package:relay/state/update_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this._respond);

  final Future<ResponseBody> Function(RequestOptions options) _respond;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) => _respond(options);
}

ResponseBody _redirect(String tag) => ResponseBody.fromString(
  '',
  302,
  headers: {
    'location': ['https://github.com/role-suite/role-client/releases/tag/$tag'],
  },
);

ResponseBody _rateLimited() => ResponseBody.fromString(
  '',
  403,
  headers: {
    'x-ratelimit-remaining': ['0'],
  },
);

Future<ProviderContainer> _container({Map<String, Object> prefs = const {}, Future<ResponseBody> Function(RequestOptions options)? respond}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sharedPreferences = await SharedPreferences.getInstance();
  PackageInfo.setMockInitialValues(appName: 'Röle', packageName: 'com.devora.relay', version: '1.1.0', buildNumber: '3', buildSignature: '');

  final dio = Dio()..httpClientAdapter = _ScriptedAdapter(respond ?? (_) async => _redirect('v1.1.0'));
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      releaseCheckerProvider.overrideWithValue(ReleaseChecker(dio: dio)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('loads the current version and persisted update state', () async {
    final container = await _container(
      prefs: {'updates.availableTag': 'v1.2.0', 'updates.availableUrl': 'https://example.com/v1.2.0', 'updates.dismissedTag': 'v1.2.0'},
    );

    final state = await container.read(updateNotifierProvider.future);
    expect(state.currentVersion, '1.1.0');
    expect(state.displayVersion, '1.1.0+3');
    expect(state.updateAvailable, isTrue);
    expect(state.showBadge, isFalse, reason: 'dismissed for this tag');
  });

  test('manual check finds a newer release and persists it', () async {
    final container = await _container(respond: (_) async => _redirect('v1.2.0'));
    await container.read(updateNotifierProvider.future);

    await container.read(updateNotifierProvider.notifier).checkForUpdates();

    final state = container.read(updateNotifierProvider).value!;
    expect(state.updateAvailable, isTrue);
    expect(state.availableTag, 'v1.2.0');
    expect(state.latest?.tagName, 'v1.2.0');
    expect(state.errorMessage, isNull);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('updates.availableTag'), 'v1.2.0');
    expect(prefs.getString('updates.lastAttemptAt'), isNotNull);
  });

  test('checking against the running version clears stale update info', () async {
    final container = await _container(
      prefs: {'updates.availableTag': 'v1.1.0', 'updates.availableUrl': 'https://example.com/v1.1.0'},
      respond: (_) async => _redirect('v1.1.0'),
    );
    await container.read(updateNotifierProvider.future);

    await container.read(updateNotifierProvider.notifier).checkForUpdates();

    final state = container.read(updateNotifierProvider).value!;
    expect(state.updateAvailable, isFalse);
    expect(state.availableTag, isNull);
    expect(state.latest?.tagName, 'v1.1.0');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('updates.availableTag'), isNull);
  });

  test('a failed check surfaces an error, keeps prior state, and persists the attempt', () async {
    final container = await _container(
      prefs: {'updates.availableTag': 'v1.2.0', 'updates.availableUrl': 'https://example.com/v1.2.0'},
      respond: (_) async => _rateLimited(),
    );
    await container.read(updateNotifierProvider.future);

    await container.read(updateNotifierProvider.notifier).checkForUpdates();

    final state = container.read(updateNotifierProvider).value!;
    expect(state.errorMessage, contains('rate-limiting'));
    expect(state.updateAvailable, isTrue, reason: 'the previously known release stays visible');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('updates.lastAttemptAt'), isNotNull);
  });

  test('dismiss hides the badge for the current tag only', () async {
    final container = await _container(prefs: {'updates.availableTag': 'v1.2.0', 'updates.availableUrl': 'https://example.com/v1.2.0'});
    await container.read(updateNotifierProvider.future);

    await container.read(updateNotifierProvider.notifier).dismissUpdate();

    final state = container.read(updateNotifierProvider).value!;
    expect(state.showBadge, isFalse);
    expect(state.updateAvailable, isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('updates.dismissedTag'), 'v1.2.0');
  });

  test('enabling automatic checks persists the flag and checks immediately', () async {
    var fetches = 0;
    final container = await _container(
      respond: (_) async {
        fetches++;
        return _redirect('v1.2.0');
      },
    );
    await container.read(updateNotifierProvider.future);

    await container.read(updateNotifierProvider.notifier).setAutoCheck(true);

    expect(fetches, 1);
    expect(container.read(updateNotifierProvider).value!.autoCheckEnabled, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('updates.autoCheck'), isTrue);
  });

  test('automatic check runs when the last attempt is stale', () async {
    var fetches = 0;
    final stale = DateTime.now().subtract(const Duration(days: 2)).toIso8601String();
    final container = await _container(
      prefs: {'updates.autoCheck': true, 'updates.lastAttemptAt': stale},
      respond: (_) async {
        fetches++;
        return _redirect('v1.2.0');
      },
    );

    final initial = await container.read(updateNotifierProvider.future);
    await pumpEventQueue();

    expect(fetches, 1);
    final state = container.read(updateNotifierProvider).value!;
    expect(state.lastAttemptAt!.isAfter(DateTime.parse(stale)), isTrue);
    expect(initial.autoCheckEnabled, isTrue);
  });

  test('automatic check is skipped when a recent attempt exists', () async {
    var fetches = 0;
    final container = await _container(
      prefs: {'updates.autoCheck': true, 'updates.lastAttemptAt': DateTime.now().toIso8601String()},
      respond: (_) async {
        fetches++;
        return _redirect('v1.2.0');
      },
    );

    await container.read(updateNotifierProvider.future);
    await pumpEventQueue();

    expect(fetches, 0);
  });

  test('a recent failed attempt also suppresses the next automatic check', () async {
    var fetches = 0;
    final failedAt = DateTime.now().subtract(const Duration(hours: 1)).toIso8601String();
    final container = await _container(
      prefs: {'updates.autoCheck': true, 'updates.lastAttemptAt': failedAt},
      respond: (_) async {
        fetches++;
        return _rateLimited();
      },
    );

    await container.read(updateNotifierProvider.future);
    await pumpEventQueue();

    expect(fetches, 0, reason: 'failures must not retry on every launch');
  });

  test('reads the legacy last-checked key written by v1.1.1', () async {
    final container = await _container(prefs: {'updates.lastCheckedAt': DateTime.now().toIso8601String()});
    final state = await container.read(updateNotifierProvider.future);
    expect(state.lastAttemptAt, isNotNull);
  });
}
