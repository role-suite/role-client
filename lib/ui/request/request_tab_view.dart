import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/api_request.dart';
import '../../core/models/request_result.dart';
import '../../core/models/response_snapshot.dart';
import '../../core/network/template_resolver.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/role_theme.dart';
import '../../core/utils/id.dart';
import '../../state/environments_notifier.dart';
import '../../state/history_notifier.dart';
import '../../state/network_providers.dart';
import '../../state/workbench_notifier.dart';
import '../../state/workbench_state.dart';
import '../../state/workspace_notifier.dart';
import '../widgets/widgets.dart';
import 'method_url_bar.dart';
import 'request_editor_panel.dart';
import 'response_viewer.dart';

class RequestTabView extends ConsumerStatefulWidget {
  const RequestTabView({super.key, required this.requestId});

  final String requestId;

  @override
  ConsumerState<RequestTabView> createState() => _RequestTabViewState();
}

class _RequestTabViewState extends ConsumerState<RequestTabView> {
  ApiRequest? _draft;
  ApiRequest? _saved;
  RequestResult? _result;
  bool _sending = false;

  String get _tabId => WorkbenchTab.idFor(WorkbenchTabType.request, widget.requestId);

  void _updateDraft(ApiRequest next) {
    setState(() => _draft = next);
    final dirty = _saved == null || !_isSame(next, _saved!);
    ref.read(workbenchProvider.notifier).setTabDirty(_tabId, dirty);
  }

  bool _isSame(ApiRequest a, ApiRequest b) {
    return a.name == b.name &&
        a.method == b.method &&
        a.url == b.url &&
        a.headers.toString() == b.headers.toString() &&
        a.queryParams.toString() == b.queryParams.toString() &&
        a.bodyType == b.bodyType &&
        a.body == b.body &&
        a.formFields.toString() == b.formFields.toString() &&
        a.authType == b.authType &&
        a.authConfig.toString() == b.authConfig.toString() &&
        a.description == b.description;
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null) return;
    await ref.read(workspaceProvider.notifier).updateRequest(draft);
    setState(() => _saved = draft);
    ref.read(workbenchProvider.notifier)
      ..setTabDirty(_tabId, false)
      ..renameTab(_tabId, draft.name);
  }

  Future<void> _send() async {
    final draft = _draft;
    if (draft == null || draft.url.trim().isEmpty) return;

    setState(() {
      _sending = true;
      _result = null;
    });

    final variables = ref.read(activeVariablesProvider);
    final runner = ref.read(requestRunnerProvider);
    final result = await runner.run(draft, variables);

    if (!mounted) return;
    setState(() {
      _sending = false;
      _result = result;
    });

    await ref
        .read(historyProvider.notifier)
        .record(
          ResponseSnapshot(
            id: generateId('snap'),
            requestId: draft.id,
            requestName: draft.name,
            method: draft.method,
            url: draft.url,
            timestamp: DateTime.now(),
            result: result,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(workspaceProvider);

    return workspace.when(
      loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (error, _) => Center(child: Text('Failed to load: $error')),
      data: (state) {
        ApiRequest? persisted;
        for (final r in state.requests) {
          if (r.id == widget.requestId) {
            persisted = r;
            break;
          }
        }

        if (persisted == null) {
          return const EmptyState(icon: Icons.dns_outlined, title: 'Request not found', message: 'It may have been deleted.');
        }

        if (_draft == null) {
          _saved = persisted;
          _draft = persisted;
        }

        return _buildEditor(context, _draft!);
      },
    );
  }

  Widget _buildEditor(BuildContext context, ApiRequest draft) {
    final colors = context.colors;
    final variables = ref.watch(activeVariablesProvider);
    final unresolved = TemplateResolver.unresolvedIn(draft.url, variables);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.border))),
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: ValueKey('name-${draft.id}'),
                  initialValue: draft.name,
                  style: context.type.bodyStrong,
                  decoration: const InputDecoration(border: InputBorder.none, isDense: true, hintText: 'Request name'),
                  onChanged: (v) => _updateDraft(draft.copyWith(name: v)),
                ),
              ),
              if (unresolved.isNotEmpty)
                Tooltip(
                  message: 'Unresolved variables: ${unresolved.join(', ')}',
                  child: Icon(Icons.warning_amber_rounded, size: 16, color: colors.warning),
                ),
              const SizedBox(width: AppSpacing.sm),
              AppButton(label: 'Save', icon: Icons.save_outlined, onPressed: _save),
            ],
          ),
        ),
        Expanded(
          child: SplitView(
            top: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MethodUrlBar(
                  key: ValueKey('url-${draft.id}'),
                  method: draft.method,
                  url: draft.url,
                  sending: _sending,
                  onMethodChanged: (m) => _updateDraft(draft.copyWith(method: m)),
                  onUrlChanged: (v) => _updateDraft(draft.copyWith(url: v)),
                  onSend: _send,
                ),
                Expanded(child: RequestEditorPanel(request: draft, onChanged: _updateDraft)),
              ],
            ),
            bottom: ResponseViewer(result: _result, sending: _sending),
          ),
        ),
      ],
    );
  }
}
