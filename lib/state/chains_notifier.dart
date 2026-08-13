import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/chain.dart';
import '../core/storage/json_store.dart';
import '../core/storage/workspace_paths.dart';
import '../core/utils/id.dart';

class ChainsNotifier extends AsyncNotifier<List<SavedChain>> {
  @override
  Future<List<SavedChain>> build() async {
    final raw = await JsonStore.instance.readAll(WorkspacePaths.flows);
    final chains = raw.map(SavedChain.fromJson).toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return chains;
  }

  Future<SavedChain> create({required String name, String? description, List<ChainStep> steps = const []}) async {
    final now = DateTime.now();
    final chain = SavedChain(id: generateId('flow'), name: name, description: description, steps: steps, createdAt: now, updatedAt: now);
    await JsonStore.instance.write(WorkspacePaths.flowFile(chain.id), chain.toJson());
    state = AsyncData([...state.value ?? const [], chain]);
    return chain;
  }

  Future<void> updateChain(SavedChain updated) async {
    await JsonStore.instance.write(WorkspacePaths.flowFile(updated.id), updated.toJson());
    state = AsyncData((state.value ?? const []).map((c) => c.id == updated.id ? updated : c).toList());
  }

  Future<void> delete(String id) async {
    await JsonStore.instance.delete(WorkspacePaths.flowFile(id));
    state = AsyncData((state.value ?? const []).where((c) => c.id != id).toList());
  }
}

final chainsProvider = AsyncNotifierProvider<ChainsNotifier, List<SavedChain>>(ChainsNotifier.new);
