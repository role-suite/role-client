import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/models/workspace_member.dart';

void main() {
  test('WorkspaceMember.fromJson maps role-node\'s {userId,name,email,role} shape', () {
    final member = WorkspaceMember.fromJson({'userId': 2, 'name': 'Altay', 'email': 'altay@example.com', 'role': 'admin'});

    expect(member.userId, 2);
    expect(member.name, 'Altay');
    expect(member.email, 'altay@example.com');
    expect(member.role, 'admin');
  });
}
