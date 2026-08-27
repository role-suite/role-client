import 'dart:async';

import '../../models/outbox_entry.dart';
import '../../storage/json_store.dart';
import '../../storage/workspace_paths.dart';

/// File-backed pending-push queue for one workspace. Deliberately has no
/// Riverpod dependency — both `WorkspaceNotifier`/`EnvironmentsNotifier`
/// (enqueue, on a local edit) and `SyncNotifier` (flush, on its poll loop)
/// read/write the same file without referencing each other, avoiding the
/// notifier-to-notifier circular-dependency trap `AuthNotifier`/
/// `SyncNotifier` hit in Phase 3 (see docs/08-ONLINE-MODE-INTEGRATION.md).
abstract class OutboxStore {
  /// Per-workspace async mutex: `enqueue`/`remove` are each an unlocked
  /// read-modify-write against the same file, and the immediate-flush-on-edit
  /// path (`WorkspaceNotifier`/`EnvironmentsNotifier`) can interleave with
  /// `SyncNotifier`'s per-tick flush across an `await` (file I/O yields
  /// control even within one isolate) — without this, a completed push's
  /// entry could be resurrected by a concurrent `enqueue` that read the list
  /// before the `remove`'s write landed. Serializing every mutation per
  /// workspace closes that race.
  static final Map<int, Future<void>> _locks = {};

  static Future<T> _locked<T>(int workspaceId, Future<T> Function() action) async {
    final previous = _locks[workspaceId] ?? Future.value();
    final completer = Completer<void>();
    _locks[workspaceId] = previous.then((_) => completer.future);
    await previous;
    try {
      return await action();
    } finally {
      completer.complete();
    }
  }

  static Future<List<OutboxEntry>> load(int workspaceId) async {
    final json = await JsonStore.instance.read(WorkspacePaths.outboxFile(workspaceId));
    if (json == null) return const [];
    return (json['entries'] as List? ?? const []).whereType<Map>().map((e) => OutboxEntry.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  static Future<void> _save(int workspaceId, List<OutboxEntry> entries) {
    return JsonStore.instance.write(WorkspacePaths.outboxFile(workspaceId), {'entries': entries.map((e) => e.toJson()).toList()});
  }

  /// Coalesces by [OutboxEntry.key] — a second edit to the same entity
  /// before the first push lands replaces the queued entry instead of
  /// piling up duplicate work.
  static Future<void> enqueue(int workspaceId, OutboxEntry entry) {
    return _locked(workspaceId, () async {
      final entries = await load(workspaceId);
      await _save(workspaceId, [...entries.where((e) => e.key != entry.key), entry]);
    });
  }

  static Future<void> remove(int workspaceId, String entryKey) {
    return _locked(workspaceId, () async {
      final entries = await load(workspaceId);
      await _save(workspaceId, entries.where((e) => e.key != entryKey).toList());
    });
  }
}
