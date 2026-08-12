import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/run_history.dart';
import '../core/storage/json_store.dart';
import '../core/storage/workspace_paths.dart';
import '../core/utils/id.dart';

class RunHistoryNotifier extends AsyncNotifier<List<RunHistoryEntry>> {
  @override
  Future<List<RunHistoryEntry>> build() async {
    final raw = await JsonStore.instance.readAll(WorkspacePaths.runs);
    final entries = raw.map(RunHistoryEntry.fromJson).toList()..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    return entries;
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
    state = AsyncData([entry, ...state.value ?? const []]);
    return entry;
  }

  Future<void> delete(String id) async {
    await JsonStore.instance.delete(WorkspacePaths.runFile(id));
    state = AsyncData((state.value ?? const []).where((e) => e.id != id).toList());
  }
}

final runHistoryProvider = AsyncNotifierProvider<RunHistoryNotifier, List<RunHistoryEntry>>(RunHistoryNotifier.new);
