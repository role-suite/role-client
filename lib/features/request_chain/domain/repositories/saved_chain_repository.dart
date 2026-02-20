import 'package:relay/features/request_chain/domain/models/saved_request_chain.dart';

/// Repository interface for managing saved request chains
/// This is part of the domain layer and defines the contract
abstract class SavedChainRepository {
  /// Get all saved chains
  Future<List<SavedRequestChain>> getAllSavedChains();

  /// Get a saved chain by ID
  Future<SavedRequestChain?> getSavedChainById(String id);

  /// Save a chain (create or update)
  Future<void> saveChain(SavedRequestChain chain);

  /// Delete a saved chain by ID
  Future<void> deleteChain(String id);
}
