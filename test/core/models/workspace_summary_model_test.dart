import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/models/workspace_summary_model.dart';

void main() {
  group('WorkspaceSummaryModel.fromJson', () {
    test('removes standalone Portal word from workspace name', () {
      final model = WorkspaceSummaryModel.fromJson({
        'id': '1',
        'name': 'Tıpta Uzmanlık Karnesi Portal',
        'type': 'team',
      });

      expect(model.name, 'Tıpta Uzmanlık Karnesi');
    });

    test('falls back to Workspace when name becomes empty after sanitizing', () {
      final model = WorkspaceSummaryModel.fromJson({
        'id': '2',
        'name': 'Portal',
      });

      expect(model.name, 'Workspace');
    });
  });
}
