import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/core/models/api_request_model.dart';
import 'package:relay/features/home/presentation/providers/usecase_providers.dart';

import '../../domain/usecases/create_request_usecase.dart';
import '../../domain/usecases/delete_request_usecase.dart';
import '../../domain/usecases/get_all_requests_usecase.dart';
import '../../domain/usecases/update_request_usecase.dart';

/// Provider for all requests - watches the use case
final requestsProvider = FutureProvider<List<ApiRequestModel>>((ref) async {
  final useCase = ref.watch(getAllRequestsUseCaseProvider);
  return useCase();
});

/// Notifier for managing request state with local updates
class RequestsNotifier extends AsyncNotifier<List<ApiRequestModel>> {
  GetAllRequestsUseCase get _getAllRequestsUseCase => ref.read(getAllRequestsUseCaseProvider);
  CreateRequestUseCase get _createRequestUseCase => ref.read(createRequestUseCaseProvider);
  UpdateRequestUseCase get _updateRequestUseCase => ref.read(updateRequestUseCaseProvider);
  DeleteRequestUseCase get _deleteRequestUseCase => ref.read(deleteRequestUseCaseProvider);

  @override
  Future<List<ApiRequestModel>> build() {
    final useCase = ref.watch(getAllRequestsUseCaseProvider);
    return useCase();
  }

  Future<void> _loadRequests() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _getAllRequestsUseCase());
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
final requestsNotifierProvider = AsyncNotifierProvider<RequestsNotifier, List<ApiRequestModel>>(RequestsNotifier.new);
