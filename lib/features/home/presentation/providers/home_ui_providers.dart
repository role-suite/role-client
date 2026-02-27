import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/core/models/api_request_model.dart';
import 'package:relay/features/home/presentation/providers/request_providers.dart';

/// UI-scoped provider that tracks the currently selected collection on Home.
class SelectedCollectionIdNotifier extends Notifier<String?> {
  @override
  String? build() => 'default';

  void select(String? collectionId) {
    state = collectionId;
  }
}

final selectedCollectionIdProvider = NotifierProvider<SelectedCollectionIdNotifier, String?>(SelectedCollectionIdNotifier.new);

final filteredRequestsProvider = Provider<AsyncValue<List<ApiRequestModel>>>((ref) {
  final selectedCollectionId = ref.watch(selectedCollectionIdProvider);
  final requestsAsync = ref.watch(requestsNotifierProvider);

  return requestsAsync.whenData((requests) {
    if (selectedCollectionId == null) {
      return requests;
    }

    return requests.where((request) => request.collectionId == selectedCollectionId).toList();
  });
});
