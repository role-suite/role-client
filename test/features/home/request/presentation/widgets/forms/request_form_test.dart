import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/constants/data_source_mode.dart';
import 'package:relay/core/models/collection_model.dart';
import 'package:relay/core/models/data_source_config.dart';
import 'package:relay/core/models/environment_model.dart';
import 'package:relay/features/home/collection/presentation/providers/collection_providers.dart';
import 'package:relay/features/home/environment/presentation/providers/environment_providers.dart';
import 'package:relay/features/home/presentation/providers/data_source_providers.dart';
import 'package:relay/features/home/request/presentation/controllers/request_form_controller.dart';
import 'package:relay/features/home/request/presentation/widgets/forms/request_form.dart';

CollectionModel _collection(String id, String name) {
  final now = DateTime.now();
  return CollectionModel(id: id, name: name, createdAt: now, updatedAt: now);
}

void main() {
  testWidgets('local mode injects default collection when missing', (tester) async {
    final controller = RequestFormController(initialCollectionId: null);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionsNotifierProvider.overrideWith(() => _StaticCollectionsNotifier([_collection('team', 'Team')])),
          environmentsNotifierProvider.overrideWith(() => _StaticEnvironmentsNotifier(const [])),
          currentDataSourceStateProvider.overrideWith(
            (ref) => (mode: DataSourceMode.local, config: const DataSourceConfig(baseUrl: '')),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RequestForm(controller: controller, isSubmitting: false),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Default'), findsOneWidget);
    expect(controller.selectedCollectionId, 'default');
  });

  testWidgets('api mode keeps first API collection and does not add default option', (tester) async {
    final controller = RequestFormController(initialCollectionId: null);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionsNotifierProvider.overrideWith(() => _StaticCollectionsNotifier([_collection('101', 'API Team')])),
          environmentsNotifierProvider.overrideWith(() => _StaticEnvironmentsNotifier(const [])),
          currentDataSourceStateProvider.overrideWith(
            (ref) => (mode: DataSourceMode.api, config: const DataSourceConfig(baseUrl: 'https://example.test')),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RequestForm(controller: controller, isSubmitting: false),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Default'), findsNothing);
    expect(controller.selectedCollectionId, '101');
  });

  testWidgets('shows environment variable helper text and chips', (tester) async {
    final controller = RequestFormController(initialCollectionId: 'default', initialEnvironmentName: 'dev');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionsNotifierProvider.overrideWith(() => _StaticCollectionsNotifier([_collection('default', 'Default')])),
          environmentsNotifierProvider.overrideWith(
            () => _StaticEnvironmentsNotifier([
              EnvironmentModel(name: 'dev', variables: {'baseUrl': 'https://dev.example.com'}),
            ]),
          ),
          currentDataSourceStateProvider.overrideWith(
            (ref) => (mode: DataSourceMode.local, config: const DataSourceConfig(baseUrl: '')),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RequestForm(controller: controller, isSubmitting: false),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Variables from "dev" can be inserted as {{variableName}}.'), findsOneWidget);
    expect(find.text('{{baseUrl}}'), findsWidgets);
  });
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
