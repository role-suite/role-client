import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/core/models/environment_model.dart';
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
  return useCase();
});

/// Provider for active environment name (local state)
class ActiveEnvironmentNameNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setActiveName(String? name) {
    state = name;
  }
}

final activeEnvironmentNameProvider = NotifierProvider<ActiveEnvironmentNameNotifier, String?>(ActiveEnvironmentNameNotifier.new);

/// Provider for active environment model
final activeEnvironmentProvider = FutureProvider<EnvironmentModel?>((ref) async {
  final useCase = ref.watch(getActiveEnvironmentUseCaseProvider);
  return useCase();
});

/// Notifier for managing active environment
class ActiveEnvironmentNotifier extends AsyncNotifier<EnvironmentModel?> {
  late final GetActiveEnvironmentUseCase _getActiveEnvironmentUseCase;
  late final SetActiveEnvironmentUseCase _setActiveEnvironmentUseCase;

  @override
  Future<EnvironmentModel?> build() {
    _getActiveEnvironmentUseCase = ref.watch(getActiveEnvironmentUseCaseProvider);
    _setActiveEnvironmentUseCase = ref.watch(setActiveEnvironmentUseCaseProvider);
    return _getActiveEnvironmentUseCase();
  }

  Future<void> _loadActiveEnvironment() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _getActiveEnvironmentUseCase());
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
final activeEnvironmentNotifierProvider = AsyncNotifierProvider<ActiveEnvironmentNotifier, EnvironmentModel?>(ActiveEnvironmentNotifier.new);

/// Notifier for managing environment state
class EnvironmentsNotifier extends AsyncNotifier<List<EnvironmentModel>> {
  late final GetAllEnvironmentsUseCase _getAllEnvironmentsUseCase;
  late final CreateEnvironmentUseCase _createEnvironmentUseCase;
  late final UpdateEnvironmentUseCase _updateEnvironmentUseCase;
  late final DeleteEnvironmentUseCase _deleteEnvironmentUseCase;

  @override
  Future<List<EnvironmentModel>> build() {
    _getAllEnvironmentsUseCase = ref.watch(getAllEnvironmentsUseCaseProvider);
    _createEnvironmentUseCase = ref.watch(createEnvironmentUseCaseProvider);
    _updateEnvironmentUseCase = ref.watch(updateEnvironmentUseCaseProvider);
    _deleteEnvironmentUseCase = ref.watch(deleteEnvironmentUseCaseProvider);
    return _getAllEnvironmentsUseCase();
  }

  Future<void> _loadEnvironments() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _getAllEnvironmentsUseCase());
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
final environmentsNotifierProvider = AsyncNotifierProvider<EnvironmentsNotifier, List<EnvironmentModel>>(EnvironmentsNotifier.new);
