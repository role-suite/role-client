import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/models/remote_workspace.dart';

void main() {
  group('RemoteWorkspace.fromJson', () {
    test('parses the active-workspace shape (id key)', () {
      final workspace = RemoteWorkspace.fromJson({
        'id': 1,
        'name': "Altay's Workspace",
        'slug': 'altays-workspace',
        'type': 'single',
        'role': 'owner',
      });
      expect(workspace.id, 1);
      expect(workspace.role, 'owner');
    });

    test('parses a membership row shape (workspaceId key instead of id)', () {
      final workspace = RemoteWorkspace.fromJson({'workspaceId': 2, 'name': 'Core Team', 'slug': 'core-team', 'type': 'team', 'role': 'member'});
      expect(workspace.id, 2);
      expect(workspace.type, 'team');
    });
  });
}
