import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:relay/core/models/outbox_entry.dart';
import 'package:relay/core/remote/sync/outbox_store.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this._path);
  final String _path;

  @override
  Future<String?> getApplicationSupportPath() async => _path;
}

OutboxEntry _entry({required String localId, OutboxOperation operation = OutboxOperation.upsert}) =>
    OutboxEntry(kind: OutboxKind.collection, operation: operation, workspaceId: 1, localId: localId, enqueuedAt: DateTime(2026));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('role_outbox_store_test_');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  test('load returns empty when nothing was ever enqueued', () async {
    expect(await OutboxStore.load(201), isEmpty);
  });

  test('enqueue then load round-trips an entry', () async {
    await OutboxStore.enqueue(202, _entry(localId: 'col-a'));
    final entries = await OutboxStore.load(202);
    expect(entries, hasLength(1));
    expect(entries.single.localId, 'col-a');
  });

  test('enqueueing the same key twice coalesces into one entry', () async {
    await OutboxStore.enqueue(203, _entry(localId: 'col-a'));
    await OutboxStore.enqueue(203, _entry(localId: 'col-a', operation: OutboxOperation.delete));

    final entries = await OutboxStore.load(203);
    expect(entries, hasLength(1));
    expect(entries.single.operation, OutboxOperation.delete);
  });

  test('remove deletes only the matching entry', () async {
    await OutboxStore.enqueue(204, _entry(localId: 'col-a'));
    await OutboxStore.enqueue(204, _entry(localId: 'col-b'));

    await OutboxStore.remove(204, _entry(localId: 'col-a').key);

    final entries = await OutboxStore.load(204);
    expect(entries.map((e) => e.localId), ['col-b']);
  });

  test('concurrent enqueues for the same workspace never lose an update', () async {
    await Future.wait([for (var i = 0; i < 10; i++) OutboxStore.enqueue(205, _entry(localId: 'col-$i'))]);

    final entries = await OutboxStore.load(205);
    expect(entries.map((e) => e.localId).toSet(), {for (var i = 0; i < 10; i++) 'col-$i'});
  });

  test('a concurrent remove and enqueue never resurrect the removed entry', () async {
    await OutboxStore.enqueue(206, _entry(localId: 'col-a'));
    await OutboxStore.enqueue(206, _entry(localId: 'col-b'));

    // Without the per-workspace lock in OutboxStore, this interleaving is
    // exactly the race that could resurrect 'col-a': both read the
    // pre-removal list before either write lands.
    await Future.wait([OutboxStore.remove(206, _entry(localId: 'col-a').key), OutboxStore.enqueue(206, _entry(localId: 'col-c'))]);

    final entries = await OutboxStore.load(206);
    expect(entries.map((e) => e.localId).toSet(), {'col-b', 'col-c'});
  });
}
