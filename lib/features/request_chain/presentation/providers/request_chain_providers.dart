import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/features/home/domain/repositories/environment_repository.dart';
import 'package:relay/features/home/presentation/providers/repository_providers.dart';
import 'package:relay/features/request_chain/data/services/request_chain_service.dart';

/// Provider for RequestChainService
final requestChainServiceProvider = Provider<RequestChainService>((ref) {
  final environmentRepository = ref.watch(environmentRepositoryProvider);
  return RequestChainService(environmentRepository);
});
