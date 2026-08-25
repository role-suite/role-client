import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/remote_workspace.dart';
import '../../models/workspace_invitation.dart';
import '../../models/workspace_member.dart';
import '../api_client.dart';

/// Team-management actions against role-node's `/workspaces` routes (§10 of
/// docs/08-ONLINE-MODE-INTEGRATION.md) — create/list/switch a workspace,
/// members + roles, invitations. Unlike `WorkspaceSyncService`/
/// `WorkspacePushService`, nothing here is cached or queued: every call is a
/// direct, synchronous, one-shot REST action with no local-first concept,
/// mirroring how `AuthNotifier.listSessions()` already works.
///
/// Deliberately excludes `POST /workspaces/:id/members` (adding an existing
/// user directly by email) — §10 only calls out the invitation path
/// (`createInvitation` + `join`), and a second parallel add-member UX isn't
/// worth the complexity here.
class WorkspaceService {
  const WorkspaceService(this._client);

  final RemoteApiClient _client;

  Future<RemoteWorkspace> createWorkspace(String name) async {
    final data = Map<String, dynamic>.from(await _client.post('/workspaces', data: {'name': name}) as Map);
    return RemoteWorkspace.fromJson(data);
  }

  Future<List<WorkspaceMember>> listMembers(int workspaceId) async {
    final data = Map<String, dynamic>.from(await _client.get('/workspaces/$workspaceId/members') as Map);
    return (data['items'] as List? ?? const []).whereType<Map>().map((e) => WorkspaceMember.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<WorkspaceInvitation> createInvitation(int workspaceId, {required String email, String role = 'member'}) async {
    final data = Map<String, dynamic>.from(await _client.post('/workspaces/$workspaceId/invitations', data: {'email': email, 'role': role}) as Map);
    return WorkspaceInvitation.fromJson(data);
  }

  /// Only creates the membership row — role-node's response carries no new
  /// tokens. Callers must follow up with `AuthNotifier.switchWorkspace` to
  /// actually start using the joined workspace.
  Future<RemoteWorkspace> join(String token) async {
    final data = Map<String, dynamic>.from(await _client.post('/workspaces/join', data: {'token': token}) as Map);
    return RemoteWorkspace.fromJson(data);
  }

  Future<WorkspaceMember> updateMemberRole(int workspaceId, int memberUserId, String role) async {
    final data = Map<String, dynamic>.from(await _client.patch('/workspaces/$workspaceId/members/$memberUserId', data: {'role': role}) as Map);
    return WorkspaceMember.fromJson(data);
  }

  Future<void> removeMember(int workspaceId, int memberUserId) {
    return _client.delete('/workspaces/$workspaceId/members/$memberUserId');
  }

  Future<void> leave(int workspaceId) {
    return _client.post('/workspaces/$workspaceId/leave');
  }

  Future<RemoteWorkspace> convertToTeam(int workspaceId, {String? name}) async {
    final data = Map<String, dynamic>.from(await _client.post('/workspaces/$workspaceId/convert-to-team', data: {'name': ?name}) as Map);
    return RemoteWorkspace.fromJson(data);
  }
}

/// Null until a base URL is configured, same shape as [remoteApiClientProvider].
final workspaceServiceProvider = Provider<WorkspaceService?>((ref) {
  final client = ref.watch(remoteApiClientProvider);
  return client == null ? null : WorkspaceService(client);
});
