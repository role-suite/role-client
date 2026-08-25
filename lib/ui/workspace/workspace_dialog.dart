import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/remote_workspace.dart';
import '../../core/models/workspace_invitation.dart';
import '../../core/models/workspace_member.dart';
import '../../core/remote/auth/auth_state.dart';
import '../../core/remote/remote_api_exception.dart';
import '../../core/remote/workspace/workspace_service.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/role_theme.dart';
import '../../state/auth_notifier.dart';
import '../widgets/widgets.dart';
import 'workspace_import_export_actions.dart';

/// Workspace switcher, members + roles, invitations, "convert to team" (§10
/// of docs/08-ONLINE-MODE-INTEGRATION.md). Reachable only from the account
/// menu — never a gate in front of the rest of the app; local-only users
/// never see this. No local caching/outbox here (unlike collections/
/// environments): every action is a direct, synchronous REST call, same
/// pattern as `AuthNotifier.listSessions()`.
Future<void> showWorkspaceDialog(BuildContext context) {
  return showDialog<void>(context: context, builder: (context) => const _WorkspaceDialog());
}

class _WorkspaceDialog extends ConsumerStatefulWidget {
  const _WorkspaceDialog();

  @override
  ConsumerState<_WorkspaceDialog> createState() => _WorkspaceDialogState();
}

class _WorkspaceDialogState extends ConsumerState<_WorkspaceDialog> {
  Future<List<WorkspaceMember>>? _membersFuture;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reloadMembers();
  }

  AuthSignedIn get _auth => ref.read(authNotifierProvider) as AuthSignedIn;
  WorkspaceService get _service => ref.read(workspaceServiceProvider)!;

  void _reloadMembers() {
    final auth = _auth;
    _membersFuture = auth.activeWorkspace.type == 'team' ? _service.listMembers(auth.activeWorkspaceId) : null;
  }

  String _messageFor(Object error) => error is RemoteApiException ? error.message : error.toString();

  /// Runs [action], then refreshes the member list and clears/reports the
  /// error banner — shared by every mutating action below.
  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) setState(_reloadMembers);
    } catch (error) {
      if (mounted) setState(() => _error = _messageFor(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _switchTo(int workspaceId) => _run(() => ref.read(authNotifierProvider.notifier).switchWorkspace(workspaceId));

  Future<void> _createWorkspace() async {
    final name = await _promptText(context, title: 'Create workspace', label: 'Name');
    if (name == null || name.trim().isEmpty) return;
    await _run(() async {
      final workspace = await _service.createWorkspace(name.trim());
      await ref.read(authNotifierProvider.notifier).switchWorkspace(workspace.id);
    });
  }

  Future<void> _joinWithInvitation() async {
    final token = await _promptText(context, title: 'Join with invitation', label: 'Invitation token');
    if (token == null || token.trim().isEmpty) return;
    await _run(() async {
      final workspace = await _service.join(token.trim());
      await ref.read(authNotifierProvider.notifier).switchWorkspace(workspace.id);
    });
  }

  /// Leaving the active workspace switches away to another one the caller
  /// still belongs to (a personal workspace always exists and can't be left
  /// while sole-owner, so there's always a fallback); leaving a non-active
  /// one just refreshes the switcher list via the same round-trip.
  Future<void> _leave(int workspaceId) => _run(() async {
    final snapshot = _auth;
    await _service.leave(workspaceId);
    final targetId = workspaceId == snapshot.activeWorkspaceId
        ? snapshot.workspaces.firstWhere((w) => w.id != workspaceId).id
        : snapshot.activeWorkspaceId;
    await ref.read(authNotifierProvider.notifier).switchWorkspace(targetId);
  });

  Future<void> _convertToTeam() => _run(() async {
    final workspaceId = _auth.activeWorkspaceId;
    await _service.convertToTeam(workspaceId);
    // Refreshes AuthState.workspaces/activeWorkspace with the now-team type.
    await ref.read(authNotifierProvider.notifier).switchWorkspace(workspaceId);
  });

  Future<void> _invite() async {
    final email = await _promptText(context, title: 'Invite by email', label: 'Email', keyboardType: TextInputType.emailAddress);
    if (email == null || email.trim().isEmpty) return;
    try {
      final invitation = await _service.createInvitation(_auth.activeWorkspaceId, email: email.trim());
      if (mounted) await _showInvitationToken(invitation);
    } catch (error) {
      if (mounted) setState(() => _error = _messageFor(error));
    }
  }

  Future<void> _showInvitationToken(WorkspaceInvitation invitation) {
    final colors = context.colors;
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Invitation created'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Share this token with ${invitation.email} however you like (Slack, email, ...) — '
                'it expires in 7 days and role-node has no delivery mechanism of its own.',
                style: dialogContext.type.body,
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(color: colors.surfaceSunken, borderRadius: AppRadius.smRadius),
                child: SelectableText(invitation.token, style: dialogContext.type.monoSmall),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Clipboard.setData(ClipboardData(text: invitation.token)),
            child: const Text('Copy'),
          ),
          AppButton(label: 'Done', onPressed: () => Navigator.of(dialogContext).pop()),
        ],
      ),
    );
  }

  Future<void> _updateRole(int memberUserId, String role) => _run(() => _service.updateMemberRole(_auth.activeWorkspaceId, memberUserId, role));

  Future<void> _removeMember(int memberUserId) => _run(() => _service.removeMember(_auth.activeWorkspaceId, memberUserId));

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final auth = ref.watch(authNotifierProvider) as AuthSignedIn;
    final isOwner = auth.activeWorkspace.role == 'owner';
    final isTeam = auth.activeWorkspace.type == 'team';

    return AlertDialog(
      title: const Text('Workspace'),
      content: SizedBox(
        width: 440,
        height: 460,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null) ...[Text(_error!, style: context.type.body.copyWith(color: colors.danger)), const SizedBox(height: AppSpacing.sm)],
              SectionHeader('Your workspaces'),
              for (final workspace in auth.workspaces)
                _WorkspaceRow(
                  workspace: workspace,
                  isActive: workspace.id == auth.activeWorkspaceId,
                  busy: _busy,
                  onSwitch: () => _switchTo(workspace.id),
                  onLeave: workspace.type == 'team' ? () => _leave(workspace.id) : null,
                  // role-node only lets owner/admin run import/export
                  // (IMPORT_EXPORT_RUN_FORBIDDEN for member) — hide rather
                  // than let the request fail.
                  onExport: workspace.role == 'member'
                      ? null
                      : () => runExportRemoteWorkspace(context, ref, workspaceId: workspace.id, workspaceName: workspace.name),
                  onImport: workspace.role == 'member'
                      ? null
                      : () => runImportRemoteWorkspace(context, ref, workspaceId: workspace.id, workspaceName: workspace.name),
                ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  TextButton(onPressed: _busy ? null : _createWorkspace, child: const Text('Create workspace')),
                  TextButton(onPressed: _busy ? null : _joinWithInvitation, child: const Text('Join with invitation')),
                ],
              ),
              const Divider(height: AppSpacing.lg),
              if (isTeam) ...[
                SectionHeader(
                  'Members',
                  trailing: isOwner ? AppIconButton(icon: Icons.person_add_alt_outlined, tooltip: 'Invite by email', onPressed: _invite) : null,
                ),
                FutureBuilder<List<WorkspaceMember>>(
                  future: _membersFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.all(AppSpacing.md),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      );
                    }
                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Text('Could not load members: ${snapshot.error}', style: context.type.body),
                      );
                    }
                    final members = snapshot.data ?? const [];
                    return Column(
                      children: [
                        for (final member in members)
                          _MemberRow(
                            member: member,
                            isSelf: member.userId == auth.user.id,
                            canManage: isOwner,
                            busy: _busy,
                            onRoleChanged: (role) => _updateRole(member.userId, role),
                            onRemove: () => _removeMember(member.userId),
                          ),
                      ],
                    );
                  },
                ),
              ] else if (isOwner) ...[
                SectionHeader('Personal workspace'),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: AppButton(label: 'Convert to team', icon: Icons.groups_outlined, onPressed: _busy ? null : _convertToTeam),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [AppButton(label: 'Close', onPressed: () => Navigator.of(context).pop())],
    );
  }
}

class _WorkspaceRow extends StatelessWidget {
  const _WorkspaceRow({
    required this.workspace,
    required this.isActive,
    required this.busy,
    required this.onSwitch,
    this.onLeave,
    this.onExport,
    this.onImport,
  });

  final RemoteWorkspace workspace;
  final bool isActive;
  final bool busy;
  final VoidCallback onSwitch;
  final VoidCallback? onLeave;
  final VoidCallback? onExport;
  final VoidCallback? onImport;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(isActive ? Icons.radio_button_checked : Icons.radio_button_unchecked, size: 15, color: isActive ? colors.accent : colors.textMuted),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text('${workspace.name} · ${workspace.type} · ${workspace.role}', style: context.type.body, overflow: TextOverflow.ellipsis),
          ),
          if (!isActive) TextButton(onPressed: busy ? null : onSwitch, child: const Text('Switch')),
          if (onExport != null) AppIconButton(icon: Icons.file_download_outlined, tooltip: 'Export this workspace', onPressed: onExport),
          if (onImport != null) AppIconButton(icon: Icons.file_upload_outlined, tooltip: 'Import into this workspace', onPressed: onImport),
          if (onLeave != null) AppIconButton(icon: Icons.exit_to_app, tooltip: 'Leave workspace', onPressed: busy ? null : onLeave),
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.isSelf,
    required this.canManage,
    required this.busy,
    required this.onRoleChanged,
    required this.onRemove,
  });

  final WorkspaceMember member;
  final bool isSelf;
  final bool canManage;
  final bool busy;
  final ValueChanged<String> onRoleChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Owner role is immutable server-side and self-removal is rejected
    // (use Leave instead) — hide the controls the server would reject.
    final canEditThisRow = canManage && !isSelf && member.role != 'owner';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text('${member.name} · ${member.email}', style: context.type.body, overflow: TextOverflow.ellipsis),
          ),
          if (canEditThisRow) ...[
            DropdownButton<String>(
              value: member.role,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: 'member', child: Text('member')),
                DropdownMenuItem(value: 'admin', child: Text('admin')),
              ],
              onChanged: busy ? null : (role) => role == null ? null : onRoleChanged(role),
            ),
            AppIconButton(icon: Icons.person_remove_outlined, tooltip: 'Remove', onPressed: busy ? null : onRemove),
          ] else
            Text(member.role, style: context.type.label.copyWith(color: colors.textMuted)),
        ],
      ),
    );
  }
}

Future<String?> _promptText(BuildContext context, {required String title, required String label, TextInputType? keyboardType}) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 320,
        child: LabeledField(
          label: label,
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            autofocus: true,
            decoration: const InputDecoration(isDense: true),
            onSubmitted: (v) => Navigator.of(context).pop(v),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        AppButton(label: 'OK', variant: AppButtonVariant.primary, onPressed: () => Navigator.of(context).pop(controller.text)),
      ],
    ),
  );
}
