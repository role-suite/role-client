import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../core/models/run_history.dart';
import '../core/storage/json_store.dart';
import '../core/storage/workspace_paths.dart';
import '../core/utils/id.dart';

/// Run entries carry no response bodies (just status/duration per item), so
/// unlike request history there's nothing to split out — the only thing
/// that can grow without bound here is the entry count itself, capped at
/// [AppConstants.maxRunHistoryEntries] with oldest evicted first.
class RunHistoryNotifier extends AsyncNotifier<List<RunHistoryEntry>> {
  @override
  Future<List<RunHistoryEntry>> build() async {
    final raw = await JsonStore.instance.readAll(WorkspacePaths.runs);
    final entries = raw.map(RunHistoryEntry.fromJson).toList()..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    return _capped(entries);
  }

  Future<List<RunHistoryEntry>> _capped(List<RunHistoryEntry> entries) async {
    if (entries.length <= AppConstants.maxRunHistoryEntries) return entries;
    final overflow = entries.sublist(AppConstants.maxRunHistoryEntries);
    for (final e in overflow) {
      await JsonStore.instance.delete(WorkspacePaths.runFile(e.id));
    }
    return entries.sublist(0, AppConstants.maxRunHistoryEntries);
  }

  Future<RunHistoryEntry> record({
    required String collectionId,
    required String collectionName,
    String? environmentName,
    required DateTime startedAt,
    required List<RunItemResult> results,
  }) async {
    final entry = RunHistoryEntry(
      id: generateId('run'),
      collectionId: collectionId,
      collectionName: collectionName,
      environmentName: environmentName,
      startedAt: startedAt,
      completedAt: DateTime.now(),
      results: results,
    );
    await JsonStore.instance.write(WorkspacePaths.runFile(entry.id), entry.toJson());
    final next = await _capped([entry, ...state.value ?? const []]);
    state = AsyncData(next);
    return entry;
  }

  Future<void> delete(String id) async {
    await JsonStore.instance.delete(WorkspacePaths.runFile(id));
    state = AsyncData((state.value ?? const []).where((e) => e.id != id).toList());
  }

  Future<void> clearForCollection(String collectionId) async {
    final removed = (state.value ?? const []).where((e) => e.collectionId == collectionId).toList();
    for (final e in removed) {
      await JsonStore.instance.delete(WorkspacePaths.runFile(e.id));
    }
    state = AsyncData((state.value ?? const []).where((e) => e.collectionId != collectionId).toList());
  }
}

final runHistoryProvider = AsyncNotifierProvider<RunHistoryNotifier, List<RunHistoryEntry>>(RunHistoryNotifier.new);
