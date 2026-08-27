import 'package:flutter_test/flutter_test.dart';
import 'package:relay/state/sync_notifier.dart';
import 'package:relay/ui/shell/online_mode_panel.dart';

void main() {
  test('syncLastSyncedAt reports synced and offline timestamps only', () {
    final at = DateTime(2026, 8, 25, 12);

    expect(syncLastSyncedAt(SyncSynced(at)), at);
    expect(syncLastSyncedAt(SyncOffline(at)), at);
    expect(syncLastSyncedAt(const SyncOffline(null)), isNull);
    expect(syncLastSyncedAt(const SyncIdle()), isNull);
    expect(syncLastSyncedAt(const SyncSyncing()), isNull);
    expect(syncLastSyncedAt(const SyncError('No access')), isNull);
  });
}
