import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/models/api_request_model.dart';
import 'package:relay/core/models/collection_model.dart';
import 'package:relay/core/models/environment_model.dart';
import 'package:relay/features/home/collection/presentation/providers/collection_providers.dart';
import 'package:relay/features/home/environment/presentation/providers/environment_providers.dart';
import 'package:relay/features/home/presentation/providers/home_ui_providers.dart';
import 'package:relay/features/home/presentation/viewmodels/home_dialog_view_models.dart';
import 'package:relay/features/home/request/presentation/widgets/dialogs/create_request_dialog.dart';

CollectionModel _collection(String id, String name) {
  final now = DateTime.now();
  return CollectionModel(id: id, name: name, createdAt: now, updatedAt: now);
}

void main() {
  testWidgets('shows validation snackbar when required fields are empty', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionsNotifierProvider.overrideWith(() => _StaticCollectionsNotifier([_collection('default', 'Default')])),
          environmentsNotifierProvider.overrideWith(() => _StaticEnvironmentsNotifier(const [])),
        ],
        child: const MaterialApp(home: _DialogHost()),
      ),
    );

    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('Please fill in all required fields'), findsOneWidget);
    expect(find.byType(CreateRequestDialog), findsOneWidget);
  });

  testWidgets('creates request and closes dialog when form is valid', (tester) async {
    late _RecordingCreateRequestViewModel createVm;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionsNotifierProvider.overrideWith(() => _StaticCollectionsNotifier([_collection('default', 'Default')])),
          environmentsNotifierProvider.overrideWith(() => _StaticEnvironmentsNotifier(const [])),
          activeEnvironmentNameProvider.overrideWith(ActiveEnvironmentNameNotifier.new),
          createRequestViewModelProvider.overrideWith((ref) {
            createVm = _RecordingCreateRequestViewModel(ref);
            return createVm;
          }),
        ],
        child: const MaterialApp(home: _DialogHost()),
      ),
    );

    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Request Name'), 'Get Users');
    await tester.enterText(find.widgetWithText(TextFormField, 'URL'), 'https://api.example.com/users');

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.byType(CreateRequestDialog), findsNothing);
    expect(createVm.createdRequests.length, 1);
    expect(createVm.createdRequests.single.name, 'Get Users');
    expect(createVm.createdRequests.single.urlTemplate, 'https://api.example.com/users');
    expect(find.text('Request "Get Users" created successfully'), findsOneWidget);
  });
}

class _DialogHost extends StatelessWidget {
  const _DialogHost();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () {
            showDialog<void>(
              context: context,
              builder: (_) => const CreateRequestDialog(initialCollectionId: 'default'),
            );
          },
          child: const Text('Open Dialog'),
        ),
      ),
    );
  }
}

class _StaticCollectionsNotifier extends CollectionsNotifier {
  _StaticCollectionsNotifier(this._collections);

  final List<CollectionModel> _collections;

  @override
  Future<List<CollectionModel>> build() async => _collections;
}

class _StaticEnvironmentsNotifier extends EnvironmentsNotifier {
  _StaticEnvironmentsNotifier(this._environments);

  final List<EnvironmentModel> _environments;

  @override
  Future<List<EnvironmentModel>> build() async => _environments;
}

class _RecordingCreateRequestViewModel extends CreateRequestViewModel {
  _RecordingCreateRequestViewModel(super.ref);

  final List<ApiRequestModel> createdRequests = [];

  @override
  Future<void> createRequest(ApiRequestModel request) async {
    createdRequests.add(request);
  }
}
