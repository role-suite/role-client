import 'dart:async';
import 'dart:collection';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/core/constants/data_source_mode.dart';
import 'package:relay/core/models/api_request_model.dart';
import 'package:relay/core/models/collection_model.dart';
import 'package:relay/core/models/data_source_config.dart';
import 'package:relay/core/models/environment_model.dart';
import 'package:relay/core/models/request_enums.dart';
import 'package:relay/core/services/relay_api/relay_api_client.dart';
import 'package:relay/core/services/relay_api/relay_api_http.dart';
import 'package:relay/core/services/relay_api/workspace_updates_api_client.dart';
import 'package:relay/core/utils/extension.dart';

import 'package:relay/features/home/collection/presentation/providers/collection_providers.dart';
import 'package:relay/features/home/environment/presentation/providers/environment_providers.dart';
import 'package:relay/features/home/request/presentation/providers/request_providers.dart';

import 'collection_selection_utils.dart';
import 'data_source_providers.dart';
import 'home_ui_providers.dart';
import 'repository_providers.dart';
import 'workspace_selection_providers.dart';
import 'package:relay/core/services/data_source_preferences_service.dart';

const Duration _defaultPollInterval = Duration(seconds: 4);
const Duration _offlineProbeInterval = Duration(seconds: 8);
const int _defaultPollLimit = 50;
const int _maxSeenEventIds = 1200;
const int _maxConsecutiveErrors = 5;

final workspaceUpdatesPollIntervalProvider = Provider<Duration>((ref) => _defaultPollInterval);
final workspaceUpdatesOfflineProbeIntervalProvider = Provider<Duration>((ref) => _offlineProbeInterval);
final workspaceUpdatesPollLimitProvider = Provider<int>((ref) => _defaultPollLimit);
final workspaceUpdatesInitialDelayProvider = Provider<Duration>((ref) => const Duration(milliseconds: 50));
final workspaceUpdatesObserveLifecycleProvider = Provider<bool>((ref) => true);

class WorkspaceUpdatesPollingErrorNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setError(String? message) {
    state = message;
  }
}

final workspaceUpdatesPollingErrorProvider = NotifierProvider<WorkspaceUpdatesPollingErrorNotifier, String?>(
  WorkspaceUpdatesPollingErrorNotifier.new,
);

final workspaceUpdatesApiFactoryProvider = Provider<WorkspaceUpdatesApi Function(String baseUrl, String accessToken, String? workspaceId)>((ref) {
  return (baseUrl, accessToken, workspaceId) => WorkspaceUpdatesApiClient(baseUrl: baseUrl, accessToken: accessToken, workspaceId: workspaceId);
});

final workspaceUpdatesPollingProvider = Provider<void>((ref) {
  final state = ref.watch(currentDataSourceStateProvider);
  if (state == null || state.mode != DataSourceMode.api || !state.config.isValid) {
    return;
  }

  final token = state.config.apiKey?.trim();
  if (token == null || token.isEmpty) {
    return;
  }

  final api = ref.watch(activeRelayApiClientProvider);
  if (api == null) {
    return;
  }

  final httpFactory = ref.watch(workspaceUpdatesApiFactoryProvider);
  final pollInterval = ref.watch(workspaceUpdatesPollIntervalProvider);
  final offlineProbeInterval = ref.watch(workspaceUpdatesOfflineProbeIntervalProvider);
  final pollLimit = ref.watch(workspaceUpdatesPollLimitProvider);
  final initialDelay = ref.watch(workspaceUpdatesInitialDelayProvider);
  final observeLifecycle = ref.watch(workspaceUpdatesObserveLifecycleProvider);

  final activeWorkspaceId = ref.watch(activeWorkspaceIdProvider).asData?.value;
  final poller = _WorkspaceUpdatesPoller(
    ref,
    api: api,
    http: httpFactory(state.config.baseUrl, token, activeWorkspaceId),
    pollInterval: pollInterval,
    offlineProbeInterval: offlineProbeInterval,
    pollLimit: pollLimit,
    initialDelay: initialDelay,
    observeLifecycle: observeLifecycle,
  );

  ref.onDispose(poller.dispose);
  poller.start();
});

class _WorkspaceUpdatesPoller with WidgetsBindingObserver {
  _WorkspaceUpdatesPoller(
    this._ref, {
    required RelayApiClient api,
    required WorkspaceUpdatesApi http,
    required Duration pollInterval,
    required Duration offlineProbeInterval,
    required int pollLimit,
    required Duration initialDelay,
    required bool observeLifecycle,
  }) : _api = api,
       _http = http,
       _pollInterval = pollInterval,
       _offlineProbeInterval = offlineProbeInterval,
       _pollLimit = pollLimit,
       _initialDelay = initialDelay,
       _observeLifecycle = observeLifecycle;

  final Ref _ref;
  final RelayApiClient _api;
  final WorkspaceUpdatesApi _http;
  final Duration _pollInterval;
  final Duration _offlineProbeInterval;
  final int _pollLimit;
  final Duration _initialDelay;
  final bool _observeLifecycle;

  Timer? _pollTimer;
  Timer? _offlineProbeTimer;
  bool _running = false;
  bool _pollInFlight = false;
  bool _appVisible = true;
  bool _offline = false;
  bool _authInvalid = false;
  bool _pausedByError = false;
  String? _activeWorkspaceId;

  int _consecutiveErrors = 0;
  int _offlineProbeFailures = 0;

  final Map<String, int> _cursorByWorkspaceId = <String, int>{};
  final Queue<String> _seenEventIdsOrder = Queue<String>();
  final Set<String> _seenEventIds = <String>{};

  void start() {
    if (_running) return;
    _running = true;
    Future<void>.delayed(Duration.zero, () {
      if (!_running) return;
      _resetErrorState();
    });
    if (_observeLifecycle) {
      WidgetsBinding.instance.addObserver(this);
    }
    _scheduleNextPoll(_initialDelay);
  }

  void dispose() {
    _running = false;
    _pollTimer?.cancel();
    _offlineProbeTimer?.cancel();
    if (_observeLifecycle) {
      WidgetsBinding.instance.removeObserver(this);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final visible = state == AppLifecycleState.resumed;
    _appVisible = visible;

    if (!_running) return;
    if (!visible) {
      _pollTimer?.cancel();
      return;
    }

    _resumePolling();
  }

  void _resumePolling() {
    if (_authInvalid || _pausedByError || !_running || !_appVisible) return;
    if (_offline) {
      _startOfflineProbe();
      return;
    }
    _scheduleNextPoll(_initialDelay);
  }

  void _scheduleNextPoll(Duration after) {
    _pollTimer?.cancel();
    if (!_running || !_appVisible || _offline || _authInvalid || _pausedByError) return;
    _pollTimer = Timer(after, () {
      unawaited(_pollOnce());
    });
  }

  Future<void> _pollOnce() async {
    if (!_running || !_appVisible || _offline || _authInvalid || _pausedByError || _pollInFlight) {
      return;
    }
    _pollInFlight = true;

    try {
      final workspaceId = await _http.resolveWorkspaceId();
      if (_activeWorkspaceId != workspaceId) {
        _activeWorkspaceId = workspaceId;
        _cursorByWorkspaceId[workspaceId] = 0;
        _seenEventIds.clear();
        _seenEventIdsOrder.clear();
      }

      final since = _cursorByWorkspaceId[workspaceId] ?? 0;
      final response = await _http.getUpdates(workspaceId: workspaceId, since: since, limit: _pollLimit);

      final parsed = _parseUpdatesResponse(response, fallbackSince: since);
      var shouldFullRefetch = false;
      for (final event in parsed.events) {
        final result = _applyEvent(event);
        if (result == _ApplyResult.requiresFullRefetch) {
          shouldFullRefetch = true;
        }
      }

      if (parsed.events.length >= _pollLimit) {
        shouldFullRefetch = true;
      }

      _cursorByWorkspaceId[workspaceId] = parsed.nextCursor;

      if (shouldFullRefetch) {
        await _fullRefetch();
      }

      _offline = false;
      _clearPollingError();
      _scheduleNextPoll(_pollInterval);
    } on RelayApiException catch (e) {
      if (e.isAuthError) {
        await _handleAuthInvalid();
      } else if (e.isOffline) {
        _handleOffline();
      } else {
        _recordFailure('Workspace updates paused after repeated errors.');
        if (!_pausedByError) {
          _scheduleNextPoll(_pollInterval);
        }
      }
    } catch (_) {
      _recordFailure('Workspace updates paused after repeated errors.');
      if (!_pausedByError) {
        _scheduleNextPoll(_pollInterval);
      }
    } finally {
      _pollInFlight = false;
    }
  }

  void _handleOffline() {
    _offline = true;
    _pollTimer?.cancel();
    _startOfflineProbe();
  }

  void _startOfflineProbe() {
    _offlineProbeTimer?.cancel();
    if (!_running || !_appVisible || _authInvalid || _pausedByError) return;

    _offlineProbeTimer = Timer.periodic(_offlineProbeInterval, (_) async {
      if (!_running || !_appVisible || _authInvalid || _pausedByError) return;
      try {
        await _http.resolveWorkspaceId();
        _offline = false;
        _offlineProbeFailures = 0;
        _clearPollingError();
        _offlineProbeTimer?.cancel();
        _scheduleNextPoll(_initialDelay);
      } catch (_) {
        _offlineProbeFailures += 1;
        if (_offlineProbeFailures >= _maxConsecutiveErrors) {
          _pausePolling('Workspace updates paused while offline.');
        }
        // Stay paused while offline.
      }
    });
  }

  Future<void> _handleAuthInvalid() async {
    _authInvalid = true;
    _pollTimer?.cancel();
    _offlineProbeTimer?.cancel();
    _clearPollingError();

    final notifier = _ref.read(dataSourceStateNotifierProvider.notifier);
    final current = _ref.read(currentDataSourceStateProvider);
    final config = current?.config ?? await DataSourcePreferencesService.loadConfig();
    await notifier.setConfig(DataSourceConfig(baseUrl: config.baseUrl, apiKey: null, refreshToken: config.refreshToken, apiStyle: config.apiStyle));
    await notifier.setMode(DataSourceMode.local);

    _ref.invalidate(collectionsNotifierProvider);
    _ref.invalidate(requestsNotifierProvider);
    _ref.invalidate(environmentsNotifierProvider);
    _ref.invalidate(activeEnvironmentNotifierProvider);
  }

  void _recordFailure(String message) {
    if (_pausedByError) return;
    _consecutiveErrors += 1;
    if (_consecutiveErrors < _maxConsecutiveErrors) return;
    _pausePolling(message);
  }

  void _pausePolling(String message) {
    if (_pausedByError) return;
    _pausedByError = true;
    _pollTimer?.cancel();
    _offlineProbeTimer?.cancel();
    _ref.read(workspaceUpdatesPollingErrorProvider.notifier).setError(message);
  }

  void _clearPollingError() {
    _consecutiveErrors = 0;
    _ref.read(workspaceUpdatesPollingErrorProvider.notifier).setError(null);
  }

  void _resetErrorState() {
    _pausedByError = false;
    _consecutiveErrors = 0;
    _offlineProbeFailures = 0;
    _ref.read(workspaceUpdatesPollingErrorProvider.notifier).setError(null);
  }

  Future<void> _fullRefetch() async {
    final collections = await _api.listCollections();
    final environments = await _api.listEnvironments();
    final requests = <ApiRequestModel>[];
    for (final collection in collections) {
      final r = await _api.listRequests(collection.id);
      requests.addAll(r);
    }

    _ref.read(collectionsNotifierProvider.notifier).replaceFromRemote(collections);
    _ref.read(environmentsNotifierProvider.notifier).replaceFromRemote(environments);
    _ref.read(requestsNotifierProvider.notifier).replaceFromRemote(requests);

    final selectedCollectionId = _ref.read(selectedCollectionIdProvider);
    final preferred = resolvePreferredCollectionId(
      loadedCollections: collections,
      selectedCollectionId: selectedCollectionId,
      mode: DataSourceMode.api,
    );
    if (preferred != selectedCollectionId) {
      _ref.read(selectedCollectionIdProvider.notifier).select(preferred);
    }
  }

  _ApplyResult _applyEvent(Map<String, dynamic> event) {
    final eventId = _readString(event, const ['id', '_id', 'eventId', 'event_id']);
    if (eventId != null && _isSeenEvent(eventId)) {
      return _ApplyResult.skipped;
    }

    final eventType = _readString(event, const ['type', 'eventType', 'event_type'])?.toLowerCase();
    final entity = _normalizeEntity(_readString(event, const ['entity', 'resource', 'model']) ?? eventType);
    final action = _normalizeAction(_readString(event, const ['action', 'operation', 'op']) ?? eventType);
    final payload = _extractPayload(event);

    final result = switch (entity) {
      _EventEntity.collection => _applyCollectionEvent(action, payload, event),
      _EventEntity.request => _applyRequestEvent(action, payload, event),
      _EventEntity.environment => _applyEnvironmentEvent(action, payload, event),
      _EventEntity.unknown => _ApplyResult.requiresFullRefetch,
    };

    if (eventId != null && result != _ApplyResult.requiresFullRefetch) {
      _rememberEvent(eventId);
    }
    return result;
  }

  _ApplyResult _applyCollectionEvent(_EventAction action, Map<String, dynamic>? payload, Map<String, dynamic> event) {
    final id = _readString(payload, const ['id', '_id']) ?? _readString(event, const ['collectionId', 'collection_id', 'id', '_id']);
    if (id == null || id.isEmpty) {
      return _ApplyResult.requiresFullRefetch;
    }

    if (action == _EventAction.delete) {
      _ref.read(collectionsNotifierProvider.notifier).applyRemoteDelete(id);
      return _ApplyResult.applied;
    }

    final existingCollections = _ref.read(collectionsNotifierProvider).asData?.value;
    CollectionModel? existing;
    if (existingCollections != null) {
      for (final collection in existingCollections) {
        if (collection.id == id) {
          existing = collection;
          break;
        }
      }
    }
    final name = _readString(payload, const ['name']) ?? existing?.name;
    if (name == null || name.isEmpty) {
      return _ApplyResult.requiresFullRefetch;
    }

    final now = DateTime.now();
    final collection = CollectionModel(
      id: id,
      name: name,
      description: _readString(payload, const ['description']) ?? existing?.description ?? '',
      createdAt: _readDate(payload, const ['createdAt', 'created_at']) ?? existing?.createdAt ?? now,
      updatedAt: _readDate(payload, const ['updatedAt', 'updated_at']) ?? now,
    );
    _ref.read(collectionsNotifierProvider.notifier).applyRemoteUpsert(collection);
    return _ApplyResult.applied;
  }

  _ApplyResult _applyRequestEvent(_EventAction action, Map<String, dynamic>? payload, Map<String, dynamic> event) {
    final id =
        _readString(payload, const ['id', '_id', 'endpointId']) ??
        _readString(event, const ['requestId', 'request_id', 'endpointId', 'endpoint_id', 'id', '_id']);
    if (id == null || id.isEmpty) {
      return _ApplyResult.requiresFullRefetch;
    }

    if (action == _EventAction.delete) {
      _ref.read(requestsNotifierProvider.notifier).applyRemoteDelete(id);
      return _ApplyResult.applied;
    }

    final existingRequests = _ref.read(requestsNotifierProvider).asData?.value;
    ApiRequestModel? existing;
    if (existingRequests != null) {
      for (final request in existingRequests) {
        if (request.id == id) {
          existing = request;
          break;
        }
      }
    }

    final collectionId =
        _readString(payload, const ['collectionId', 'collection_id', 'folderId']) ??
        _readString(event, const ['collectionId', 'collection_id']) ??
        existing?.collectionId;
    final name = _readString(payload, const ['name']) ?? existing?.name;
    final url = _readString(payload, const ['url', 'urlTemplate']) ?? existing?.urlTemplate;
    if (collectionId == null || collectionId.isEmpty || name == null || name.isEmpty || url == null || url.isEmpty) {
      return _ApplyResult.requiresFullRefetch;
    }

    final now = DateTime.now();
    final request = ApiRequestModel(
      id: id,
      name: name,
      method: HttpMethodX.fromString(_readString(payload, const ['method']) ?? existing?.method.name ?? 'GET'),
      urlTemplate: url,
      headers: _readKeyValueMap(payload?['headers']) ?? existing?.headers ?? const {},
      queryParams: _readKeyValueMap(payload?['queryParams']) ?? existing?.queryParams ?? const {},
      body: _readBody(payload) ?? existing?.body,
      bodyType: _readBodyType(payload) ?? existing?.bodyType ?? BodyType.raw,
      formDataFields: _readFormData(payload) ?? existing?.formDataFields ?? const {},
      authType: _readAuthType(payload) ?? existing?.authType ?? AuthType.none,
      authConfig: _readAuthConfig(payload) ?? existing?.authConfig ?? const {},
      description: _readString(payload, const ['description']) ?? existing?.description,
      filePath: existing?.filePath,
      collectionId: collectionId,
      environmentName: _readString(payload, const ['environmentName', 'environment']) ?? existing?.environmentName,
      createdAt: _readDate(payload, const ['createdAt', 'created_at']) ?? existing?.createdAt ?? now,
      updatedAt: _readDate(payload, const ['updatedAt', 'updated_at']) ?? now,
    );
    _ref.read(requestsNotifierProvider.notifier).applyRemoteUpsert(request);
    return _ApplyResult.applied;
  }

  _ApplyResult _applyEnvironmentEvent(_EventAction action, Map<String, dynamic>? payload, Map<String, dynamic> event) {
    final name = _readString(payload, const ['name']) ?? _readString(event, const ['name', 'environment', 'environmentName']);
    if (name == null || name.isEmpty) {
      return _ApplyResult.requiresFullRefetch;
    }

    if (action == _EventAction.delete) {
      _ref.read(environmentsNotifierProvider.notifier).applyRemoteDelete(name);
      final activeName = _ref.read(activeEnvironmentNameProvider);
      if (activeName == name) {
        _ref.read(activeEnvironmentNameProvider.notifier).setActiveName(null);
        unawaited(_ref.read(activeEnvironmentNotifierProvider.notifier).setActiveEnvironment(null));
      }
      return _ApplyResult.applied;
    }

    final existingEnvironments = _ref.read(environmentsNotifierProvider).asData?.value;
    EnvironmentModel? existing;
    if (existingEnvironments != null) {
      for (final environment in existingEnvironments) {
        if (environment.name == name) {
          existing = environment;
          break;
        }
      }
    }
    final variables = _readEnvironmentVariables(payload) ?? existing?.variables;
    if (variables == null) {
      return _ApplyResult.requiresFullRefetch;
    }

    _ref.read(environmentsNotifierProvider.notifier).applyRemoteUpsert(EnvironmentModel(name: name, variables: variables));
    return _ApplyResult.applied;
  }

  bool _isSeenEvent(String id) => _seenEventIds.contains(id);

  void _rememberEvent(String id) {
    if (_seenEventIds.add(id)) {
      _seenEventIdsOrder.addLast(id);
      while (_seenEventIdsOrder.length > _maxSeenEventIds) {
        final removed = _seenEventIdsOrder.removeFirst();
        _seenEventIds.remove(removed);
      }
    }
  }
}

_UpdatesBatch _parseUpdatesResponse(dynamic payload, {required int fallbackSince}) {
  if (payload is! Map<String, dynamic>) {
    return _UpdatesBatch(events: const [], nextCursor: fallbackSince);
  }

  final eventsRaw = payload['events'] ?? payload['items'] ?? payload['changes'];
  final events = eventsRaw is List ? eventsRaw.whereType<Map<String, dynamic>>().toList() : const <Map<String, dynamic>>[];

  final cursorObj = payload['cursor'];
  var nextCursor = fallbackSince;
  if (cursorObj is Map<String, dynamic>) {
    nextCursor = _readInt(cursorObj, const ['next', 'value']) ?? nextCursor;
  }
  nextCursor = _readInt(payload, const ['next', 'since']) ?? nextCursor;
  return _UpdatesBatch(events: events, nextCursor: nextCursor);
}

Map<String, dynamic>? _extractPayload(Map<String, dynamic> event) {
  final payload = event['payload'] ?? event['data'] ?? event['entity'] ?? event['item'] ?? event['after'];
  return payload is Map<String, dynamic> ? payload : null;
}

_EventEntity _normalizeEntity(String? raw) {
  final value = (raw ?? '').toLowerCase();
  if (value.contains('collection')) return _EventEntity.collection;
  if (value.contains('request') || value.contains('endpoint')) return _EventEntity.request;
  if (value.contains('environment')) return _EventEntity.environment;
  return _EventEntity.unknown;
}

_EventAction _normalizeAction(String? raw) {
  final value = (raw ?? '').toLowerCase();
  if (value.contains('delete') || value.contains('remove')) return _EventAction.delete;
  if (value.contains('create') || value.contains('insert') || value.contains('add')) return _EventAction.upsert;
  if (value.contains('update') || value.contains('patch') || value.contains('put') || value.contains('upsert')) return _EventAction.upsert;
  return _EventAction.unknown;
}

String? _readString(Map<String, dynamic>? json, List<String> keys) {
  if (json == null) return null;
  for (final key in keys) {
    final value = json[key];
    if (value == null) continue;
    final str = value.toString().trim();
    if (str.isNotEmpty) return str;
  }
  return null;
}

DateTime? _readDate(Map<String, dynamic>? json, List<String> keys) {
  final value = _readString(json, keys);
  if (value == null) return null;
  return DateTime.tryParse(value);
}

int? _readInt(Map<String, dynamic>? json, List<String> keys) {
  final value = _readString(json, keys);
  if (value == null) return null;
  return int.tryParse(value);
}

Map<String, String>? _readKeyValueMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value.map((k, v) => MapEntry(k, v?.toString() ?? ''));
  }
  if (value is! List) return null;
  final map = <String, String>{};
  for (final item in value.whereType<Map<String, dynamic>>()) {
    final key = _readString(item, const ['key']);
    if (key == null || key.isEmpty) continue;
    map[key] = _readString(item, const ['value']) ?? '';
  }
  return map;
}

String? _readBody(Map<String, dynamic>? payload) {
  if (payload == null) return null;
  final body = payload['body'];
  if (body is String) return body;
  if (body is Map<String, dynamic>) {
    final mode = _readString(body, const ['mode'])?.toLowerCase();
    if (mode == 'raw') return _readString(body, const ['raw']);
    if (mode == 'binary') {
      final file = body['file'];
      if (file is Map<String, dynamic>) {
        return _readString(file, const ['contentBase64']);
      }
    }
  }
  return null;
}

BodyType? _readBodyType(Map<String, dynamic>? payload) {
  final body = payload?['body'];
  if (body is! Map<String, dynamic>) return null;
  final mode = _readString(body, const ['mode'])?.toLowerCase();
  return switch (mode) {
    'none' => BodyType.none,
    'urlencoded' => BodyType.urlEncoded,
    'formdata' => BodyType.formData,
    'binary' => BodyType.binary,
    'raw' => BodyType.raw,
    _ => null,
  };
}

Map<String, String>? _readFormData(Map<String, dynamic>? payload) {
  final body = payload?['body'];
  if (body is! Map<String, dynamic>) return null;
  final mode = _readString(body, const ['mode'])?.toLowerCase();
  final key = switch (mode) {
    'formdata' => 'formdata',
    'urlencoded' => 'urlencoded',
    _ => null,
  };
  if (key == null) return null;
  return _readKeyValueMap(body[key]);
}

AuthType? _readAuthType(Map<String, dynamic>? payload) {
  final auth = payload?['auth'];
  if (auth is! Map<String, dynamic>) return null;
  final type = _readString(auth, const ['type'])?.toLowerCase();
  return switch (type) {
    'none' => AuthType.none,
    'bearer' => AuthType.bearer,
    'basic' => AuthType.basic,
    'apikey' || 'api_key' => AuthType.apiKey,
    _ => null,
  };
}

Map<String, String>? _readAuthConfig(Map<String, dynamic>? payload) {
  final auth = payload?['auth'];
  if (auth is! Map<String, dynamic>) return null;
  final type = _readAuthType(payload);
  return switch (type) {
    AuthType.none => const {},
    AuthType.bearer => {
      AuthConfigKeys.token: _readString(auth, const ['token']) ?? '',
    },
    AuthType.basic => {
      AuthConfigKeys.username: _readString(auth, const ['username']) ?? '',
      AuthConfigKeys.password: _readString(auth, const ['password']) ?? '',
    },
    AuthType.apiKey => {
      AuthConfigKeys.key: _readString(auth, const ['key']) ?? '',
      AuthConfigKeys.value: _readString(auth, const ['value']) ?? '',
    },
    null => null,
  };
}

Map<String, String>? _readEnvironmentVariables(Map<String, dynamic>? payload) {
  if (payload == null) return null;
  final vars = payload['variables'] ?? payload['vars'];
  return _readKeyValueMap(vars);
}

class _UpdatesBatch {
  const _UpdatesBatch({required this.events, required this.nextCursor});

  final List<Map<String, dynamic>> events;
  final int nextCursor;
}

enum _EventEntity { collection, request, environment, unknown }

enum _EventAction { upsert, delete, unknown }

enum _ApplyResult { applied, skipped, requiresFullRefetch }
