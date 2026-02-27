import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/features/home/presentation/providers/environment_providers.dart';
import 'package:relay/features/home/presentation/providers/home_ui_providers.dart';

void main() {
  test('selectedCollectionIdProvider defaults to default and updates', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(selectedCollectionIdProvider), 'default');

    container.read(selectedCollectionIdProvider.notifier).select('collection-1');
    expect(container.read(selectedCollectionIdProvider), 'collection-1');
  });

  test('activeEnvironmentNameProvider defaults to null and updates', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(activeEnvironmentNameProvider), isNull);

    container.read(activeEnvironmentNameProvider.notifier).setActiveName('dev');
    expect(container.read(activeEnvironmentNameProvider), 'dev');

    container.read(activeEnvironmentNameProvider.notifier).setActiveName(null);
    expect(container.read(activeEnvironmentNameProvider), isNull);
  });
}
