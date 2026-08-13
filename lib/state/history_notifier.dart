import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../core/models/response_snapshot.dart';
import '../core/storage/json_store.dart';
import '../core/storage/workspace_paths.dart';

/// Snapshot list held in memory and on disk holds metadata only — response
/// bodies live in one file per snapshot under `history/bodies/` and are
/// fetched on demand via [hydrate]. Two caps keep both bounded: at most
/// [AppConstants.maxHistoryEntriesPerRequest] per request, and at most
/// [AppConstants.maxHistoryEntriesGlobal] across all requests combined —
/// oldest entries are evicted (metadata + body file deleted) as new ones
/// come in, so history never grows without bound.
class HistoryNotifier extends AsyncNotifier<List<ResponseSnapshot>> {
  @override
  Future<List<ResponseSnapshot>> build() async {
    final raw = await JsonStore.instance.readAll(WorkspacePaths.history);
    final snapshots =
        raw
            .expand((file) => (file['snapshots'] as List? ?? const []).whereType<Map>())
            .map((e) => ResponseSnapshot.fromJson(Map<String, dynamic>.from(e)))
            .toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return _normalize(snapshots);
  }

  /// One-time cleanup for data written before the body/metadata split:
  /// moves any snapshot still carrying its body inline out to its own body
  /// file and strips it from the metadata file, and applies the global cap
  /// to anything that predates it. No-op once an install has converged.
  Future<List<ResponseSnapshot>> _normalize(List<ResponseSnapshot> snapshots) async {
    final legacyInline = snapshots.where((s) => s.result.body != null).toList();
    final overflow = snapshots.length > AppConstants.maxHistoryEntriesGlobal
        ? snapshots.sublist(AppConstants.maxHistoryEntriesGlobal)
        : const <ResponseSnapshot>[];
    if (legacyInline.isEmpty && overflow.isEmpty) return snapshots;

    final overflowIds = overflow.map((s) => s.id).toSet();
    final kept = overflow.isEmpty ? snapshots : snapshots.sublist(0, AppConstants.maxHistoryEntriesGlobal);

    for (final s in legacyInline) {
      if (overflowIds.contains(s.id)) continue;
      await JsonStore.instance.write(WorkspacePaths.historyBodyFile(s.id), {'body': s.result.body});
    }
    for (final s in overflow) {
      await JsonStore.instance.delete(WorkspacePaths.historyBodyFile(s.id));
    }

    final touchedRequestIds = {...legacyInline.map((s) => s.requestId), ...overflow.map((s) => s.requestId)};
    for (final requestId in touchedRequestIds) {
      final forRequest = kept.where((s) => s.requestId == requestId).toList();
      if (forRequest.isEmpty) {
        await JsonStore.instance.delete(WorkspacePaths.historyFile(requestId));
      } else {
        await JsonStore.instance.write(WorkspacePaths.historyFile(requestId), {
          'requestId': requestId,
          'snapshots': forRequest.map((s) => s.toMetadataJson()).toList(),
        });
      }
    }

    return kept;
  }

  Future<void> record(ResponseSnapshot snapshot) async {
    final current = state.value ?? const [];
    var next = [snapshot, ...current];
    final touchedRequestIds = <String>{snapshot.requestId};
    final evicted = <ResponseSnapshot>[];

    final sameRequest = next.where((s) => s.requestId == snapshot.requestId).toList();
    if (sameRequest.length > AppConstants.maxHistoryEntriesPerRequest) {
      final overflow = sameRequest.sublist(AppConstants.maxHistoryEntriesPerRequest);
      evicted.addAll(overflow);
      final overflowIds = overflow.map((s) => s.id).toSet();
      next = next.where((s) => !overflowIds.contains(s.id)).toList();
    }

    if (next.length > AppConstants.maxHistoryEntriesGlobal) {
      final overflow = next.sublist(AppConstants.maxHistoryEntriesGlobal);
      evicted.addAll(overflow);
      touchedRequestIds.addAll(overflow.map((s) => s.requestId));
      next = next.sublist(0, AppConstants.maxHistoryEntriesGlobal);
    }

    for (final requestId in touchedRequestIds) {
      final forRequest = next.where((s) => s.requestId == requestId).toList();
      if (forRequest.isEmpty) {
        await JsonStore.instance.delete(WorkspacePaths.historyFile(requestId));
      } else {
        await JsonStore.instance.write(WorkspacePaths.historyFile(requestId), {
          'requestId': requestId,
          'snapshots': forRequest.map((s) => s.toMetadataJson()).toList(),
        });
      }
    }

    if (snapshot.result.body != null) {
      await JsonStore.instance.write(WorkspacePaths.historyBodyFile(snapshot.id), {'body': snapshot.result.body});
    }
    for (final e in evicted) {
      await JsonStore.instance.delete(WorkspacePaths.historyBodyFile(e.id));
    }

    state = AsyncData(next);
  }

  /// Reads the full response body for [snapshot] from its body file and
  /// returns a copy with it attached. Snapshots in [state] never carry a
  /// body, so callers that need one (the history detail dialog) hydrate on
  /// open rather than paying for every body on every history load.
  Future<ResponseSnapshot> hydrate(ResponseSnapshot snapshot) async {
    final bodyJson = await JsonStore.instance.read(WorkspacePaths.historyBodyFile(snapshot.id));
    if (bodyJson == null) return snapshot;
    return snapshot.withResult(snapshot.result.withBody(bodyJson['body']));
  }

  Future<void> clearForRequest(String requestId) async {
    final removed = (state.value ?? const []).where((s) => s.requestId == requestId).toList();
    await JsonStore.instance.delete(WorkspacePaths.historyFile(requestId));
    for (final s in removed) {
      await JsonStore.instance.delete(WorkspacePaths.historyBodyFile(s.id));
    }
    state = AsyncData((state.value ?? const []).where((s) => s.requestId != requestId).toList());
  }

  List<ResponseSnapshot> forRequest(String requestId) {
    return (state.value ?? const []).where((s) => s.requestId == requestId).toList();
  }
}

final historyProvider = AsyncNotifierProvider<HistoryNotifier, List<ResponseSnapshot>>(HistoryNotifier.new);
