import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/core/models/api_request_model.dart';
import 'package:relay/core/models/collection_model.dart';
import 'package:relay/core/models/shared_request_model.dart';
import 'package:relay/core/presentation/widgets/app_button.dart';
import 'package:relay/core/presentation/widgets/app_text_field.dart';
import 'package:relay/features/home/presentation/providers/providers.dart';
import 'package:relay/core/utils/error_utils.dart';

class ShareRequestDialog extends ConsumerStatefulWidget {
  const ShareRequestDialog({super.key, required this.requests});

  final List<ApiRequestModel> requests;

  @override
  ConsumerState<ShareRequestDialog> createState() => _ShareRequestDialogState();
}

class _ShareRequestDialogState extends ConsumerState<ShareRequestDialog> {
  late final TextEditingController _targetWorkspaceController;
  late final TextEditingController _noteController;
  String? _selectedRequestId;
  bool _isSending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _targetWorkspaceController = TextEditingController();
    _noteController = TextEditingController();
    if (widget.requests.isNotEmpty) {
      _selectedRequestId = widget.requests.first.id;
    }
  }

  @override
  void dispose() {
    _targetWorkspaceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    final target = _targetWorkspaceController.text.trim();
    if (target.isEmpty) {
      setState(() => _error = 'Target workspace ID is required');
      return;
    }
    if (_selectedRequestId == null) {
      setState(() => _error = 'Select a request to share');
      return;
    }

    final request = widget.requests.firstWhere((r) => r.id == _selectedRequestId, orElse: () => widget.requests.first);
    setState(() {
      _isSending = true;
      _error = null;
    });

    try {
      final actions = ref.read(sharedRequestActionsProvider);
      await actions.shareRequest(request: request.toJson(), targetWorkspaceId: target, note: _noteController.text.trim());
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = _humanizeError(e);
          _isSending = false;
        });
      }
    }
  }

  String _humanizeError(Object error) {
    return humanizeApiError(error);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Share request'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              controller: _targetWorkspaceController,
              label: 'Target workspace ID',
              hint: 'Workspace ID of the other team',
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey(_selectedRequestId ?? 'none'),
              initialValue: _selectedRequestId,
              items: widget.requests
                  .map((request) => DropdownMenuItem(value: request.id, child: Text('${request.method.name} ${request.name}')))
                  .toList(),
              decoration: const InputDecoration(labelText: 'Request', border: OutlineInputBorder()),
              onChanged: _isSending
                  ? null
                  : (value) {
                      setState(() {
                        _selectedRequestId = value;
                        _error = null;
                      });
                    },
            ),
            const SizedBox(height: 12),
            AppTextField(controller: _noteController, label: 'Note (optional)', hint: 'Why you are sharing this request', maxLines: 2),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _isSending ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        AppButton(label: _isSending ? 'Sharing...' : 'Share', icon: Icons.send, onPressed: _isSending ? null : _share),
      ],
    );
  }
}

class SharedRequestsInboxDialog extends ConsumerStatefulWidget {
  const SharedRequestsInboxDialog({super.key, required this.collections, required this.selectedCollectionId});

  final List<CollectionModel> collections;
  final String? selectedCollectionId;

  @override
  ConsumerState<SharedRequestsInboxDialog> createState() => _SharedRequestsInboxDialogState();
}

class _SharedRequestsInboxDialogState extends ConsumerState<SharedRequestsInboxDialog> {
  String? _selectedCollectionId;
  String? _error;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _selectedCollectionId = widget.selectedCollectionId ?? (widget.collections.isNotEmpty ? widget.collections.first.id : null);
  }

  Future<void> _import(SharedRequestModel shared) async {
    if (_selectedCollectionId == null || _selectedCollectionId!.isEmpty) {
      setState(() => _error = 'Select a collection to import into');
      return;
    }
    setState(() {
      _isImporting = true;
      _error = null;
    });

    try {
      final actions = ref.read(sharedRequestActionsProvider);
      await actions.importSharedRequest(sharedRequestId: shared.id, collectionId: _selectedCollectionId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request imported.')));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = _humanizeError(e);
        });
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  String _humanizeError(Object error) {
    return humanizeApiError(error);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sharedAsync = ref.watch(sharedRequestsProvider);

    return AlertDialog(
      title: const Text('Shared requests inbox'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              key: ValueKey(_selectedCollectionId ?? 'none'),
              initialValue: _selectedCollectionId,
              items: widget.collections.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
              decoration: const InputDecoration(labelText: 'Import into collection', border: OutlineInputBorder()),
              onChanged: _isImporting
                  ? null
                  : (value) {
                      setState(() {
                        _selectedCollectionId = value;
                        _error = null;
                      });
                    },
            ),
            const SizedBox(height: 12),
            sharedAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return Text('No shared requests yet.', style: theme.textTheme.bodySmall);
                }
                return SizedBox(
                  height: 260,
                  child: ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 12),
                    itemBuilder: (context, index) {
                      final shared = items[index];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(shared.title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text('${shared.method} ${shared.url}', style: theme.textTheme.bodySmall),
                          const SizedBox(height: 4),
                          if (shared.fromTeamName.isNotEmpty) Text('From: ${shared.fromTeamName}', style: theme.textTheme.bodySmall),
                          if (shared.fromWorkspaceId.isNotEmpty) Text('Workspace: ${shared.fromWorkspaceId}', style: theme.textTheme.bodySmall),
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerRight,
                            child: AppButton(
                              label: _isImporting ? 'Importing...' : 'Import',
                              icon: Icons.download,
                              size: AppButtonSize.small,
                              onPressed: _isImporting ? null : () => _import(shared),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (error, _) => Text(_humanizeError(error), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [TextButton(onPressed: _isImporting ? null : () => Navigator.of(context).pop(), child: const Text('Close'))],
    );
  }
}
