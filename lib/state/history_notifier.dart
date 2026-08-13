import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../core/models/response_snapshot.dart';
import '../core/storage/json_store.dart';
import '../core/storage/workspace_paths.dart';

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
    return snapshots;
  }

  Future<void> record(ResponseSnapshot snapshot) async {
    final current = state.value ?? const [];
    final forRequest = [snapshot, ...current.where((s) => s.requestId == snapshot.requestId)];
    final capped = forRequest.take(AppConstants.maxHistoryEntriesPerRequest).toList();

    await JsonStore.instance.write(WorkspacePaths.historyFile(snapshot.requestId), {
      'requestId': snapshot.requestId,
      'snapshots': capped.map((s) => s.toJson()).toList(),
    });

    state = AsyncData([snapshot, ...current]);
  }

  Future<void> clearForRequest(String requestId) async {
    await JsonStore.instance.delete(WorkspacePaths.historyFile(requestId));
    state = AsyncData((state.value ?? const []).where((s) => s.requestId != requestId).toList());
  }

  List<ResponseSnapshot> forRequest(String requestId) {
    return (state.value ?? const []).where((s) => s.requestId == requestId).toList();
  }
}

final historyProvider = AsyncNotifierProvider<HistoryNotifier, List<ResponseSnapshot>>(HistoryNotifier.new);
