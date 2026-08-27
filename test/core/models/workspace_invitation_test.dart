import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/models/workspace_invitation.dart';

void main() {
  test('WorkspaceInvitation.fromJson maps role-node\'s invitation response shape', () {
    final invitation = WorkspaceInvitation.fromJson({
      'id': 5,
      'workspaceId': 1,
      'email': 'invitee@example.com',
      'role': 'member',
      'token': 'raw-secret-token',
      'expiresAt': '2026-08-01T10:00:00.000Z',
    });

    expect(invitation.id, 5);
    expect(invitation.workspaceId, 1);
    expect(invitation.email, 'invitee@example.com');
    expect(invitation.role, 'member');
    expect(invitation.token, 'raw-secret-token');
    expect(invitation.expiresAt, DateTime.parse('2026-08-01T10:00:00.000Z'));
  });
}
