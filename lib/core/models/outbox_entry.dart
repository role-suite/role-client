enum OutboxKind { collection, request, environment }

enum OutboxOperation { upsert, delete }

/// One pending push to role-node for a local edit to an already-synced
/// remote-origin entity (§5 of docs/08-ONLINE-MODE-INTEGRATION.md). Only
/// ever created for entities that already carry a `remoteId` — creating a
/// brand-new entity inside a remote workspace is out of scope for this
/// phase (see the plan's scope note on id reconciliation).
///
/// [operation] `upsert` entries carry no payload snapshot — the flusher
/// re-reads the current local remote-cache file at flush time, so a queued
/// entry always sends the latest edit, never a stale one. `delete` entries
/// must carry [deletedRemoteId] (and [deletedParentRemoteId] for a request)
/// because by flush time the local row is already gone.
class OutboxEntry {
  const OutboxEntry({
    required this.kind,
    required this.operation,
    required this.workspaceId,
    required this.localId,
    this.collectionLocalId,
    this.deletedRemoteId,
    this.deletedParentRemoteId,
    required this.enqueuedAt,
  });

  final OutboxKind kind;
  final OutboxOperation operation;
  final int workspaceId;
  final String localId;

  /// Only set for `kind == request` — which collection's bundle file to find
  /// this request's current state in.
  final String? collectionLocalId;

  final int? deletedRemoteId;
  final int? deletedParentRemoteId;
  final DateTime enqueuedAt;

  /// Coalescing key: a second edit to the same entity before the first push
  /// lands replaces the queued entry rather than piling up.
  String get key => '${kind.name}:$localId';

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'operation': operation.name,
    'workspaceId': workspaceId,
    'localId': localId,
    if (collectionLocalId != null) 'collectionLocalId': collectionLocalId,
    if (deletedRemoteId != null) 'deletedRemoteId': deletedRemoteId,
    if (deletedParentRemoteId != null) 'deletedParentRemoteId': deletedParentRemoteId,
    'enqueuedAt': enqueuedAt.toIso8601String(),
  };

  factory OutboxEntry.fromJson(Map<String, dynamic> json) {
    return OutboxEntry(
      kind: OutboxKind.values.firstWhere((k) => k.name == json['kind'], orElse: () => OutboxKind.collection),
      operation: OutboxOperation.values.firstWhere((o) => o.name == json['operation'], orElse: () => OutboxOperation.upsert),
      workspaceId: json['workspaceId'] as int,
      localId: json['localId'] as String,
      collectionLocalId: json['collectionLocalId'] as String?,
      deletedRemoteId: json['deletedRemoteId'] as int?,
      deletedParentRemoteId: json['deletedParentRemoteId'] as int?,
      enqueuedAt: DateTime.tryParse(json['enqueuedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
