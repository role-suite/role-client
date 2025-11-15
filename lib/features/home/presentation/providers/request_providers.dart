import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:relay/core/model/api_request_model.dart';
import 'package:relay/features/home/presentation/providers/usecase_providers.dart';

import '../../domain/usecases/create_request_usecase.dart';
import '../../domain/usecases/delete_request_usecase.dart';
import '../../domain/usecases/get_all_requests_usecase.dart';
import '../../domain/usecases/update_request_usecase.dart';

/// Provider for all requests - watches the use case
final requestsProvider = FutureProvider<List<ApiRequestModel>>((ref) async {
  final useCase = ref.watch(getAllRequestsUseCaseProvider);
  return await useCase();
});

/// Notifier for managing request state with local updates
class RequestsNotifier extends StateNotifier<AsyncValue<List<ApiRequestModel>>> {
  final GetAllRequestsUseCase _getAllRequestsUseCase;
  final CreateRequestUseCase _createRequestUseCase;
  final UpdateRequestUseCase _updateRequestUseCase;
  final DeleteRequestUseCase _deleteRequestUseCase;

  RequestsNotifier(
    this._getAllRequestsUseCase,
    this._createRequestUseCase,
    this._updateRequestUseCase,
    this._deleteRequestUseCase,
  ) : super(const AsyncValue.loading()) {
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    state = const AsyncValue.loading();
    try {
      final requests = await _getAllRequestsUseCase();
      state = AsyncValue.data(requests);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> addRequest(ApiRequestModel request) async {
    try {
      await _createRequestUseCase(request);
      await _loadRequests();
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow; // Re-throw so UI can show error message
    }
  }

  Future<void> updateRequest(ApiRequestModel request) async {
    try {
      await _updateRequestUseCase(request);
      await _loadRequests();
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow; // Re-throw so UI can show error message
    }
  }

  Future<void> removeRequest(String id) async {
    try {
      await _deleteRequestUseCase(id);
      await _loadRequests();
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow; // Re-throw so UI can show error message
    }
  }

  void refresh() {
    _loadRequests();
  }
}

/// Provider for RequestsNotifier
final requestsNotifierProvider = StateNotifierProvider<RequestsNotifier, AsyncValue<List<ApiRequestModel>>>((ref) {
  return RequestsNotifier(
    ref.watch(getAllRequestsUseCaseProvider),
    ref.watch(createRequestUseCaseProvider),
    ref.watch(updateRequestUseCaseProvider),
    ref.watch(deleteRequestUseCaseProvider),
  );
});

