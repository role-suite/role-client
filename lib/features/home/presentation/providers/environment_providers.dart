import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:relay/core/model/environment_model.dart';
import 'package:relay/features/home/presentation/providers/usecase_providers.dart';

import '../../domain/usecases/create_environment_usecase.dart';
import '../../domain/usecases/delete_environment_usecase.dart';
import '../../domain/usecases/get_active_environment_usecase.dart';
import '../../domain/usecases/get_all_environments_usecase.dart';
import '../../domain/usecases/set_active_environment_usecase.dart';
import '../../domain/usecases/update_environment_usecase.dart';

/// Provider for all environments
final environmentsProvider = FutureProvider<List<EnvironmentModel>>((ref) async {
  final useCase = ref.watch(getAllEnvironmentsUseCaseProvider);
  return await useCase();
});

/// Provider for active environment name (local state)
final activeEnvironmentNameProvider = StateProvider<String?>((ref) => null);

/// Provider for active environment model
final activeEnvironmentProvider = FutureProvider<EnvironmentModel?>((ref) async {
  final useCase = ref.watch(getActiveEnvironmentUseCaseProvider);
  return await useCase();
});

/// Notifier for managing active environment
class ActiveEnvironmentNotifier extends StateNotifier<AsyncValue<EnvironmentModel?>> {
  final GetActiveEnvironmentUseCase _getActiveEnvironmentUseCase;
  final SetActiveEnvironmentUseCase _setActiveEnvironmentUseCase;

  ActiveEnvironmentNotifier(
    this._getActiveEnvironmentUseCase,
    this._setActiveEnvironmentUseCase,
  ) : super(const AsyncValue.loading()) {
    _loadActiveEnvironment();
  }

  Future<void> _loadActiveEnvironment() async {
    state = const AsyncValue.loading();
    try {
      final environment = await _getActiveEnvironmentUseCase();
      state = AsyncValue.data(environment);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> setActiveEnvironment(String? name) async {
    try {
      await _setActiveEnvironmentUseCase(name);
      await _loadActiveEnvironment();
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }
}

/// Provider for ActiveEnvironmentNotifier
final activeEnvironmentNotifierProvider = StateNotifierProvider<ActiveEnvironmentNotifier, AsyncValue<EnvironmentModel?>>((ref) {
  return ActiveEnvironmentNotifier(
    ref.watch(getActiveEnvironmentUseCaseProvider),
    ref.watch(setActiveEnvironmentUseCaseProvider),
  );
});

/// Notifier for managing environment state
class EnvironmentsNotifier extends StateNotifier<AsyncValue<List<EnvironmentModel>>> {
  final GetAllEnvironmentsUseCase _getAllEnvironmentsUseCase;
  final CreateEnvironmentUseCase _createEnvironmentUseCase;
  final UpdateEnvironmentUseCase _updateEnvironmentUseCase;
  final DeleteEnvironmentUseCase _deleteEnvironmentUseCase;

  EnvironmentsNotifier(
    this._getAllEnvironmentsUseCase,
    this._createEnvironmentUseCase,
    this._updateEnvironmentUseCase,
    this._deleteEnvironmentUseCase,
  ) : super(const AsyncValue.loading()) {
    _loadEnvironments();
  }

  Future<void> _loadEnvironments() async {
    state = const AsyncValue.loading();
    try {
      final environments = await _getAllEnvironmentsUseCase();
      state = AsyncValue.data(environments);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> addEnvironment(EnvironmentModel environment) async {
    try {
      await _createEnvironmentUseCase(environment);
      await _loadEnvironments();
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow; // Re-throw so UI can show error message
    }
  }

  Future<void> updateEnvironment(EnvironmentModel environment) async {
    try {
      await _updateEnvironmentUseCase(environment);
      await _loadEnvironments();
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow; // Re-throw so UI can show error message
    }
  }

  Future<void> removeEnvironment(String name) async {
    try {
      await _deleteEnvironmentUseCase(name);
      await _loadEnvironments();
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow; // Re-throw so UI can show error message
    }
  }

  void refresh() {
    _loadEnvironments();
  }
}

/// Provider for EnvironmentsNotifier
final environmentsNotifierProvider = StateNotifierProvider<EnvironmentsNotifier, AsyncValue<List<EnvironmentModel>>>((ref) {
  return EnvironmentsNotifier(
    ref.watch(getAllEnvironmentsUseCaseProvider),
    ref.watch(createEnvironmentUseCaseProvider),
    ref.watch(updateEnvironmentUseCaseProvider),
    ref.watch(deleteEnvironmentUseCaseProvider),
  );
});

