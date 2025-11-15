import 'package:relay/core/model/environment_model.dart';

/// Repository interface for managing environments
/// This is part of the domain layer and defines the contract
abstract class EnvironmentRepository {
  /// Get all environments
  Future<List<EnvironmentModel>> getAllEnvironments();

  /// Get an environment by name
  Future<EnvironmentModel?> getEnvironmentByName(String name);

  /// Save an environment
  Future<void> saveEnvironment(EnvironmentModel environment);

  /// Delete an environment by name
  Future<void> deleteEnvironment(String name);

  /// Set the active environment
  Future<void> setActiveEnvironment(String? name);

  /// Get the active environment
  Future<EnvironmentModel?> getActiveEnvironment();

  /// Resolve template variables in a string
  String resolveTemplate(String input, EnvironmentModel? environment);
}

