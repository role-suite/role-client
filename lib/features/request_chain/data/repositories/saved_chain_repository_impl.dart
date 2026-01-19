import 'package:relay/features/request_chain/domain/models/saved_request_chain.dart';
import 'package:relay/features/request_chain/domain/repositories/saved_chain_repository.dart';
import 'package:relay/features/request_chain/data/datasources/saved_chain_local_data_source.dart';

/// Implementation of SavedChainRepository using local file storage
class SavedChainRepositoryImpl implements SavedChainRepository {
  final SavedChainLocalDataSource _dataSource;

  SavedChainRepositoryImpl(this._dataSource);

  @override
  Future<List<SavedRequestChain>> getAllSavedChains() async {
    return await _dataSource.getAllSavedChains();
  }

  @override
  Future<SavedRequestChain?> getSavedChainById(String id) async {
    return await _dataSource.getSavedChainById(id);
  }

  @override
  Future<void> saveChain(SavedRequestChain chain) async {
    await _dataSource.saveChain(chain);
  }

  @override
  Future<void> deleteChain(String id) async {
    await _dataSource.deleteChain(id);
  }
}
