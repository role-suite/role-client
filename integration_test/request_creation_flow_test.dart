import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:relay/core/constants/data_source_mode.dart';
import 'package:relay/core/models/api_request_model.dart';
import 'package:relay/core/models/collection_model.dart';
import 'package:relay/core/models/data_source_config.dart';
import 'package:relay/core/models/environment_model.dart';
import 'package:relay/features/home/collection/presentation/providers/collection_providers.dart';
import 'package:relay/features/home/environment/presentation/providers/environment_providers.dart';
import 'package:relay/features/home/presentation/providers/data_source_providers.dart';
import 'package:relay/features/home/presentation/viewmodels/home_dialog_view_models.dart';
import 'package:relay/features/home/request/presentation/widgets/dialogs/create_request_dialog.dart';

CollectionModel _collection(String id, String name) {
  final now = DateTime.now();
  return CollectionModel(id: id, name: name, createdAt: now, updatedAt: now);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('creates request from create-request dialog', (tester) async {
    late _RecordingCreateRequestViewModel viewModel;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionsNotifierProvider.overrideWith(() => _StaticCollectionsNotifier([_collection('default', 'Default')])),
          environmentsNotifierProvider.overrideWith(
            () => _StaticEnvironmentsNotifier([
              EnvironmentModel(name: 'dev', variables: {'baseUrl': 'https://dev.example.com'}),
            ]),
          ),
          activeEnvironmentNameProvider.overrideWith(ActiveEnvironmentNameNotifier.new),
          currentDataSourceStateProvider.overrideWith(
            (ref) => (mode: DataSourceMode.local, config: const DataSourceConfig(baseUrl: '')),
          ),
          createRequestViewModelProvider.overrideWith((ref) {
            viewModel = _RecordingCreateRequestViewModel(ref);
            return viewModel;
          }),
        ],
        child: const MaterialApp(home: _DialogHost()),
      ),
    );

    await tester.tap(find.text('Open Create Request'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Request Name'), 'List Users');
    await tester.enterText(find.widgetWithText(TextFormField, 'URL'), 'https://api.example.com/users');

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.byType(CreateRequestDialog), findsNothing);
    expect(viewModel.createdRequests.length, 1);
    expect(viewModel.createdRequests.single.name, 'List Users');
    expect(viewModel.createdRequests.single.urlTemplate, 'https://api.example.com/users');
    expect(find.text('Request "List Users" created successfully'), findsOneWidget);
  });

  testWidgets('prevents create when api mode has non-numeric collection id', (tester) async {
    var createCalled = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionsNotifierProvider.overrideWith(() => _StaticCollectionsNotifier([_collection('default', 'Default')])),
          environmentsNotifierProvider.overrideWith(() => _StaticEnvironmentsNotifier(const [])),
          currentDataSourceStateProvider.overrideWith(
            (ref) => (mode: DataSourceMode.api, config: const DataSourceConfig(baseUrl: 'https://api.example.com')),
          ),
          createRequestViewModelProvider.overrideWith((ref) => _CallbackCreateRequestViewModel(ref, () => createCalled = true)),
        ],
        child: const MaterialApp(home: _DialogHost()),
      ),
    );

    await tester.tap(find.text('Open Create Request'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Request Name'), 'Invalid API Collection');
    await tester.enterText(find.widgetWithText(TextFormField, 'URL'), 'https://api.example.com/users');

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.byType(CreateRequestDialog), findsOneWidget);
    expect(createCalled, isFalse);
    expect(find.text('Invalid API collection selected. Re-select a collection and try again.'), findsOneWidget);
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
          child: const Text('Open Create Request'),
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

class _CallbackCreateRequestViewModel extends CreateRequestViewModel {
  _CallbackCreateRequestViewModel(super.ref, this.onCreate);

  final VoidCallback onCreate;

  @override
  Future<void> createRequest(ApiRequestModel request) async {
    onCreate();
  }
}
