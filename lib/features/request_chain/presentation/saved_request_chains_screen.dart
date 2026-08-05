import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/core/presentation/layout/scaffold.dart';
import 'package:relay/core/presentation/widgets/app_button.dart';
import 'package:relay/features/request_chain/domain/models/saved_request_chain.dart';
import 'package:relay/features/request_chain/presentation/providers/request_chain_providers.dart';

class SavedRequestChainsScreen extends ConsumerWidget {
  const SavedRequestChainsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedChainsAsync = ref.watch(savedChainsProvider);

    return AppScaffold(
      title: 'Saved Chains',
      body: savedChainsAsync.when(
        data: (savedChains) {
          if (savedChains.isEmpty) {
            return Center(child: Text('No saved chains yet.', style: Theme.of(context).textTheme.bodyLarge));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: savedChains.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _SavedChainCard(chain: savedChains[index]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Failed to load saved chains', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(error.toString(), style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              AppButton(label: 'Retry', onPressed: () => ref.invalidate(savedChainsProvider)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedChainCard extends ConsumerWidget {
  const _SavedChainCard({required this.chain});

  final SavedRequestChain chain;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updatedAt = chain.updatedAt;
    final timestamp =
        '${updatedAt.year}-${updatedAt.month.toString().padLeft(2, '0')}-${updatedAt.day.toString().padLeft(2, '0')} '
        '${updatedAt.hour.toString().padLeft(2, '0')}:${updatedAt.minute.toString().padLeft(2, '0')}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(chain.name, style: Theme.of(context).textTheme.titleMedium)),
                IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Delete saved chain', onPressed: () => _confirmDelete(context, ref)),
              ],
            ),
            const SizedBox(height: 8),
            if (chain.description != null && chain.description!.isNotEmpty) ...[
              Text(chain.description!, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 8),
            ],
            Text('${chain.chainItems.length} requests', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text('Updated $timestamp', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: AppButton(label: 'Load Chain', icon: Icons.playlist_add_check, onPressed: () => Navigator.of(context).pop(chain)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Saved Chain'),
        content: Text('Delete "${chain.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final repository = ref.read(savedChainRepositoryProvider);
      await repository.deleteChain(chain.id);
      ref.invalidate(savedChainsProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deleted saved chain: ${chain.name}')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete saved chain: $e')));
      }
    }
  }
}
