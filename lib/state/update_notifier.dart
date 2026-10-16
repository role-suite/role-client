import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/constants.dart';
import '../core/updates/release_checker.dart';
import '../core/updates/version_compare.dart';
import 'settings_providers.dart';

const _autoCheckKey = 'updates.autoCheck';
const _lastCheckedKey = 'updates.lastCheckedAt';
const _availableTagKey = 'updates.availableTag';
const _availableUrlKey = 'updates.availableUrl';
const _dismissedTagKey = 'updates.dismissedTag';

const Object _unset = Object();

/// The release check is the only traffic Röle sends outside the user's own
/// endpoints and role-node, so it is manual by default; this interval only
/// governs the opt-in automatic mode. Overridable in tests.
final updateCheckIntervalProvider = Provider<Duration>((ref) => AppConstants.updateCheckInterval);

final releaseCheckerProvider = Provider<ReleaseChecker>((ref) => ReleaseChecker());

class UpdateState {
  const UpdateState({
    this.currentVersion = '',
    this.currentBuild = '',
    this.autoCheckEnabled = false,
    this.isChecking = false,
    this.latest,
    this.availableTag,
    this.availableUrl,
    this.dismissedTag,
    this.lastCheckedAt,
    this.errorMessage,
  });

  final String currentVersion;
  final String currentBuild;
  final bool autoCheckEnabled;
  final bool isChecking;

  /// Full details of the most recent release fetched this session.
  final ReleaseInfo? latest;

  /// Newer release known from this or a previous session (`vX.Y.Z`).
  final String? availableTag;
  final String? availableUrl;

  /// Tag the user dismissed; a later, different release shows the badge again.
  final String? dismissedTag;
  final DateTime? lastCheckedAt;
  final String? errorMessage;

  bool get versionKnown => currentVersion.isNotEmpty;

  bool get updateAvailable {
    final tag = availableTag;
    return versionKnown && tag != null && isReleaseNewer(currentVersion: currentVersion, releaseTag: tag);
  }

  /// Whether the status-bar update badge should be visible.
  bool get showBadge => updateAvailable && dismissedTag != availableTag;

  String get displayVersion {
    if (!versionKnown) return 'unknown';
    return currentBuild.isEmpty ? currentVersion : '$currentVersion+$currentBuild';
  }

  UpdateState copyWith({
    bool? autoCheckEnabled,
    bool? isChecking,
    Object? latest = _unset,
    Object? availableTag = _unset,
    Object? availableUrl = _unset,
    Object? dismissedTag = _unset,
    Object? lastCheckedAt = _unset,
    Object? errorMessage = _unset,
  }) {
    return UpdateState(
      currentVersion: currentVersion,
      currentBuild: currentBuild,
      autoCheckEnabled: autoCheckEnabled ?? this.autoCheckEnabled,
      isChecking: isChecking ?? this.isChecking,
      latest: identical(latest, _unset) ? this.latest : latest as ReleaseInfo?,
      availableTag: identical(availableTag, _unset) ? this.availableTag : availableTag as String?,
      availableUrl: identical(availableUrl, _unset) ? this.availableUrl : availableUrl as String?,
      dismissedTag: identical(dismissedTag, _unset) ? this.dismissedTag : dismissedTag as String?,
      lastCheckedAt: identical(lastCheckedAt, _unset) ? this.lastCheckedAt : lastCheckedAt as DateTime?,
      errorMessage: identical(errorMessage, _unset) ? this.errorMessage : errorMessage as String?,
    );
  }
}

final updateNotifierProvider = AsyncNotifierProvider<UpdateNotifier, UpdateState>(UpdateNotifier.new);

/// Owns the app's version/update state: reads the current version, tracks the
/// last known newer release (persisted so the badge survives restarts), and
/// runs manual or opt-in automatic GitHub release checks.
class UpdateNotifier extends AsyncNotifier<UpdateState> {
  @override
  Future<UpdateState> build() async {
    final prefs = ref.watch(sharedPreferencesProvider);

    var version = '';
    var build = '';
    try {
      final info = await PackageInfo.fromPlatform();
      version = info.version;
      build = info.buildNumber;
    } on Exception {
      // Platform version info is unavailable (e.g. in widget tests); the
      // About dialog falls back to "unknown" and checks stay disabled.
    }

    final state = UpdateState(
      currentVersion: version,
      currentBuild: build,
      autoCheckEnabled: prefs.getBool(_autoCheckKey) ?? false,
      availableTag: prefs.getString(_availableTagKey),
      availableUrl: prefs.getString(_availableUrlKey),
      dismissedTag: prefs.getString(_dismissedTagKey),
      lastCheckedAt: DateTime.tryParse(prefs.getString(_lastCheckedKey) ?? ''),
    );

    if (state.autoCheckEnabled && state.versionKnown && _isStale(state.lastCheckedAt)) {
      unawaited(Future.microtask(checkForUpdates));
    }
    return state;
  }

  bool _isStale(DateTime? lastCheckedAt) {
    if (lastCheckedAt == null) return true;
    return DateTime.now().difference(lastCheckedAt) >= ref.read(updateCheckIntervalProvider);
  }

  Future<void> checkForUpdates() async {
    final current = state.value;
    if (current == null || current.isChecking || !current.versionKnown) return;

    state = AsyncData(current.copyWith(isChecking: true, errorMessage: null));
    try {
      final release = await ref.read(releaseCheckerProvider).fetchLatest();
      final newer = isReleaseNewer(currentVersion: current.currentVersion, releaseTag: release.tagName);
      final next = current.copyWith(
        isChecking: false,
        latest: release,
        availableTag: newer ? release.tagName : null,
        availableUrl: newer ? release.htmlUrl : null,
        lastCheckedAt: DateTime.now(),
        errorMessage: null,
      );
      state = AsyncData(next);
      await _persist(next);
    } on ReleaseCheckException catch (error) {
      state = AsyncData(current.copyWith(isChecking: false, errorMessage: error.message));
    }
  }

  Future<void> setAutoCheck(bool enabled) async {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(autoCheckEnabled: enabled));
    await ref.read(sharedPreferencesProvider).setBool(_autoCheckKey, enabled);
    if (enabled && current.versionKnown) {
      await checkForUpdates();
    }
  }

  Future<void> dismissUpdate() async {
    final current = state.value;
    final tag = current?.availableTag;
    if (current == null || tag == null) return;
    state = AsyncData(current.copyWith(dismissedTag: tag));
    await ref.read(sharedPreferencesProvider).setString(_dismissedTagKey, tag);
  }

  Future<void> _persist(UpdateState state) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final lastCheckedAt = state.lastCheckedAt;
    if (lastCheckedAt != null) {
      await prefs.setString(_lastCheckedKey, lastCheckedAt.toIso8601String());
    }
    final tag = state.availableTag;
    final url = state.availableUrl;
    if (tag != null && url != null) {
      await prefs.setString(_availableTagKey, tag);
      await prefs.setString(_availableUrlKey, url);
    } else {
      await prefs.remove(_availableTagKey);
      await prefs.remove(_availableUrlKey);
    }
  }
}
