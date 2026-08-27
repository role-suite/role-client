import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/api_request.dart';
import '../../core/models/collection.dart';
import '../../core/models/workspace_origin.dart';
import '../../core/remote/workspace_permissions.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/role_theme.dart';
import '../../state/auth_notifier.dart';
import '../../state/workbench_notifier.dart';
import '../../state/workbench_state.dart';
import '../../state/workspace_notifier.dart';
import '../remote_error.dart';
import '../widgets/widgets.dart';
import 'collection_dialogs.dart';

class RequestsSidebarPanel extends ConsumerWidget {
  const RequestsSidebarPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(workspaceProvider);
    final query = ref.watch(workbenchProvider.select((s) => s.searchQuery)).toLowerCase();
    final canWriteRemoteWorkspace = ref.watch(activeRemoteWorkspaceCanWriteProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'Requests',
          trailing: AppIconButton(
            icon: Icons.create_new_folder_outlined,
            tooltip: canWriteRemoteWorkspace ? 'New collection' : remoteWorkspaceReadOnlyMessage,
            onPressed: canWriteRemoteWorkspace ? () => showCreateCollectionDialog(context, ref) : null,
          ),
        ),
        Expanded(
          child: workspace.when(
            loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            error: (error, _) => Padding(padding: const EdgeInsets.all(16), child: Text('$error')),
            data: (state) {
              if (state.collections.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: EmptyState(icon: Icons.dns_outlined, title: 'No collections yet', message: 'Create one to start adding requests.'),
                );
              }
              return ListView(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                children: [
                  for (final collection in state.collections)
                    _CollectionSection(collection: collection, requests: _filter(state.requestsIn(collection.id), query)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  List<ApiRequest> _filter(List<ApiRequest> requests, String query) {
    if (query.isEmpty) return requests;
    return requests.where((r) => r.name.toLowerCase().contains(query) || r.url.toLowerCase().contains(query)).toList();
  }
}

class _CollectionSection extends ConsumerStatefulWidget {
  const _CollectionSection({required this.collection, required this.requests});

  final Collection collection;
  final List<ApiRequest> requests;

  @override
  ConsumerState<_CollectionSection> createState() => _CollectionSectionState();
}

class _CollectionSectionState extends ConsumerState<_CollectionSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isRemote = widget.collection.origin == WorkspaceOrigin.remote;
    final canWrite = !isRemote || ref.watch(activeRemoteWorkspaceCanWriteProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
            child: Row(
              children: [
                Icon(_expanded ? Icons.expand_more : Icons.chevron_right, size: 16, color: colors.textMuted),
                const SizedBox(width: 2),
                Expanded(
                  child: Text(widget.collection.name, style: context.type.bodyStrong, overflow: TextOverflow.ellipsis),
                ),
                if (isRemote)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Tooltip(
                      message: 'Synced with workspace',
                      child: Icon(Icons.cloud_outlined, size: 14, color: colors.textMuted),
                    ),
                  ),
                AppIconButton(
                  icon: Icons.add,
                  tooltip: canWrite ? 'New request' : remoteWorkspaceReadOnlyMessage,
                  onPressed: canWrite
                      ? () async {
                          try {
                            final request = await ref
                                .read(workspaceProvider.notifier)
                                .createRequest(collectionId: widget.collection.id, name: 'New Request');
                            if (!context.mounted) return;
                            ref.read(workbenchProvider.notifier).openTab(type: WorkbenchTabType.request, title: request.name, payloadId: request.id);
                          } catch (error) {
                            if (!context.mounted) return;
                            showRemoteErrorSnackBar(context, 'Could not create request', error);
                          }
                        }
                      : null,
                ),
                if (canWrite)
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_horiz, size: 16, color: colors.textMuted),
                    color: colors.surfaceRaised,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.mdRadius,
                      side: BorderSide(color: colors.border),
                    ),
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'rename', child: Text('Rename')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                    onSelected: (action) {
                      if (action == 'rename') {
                        showRenameCollectionDialog(context, ref, widget.collection);
                      } else if (action == 'delete') {
                        showDeleteCollectionDialog(context, ref, widget.collection);
                      }
                    },
                  ),
              ],
            ),
          ),
        ),
        if (_expanded)
          for (final request in widget.requests) _RequestRow(request: request, isRemote: isRemote, canWrite: canWrite),
      ],
    );
  }
}

class _RequestRow extends ConsumerWidget {
  const _RequestRow({required this.request, required this.canWrite, this.isRemote = false});

  final ApiRequest request;

  /// Whether this request's parent collection is remote-origin.
  final bool isRemote;
  final bool canWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final activeTabId = ref.watch(workbenchProvider.select((s) => s.activeTabId));
    final tabId = WorkbenchTab.idFor(WorkbenchTabType.request, request.id);
    final selected = activeTabId == tabId;

    return Material(
      color: selected ? colors.accent.withValues(alpha: 0.1) : Colors.transparent,
      child: InkWell(
        onTap: () => ref.read(workbenchProvider.notifier).openTab(type: WorkbenchTabType.request, title: request.name, payloadId: request.id),
        child: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.xl, right: AppSpacing.sm, top: 6, bottom: 6),
          child: Row(
            children: [
              SizedBox(width: 40, child: MethodBadge(request.method, compact: true)),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(request.name, style: context.type.body, overflow: TextOverflow.ellipsis),
              ),
              if (canWrite)
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_horiz, size: 14, color: colors.textMuted),
                  color: colors.surfaceRaised,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.mdRadius,
                    side: BorderSide(color: colors.border),
                  ),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                  onSelected: (action) async {
                    try {
                      if (action == 'duplicate') {
                        final copy = await ref.read(workspaceProvider.notifier).duplicateRequest(request);
                        if (!context.mounted) return;
                        ref.read(workbenchProvider.notifier).openTab(type: WorkbenchTabType.request, title: copy.name, payloadId: copy.id);
                      } else if (action == 'delete') {
                        ref.read(workbenchProvider.notifier).closeTab(tabId);
                        await ref.read(workspaceProvider.notifier).deleteRequest(request);
                      }
                    } catch (error) {
                      if (!context.mounted) return;
                      showRemoteErrorSnackBar(context, action == 'duplicate' ? 'Could not duplicate request' : 'Could not delete request', error);
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
