import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/remote_workspace.dart';
import '../../core/models/workspace_invitation.dart';
import '../../core/models/workspace_member.dart';
import '../../core/remote/auth/auth_state.dart';
import '../../core/remote/remote_validation.dart';
import '../../core/remote/workspace/workspace_service.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/role_theme.dart';
import '../../state/auth_notifier.dart';
import '../remote_error.dart';
import '../widgets/widgets.dart';

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
      if (mounted) setState(() => _error = remoteErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _switchTo(int workspaceId) => _run(() => ref.read(authNotifierProvider.notifier).switchWorkspace(workspaceId));

  Future<void> _createWorkspace() async {
    final name = await _promptText(context, title: 'Create workspace', label: 'Name');
    if (name == null || name.trim().isEmpty) return;
    await _run(() async {
      validateRemoteName('name', name);
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
      if (mounted) setState(() => _error = remoteErrorMessage(error));
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
    final dialogWidth = (MediaQuery.sizeOf(context).width - AppSpacing.xxl).clamp(280.0, 440.0);
    final dialogMaxHeight = (MediaQuery.sizeOf(context).height * 0.78).clamp(360.0, 520.0);

    return AlertDialog(
      title: const Text('Workspace'),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: dialogWidth, maxHeight: dialogMaxHeight),
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
                ),
              const SizedBox(height: AppSpacing.xs),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DialogActionRow(icon: Icons.add_circle_outline, label: 'Create workspace', onTap: _busy ? null : _createWorkspace),
                  _DialogActionRow(icon: Icons.mail_outline, label: 'Join with invitation', onTap: _busy ? null : _joinWithInvitation),
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
                        child: Text('Could not load members: ${remoteErrorMessage(snapshot.error!)}', style: context.type.body),
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
  const _WorkspaceRow({required this.workspace, required this.isActive, required this.busy, required this.onSwitch, this.onLeave});

  final RemoteWorkspace workspace;
  final bool isActive;
  final bool busy;
  final VoidCallback onSwitch;
  final VoidCallback? onLeave;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final actions = [
      if (!isActive) _WorkspaceActionButton(icon: Icons.swap_horiz, label: 'Switch', onTap: busy ? null : onSwitch),
      if (onLeave != null) _WorkspaceActionButton(icon: Icons.exit_to_app, label: 'Leave', onTap: busy ? null : onLeave),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: isActive ? colors.accent.withValues(alpha: 0.08) : colors.surfaceSunken,
          borderRadius: AppRadius.lgRadius,
          border: Border.all(color: isActive ? colors.accent.withValues(alpha: 0.35) : colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isActive ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  size: 17,
                  color: isActive ? colors.accent : colors.textMuted,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(workspace.name, style: context.type.bodyStrong, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text('${workspace.type} · ${workspace.role}', style: context.type.label.copyWith(color: colors.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(spacing: AppSpacing.xs, runSpacing: AppSpacing.xs, children: actions),
            ],
          ],
        ),
      ),
    );
  }
}

class _DialogActionRow extends StatelessWidget {
  const _DialogActionRow({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.mdRadius,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
            child: Row(
              children: [
                Icon(icon, size: 17, color: onTap == null ? colors.textMuted : colors.accent),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(label, style: context.type.bodyStrong.copyWith(color: onTap == null ? colors.textMuted : colors.accent)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkspaceActionButton extends StatelessWidget {
  const _WorkspaceActionButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final disabled = onTap == null;
    return Material(
      color: disabled ? colors.surfaceSunken : colors.surfaceRaised,
      borderRadius: AppRadius.smRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.smRadius,
        child: Container(
          height: AppSizes.controlHeightSm,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: AppRadius.smRadius,
            border: Border.all(color: colors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: disabled ? colors.textMuted : colors.textSecondary),
              const SizedBox(width: AppSpacing.xs),
              Text(label, style: context.type.label.copyWith(color: disabled ? colors.textMuted : colors.textSecondary)),
            ],
          ),
        ),
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
