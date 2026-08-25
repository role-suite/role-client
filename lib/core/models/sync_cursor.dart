/// Where cursor polling for one remote workspace left off (§5 of
/// docs/08-ONLINE-MODE-INTEGRATION.md), persisted so a restart resumes
/// instead of replaying the whole event history.
class SyncCursor {
  const SyncCursor({required this.workspaceId, this.since = 0});

  final int workspaceId;
  final int since;

  SyncCursor copyWith({int? since}) => SyncCursor(workspaceId: workspaceId, since: since ?? this.since);

  Map<String, dynamic> toJson() => {'workspaceId': workspaceId, 'since': since};

  factory SyncCursor.fromJson(Map<String, dynamic> json) {
    return SyncCursor(workspaceId: json['workspaceId'] as int, since: json['since'] as int? ?? 0);
  }
}
