import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/core/models/workspace_invitation_model.dart';
import 'package:relay/core/models/workspace_member_model.dart';
import 'package:relay/core/presentation/widgets/app_button.dart';
import 'package:relay/core/presentation/widgets/app_text_field.dart';
import 'package:relay/features/home/presentation/providers/data_source_providers.dart';
import 'package:relay/features/home/presentation/providers/workspace_team_providers.dart';
import 'package:flutter/services.dart';
import 'package:relay/features/home/presentation/utils/api_auth_flow.dart';
import 'package:relay/core/utils/error_utils.dart';

class WorkspaceTeamScreen extends ConsumerStatefulWidget {
  const WorkspaceTeamScreen({super.key});

  @override
  ConsumerState<WorkspaceTeamScreen> createState() => _WorkspaceTeamScreenState();
}

class _WorkspaceTeamScreenState extends ConsumerState<WorkspaceTeamScreen> {
  late final TextEditingController _inviteEmailController;
  late final TextEditingController _joinTokenController;
  late final TextEditingController _teamNameController;
  String _inviteRole = 'member';
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _inviteEmailController = TextEditingController();
    _joinTokenController = TextEditingController();
    _teamNameController = TextEditingController();
  }

  @override
  void dispose() {
    _inviteEmailController.dispose();
    _joinTokenController.dispose();
    _teamNameController.dispose();
    super.dispose();
  }

  Future<bool> _ensureAuthenticated() async {
    final state = ref.read(currentDataSourceStateProvider);
    if (state == null || !state.config.isValid) {
      _showSnack('Configure API base URL first.');
      return false;
    }
    if (!mounted) return false;
    final ok = await ensureApiSourceAuthenticated(context, ref, state.config);
    if (!ok) {
      _showSnack('Sign in required to manage team workspace.');
    }
    return ok;
  }

  Future<void> _runAction(Future<void> Function() action, {String? successMessage}) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      await action();
      if (successMessage != null && mounted) {
        _showSnack(successMessage);
      }
    } catch (e) {
      if (mounted) {
        _showSnack(_humanizeError(e), isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _inviteMember() async {
    final email = _inviteEmailController.text.trim();
    if (email.isEmpty) {
      _showSnack('Enter an email to invite.');
      return;
    }
    if (!await _ensureAuthenticated()) return;
    await _runAction(() async {
      final actions = ref.read(workspaceTeamActionsProvider);
      final invitation = await actions.inviteMember(email: email, role: _inviteRole);
      _inviteEmailController.clear();
      if (!mounted) return;
      await _showInvitationDialog(invitation);
    }, successMessage: 'Invitation sent.');
  }

  Future<void> _joinWorkspace() async {
    final token = _joinTokenController.text.trim();
    if (token.isEmpty) {
      _showSnack('Enter an invitation token.');
      return;
    }
    if (!await _ensureAuthenticated()) return;
    await _runAction(() async {
      final actions = ref.read(workspaceTeamActionsProvider);
      await actions.joinWorkspace(token: token);
      _joinTokenController.clear();
    }, successMessage: 'Joined team workspace.');
  }

  Future<void> _convertToTeam() async {
    if (!await _ensureAuthenticated()) return;
    final confirmed = await _confirmDialog(
      title: 'Convert to team workspace',
      message: 'This will enable invitations and multi-user access. Continue?',
      confirmLabel: 'Convert',
    );
    if (!confirmed) return;
    await _runAction(() async {
      final actions = ref.read(workspaceTeamActionsProvider);
      await actions.convertToTeam(teamName: _teamNameController.text.trim());
    }, successMessage: 'Workspace converted to team.');
  }

  Future<void> _leaveWorkspace() async {
    if (!await _ensureAuthenticated()) return;
    final confirmed = await _confirmDialog(
      title: 'Leave team workspace',
      message: 'You will lose access to this workspace unless re-invited.',
      confirmLabel: 'Leave',
      isDestructive: true,
    );
    if (!confirmed) return;
    await _runAction(() async {
      final actions = ref.read(workspaceTeamActionsProvider);
      await actions.leaveWorkspace();
    }, successMessage: 'Left team workspace.');
  }

  Future<void> _updateMemberRole(WorkspaceMemberModel member, String role) async {
    if (!await _ensureAuthenticated()) return;
    await _runAction(() async {
      final actions = ref.read(workspaceTeamActionsProvider);
      await actions.updateMemberRole(memberUserId: member.userId, role: role);
    }, successMessage: 'Role updated.');
  }

  Future<void> _removeMember(WorkspaceMemberModel member) async {
    if (!await _ensureAuthenticated()) return;
    final confirmed = await _confirmDialog(
      title: 'Remove member',
      message: 'Remove ${member.displayName} from the workspace?',
      confirmLabel: 'Remove',
      isDestructive: true,
    );
    if (!confirmed) return;
    await _runAction(() async {
      final actions = ref.read(workspaceTeamActionsProvider);
      await actions.removeMember(memberUserId: member.userId);
    }, successMessage: 'Member removed.');
  }

  Future<void> _showInvitationDialog(WorkspaceInvitationModel invitation) async {
    if (!mounted) return;
    final token = invitation.token.trim();
    final baseUrl = ref.read(currentDataSourceStateProvider)?.config.baseUrl ?? '';
    final normalizedBase = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final inviteLink = token.isEmpty ? '' : (normalizedBase.isEmpty ? '/invite?token=$token' : '$normalizedBase/invite?token=$token');
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Invitation created'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Invite sent to ${invitation.email}.', style: Theme.of(context).textTheme.bodyMedium),
              if (token.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Invitation token', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                SelectableText(token, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 10),
                Text('Invite link', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                SelectableText(inviteLink, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: inviteLink));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invite link copied.')));
                      }
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy invite link'),
                  ),
                ),
              ],
            ],
          ),
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done'))],
        );
      },
    );
  }

  Future<bool> _confirmDialog({required String title, required String message, required String confirmLabel, bool isDestructive = false}) async {
    if (!mounted) return false;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: isDestructive ? Theme.of(context).colorScheme.error : null),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showSnack(String message, {bool isError = false}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(content: Text(message), backgroundColor: isError ? Theme.of(context).colorScheme.error : null));
  }

  String _humanizeError(Object error) {
    return humanizeApiError(error);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final workspaceIdAsync = ref.watch(currentWorkspaceIdProvider);
    final membersAsync = ref.watch(workspaceMembersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Team workspace'),
        actions: [
          IconButton(
            onPressed: _isBusy
                ? null
                : () {
                    ref.invalidate(workspaceMembersProvider);
                    ref.invalidate(currentWorkspaceIdProvider);
                  },
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colorScheme.surfaceContainerHighest.withValues(alpha: 0.35), colorScheme.surface],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              _PageHero(
                title: 'Team Workspace',
                subtitle: 'Invite teammates, manage roles, and keep access under control.',
                status: workspaceIdAsync.when(
                  data: (workspaceId) => workspaceId == null ? 'Not connected' : 'Connected',
                  loading: () => 'Loading',
                  error: (_, _) => 'Connection issue',
                ),
              ),
              const SizedBox(height: 14),
              _SectionCard(
                icon: Icons.badge_outlined,
                title: 'Workspace details',
                subtitle: 'Current team workspace state',
                child: workspaceIdAsync.when(
                  data: (workspaceId) => Text(
                    workspaceId == null ? 'Connect to API to load workspace.' : 'Workspace ID: $workspaceId',
                    style: theme.textTheme.bodyMedium,
                  ),
                  loading: () => const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  error: (error, _) => Text(_humanizeError(error), style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.error)),
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                icon: Icons.group_add_outlined,
                title: 'Join a team',
                subtitle: 'Use an invitation token to join',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppTextField(controller: _joinTokenController, label: 'Invitation token', hint: 'Paste token'),
                    const SizedBox(height: 12),
                    AppButton(
                      label: _isBusy ? 'Joining...' : 'Join workspace',
                      icon: Icons.group_add_outlined,
                      isFullWidth: true,
                      onPressed: _isBusy ? null : _joinWorkspace,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                icon: Icons.outgoing_mail,
                title: 'Invite members',
                subtitle: 'Send role-based invitations',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppTextField(
                      controller: _inviteEmailController,
                      label: 'Email address',
                      hint: 'teammate@example.com',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: ValueKey(_inviteRole),
                      initialValue: _inviteRole,
                      items: const [
                        DropdownMenuItem(value: 'member', child: Text('Member')),
                        DropdownMenuItem(value: 'admin', child: Text('Admin')),
                      ],
                      decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
                      onChanged: _isBusy
                          ? null
                          : (value) {
                              if (value == null) return;
                              setState(() => _inviteRole = value);
                            },
                    ),
                    const SizedBox(height: 12),
                    AppButton(
                      label: _isBusy ? 'Sending...' : 'Send invite',
                      icon: Icons.mail_outline,
                      isFullWidth: true,
                      onPressed: _isBusy ? null : _inviteMember,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                icon: Icons.upgrade_outlined,
                title: 'Convert to team',
                subtitle: 'Enable collaboration for this workspace',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppTextField(controller: _teamNameController, label: 'Team name (optional)', hint: 'Platform Team'),
                    const SizedBox(height: 12),
                    AppButton(
                      label: _isBusy ? 'Converting...' : 'Convert workspace',
                      icon: Icons.upgrade,
                      isFullWidth: true,
                      onPressed: _isBusy ? null : _convertToTeam,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                icon: Icons.people_outline,
                title: 'Members',
                subtitle: 'Manage access and workspace roles',
                child: membersAsync.when(
                  data: (members) {
                    if (members.isEmpty) {
                      return Text('No members yet.', style: theme.textTheme.bodyMedium);
                    }
                    return Column(
                      children: members
                          .map(
                            (member) => _MemberTile(
                              member: member,
                              onSelected: (value) {
                                if (value == 'remove') {
                                  _removeMember(member);
                                } else if (value == 'admin' || value == 'member') {
                                  _updateMemberRole(member, value);
                                }
                              },
                            ),
                          )
                          .toList(),
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  error: (error, _) => Text(_humanizeError(error), style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.error)),
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                icon: Icons.exit_to_app,
                title: 'Leave workspace',
                subtitle: 'Return to your personal workspace',
                isDanger: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Leave the current team workspace and return to your personal workspace.', style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 12),
                    AppButton(
                      label: _isBusy ? 'Leaving...' : 'Leave team',
                      icon: Icons.exit_to_app,
                      variant: AppButtonVariant.danger,
                      isFullWidth: true,
                      onPressed: _isBusy ? null : _leaveWorkspace,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageHero extends StatelessWidget {
  const _PageHero({required this.title, required this.subtitle, required this.status});

  final String title;
  final String subtitle;
  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(colors: [colorScheme.primary.withValues(alpha: 0.16), colorScheme.tertiary.withValues(alpha: 0.18)]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.workspaces_outline, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          Chip(avatar: const Icon(Icons.circle, size: 10), label: Text(status), visualDensity: VisualDensity.compact),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.icon, required this.title, required this.subtitle, required this.child, this.isDanger = false});

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = isDanger ? colorScheme.error : colorScheme.primary;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: accent.withValues(alpha: 0.14)),
                  child: Icon(icon, size: 18, color: accent),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member, required this.onSelected});

  final WorkspaceMemberModel member;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final role = member.role.toLowerCase();
    final roleColor = role == 'admin' ? Theme.of(context).colorScheme.tertiary : Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          const CircleAvatar(radius: 15, child: Icon(Icons.person_outline, size: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  member.email.isEmpty ? member.userId : member.email,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Chip(
            label: Text(role),
            labelStyle: TextStyle(color: roleColor, fontWeight: FontWeight.w600),
            side: BorderSide(color: roleColor.withValues(alpha: 0.35)),
            visualDensity: VisualDensity.compact,
          ),
          if (member.userId.isNotEmpty)
            PopupMenuButton<String>(
              onSelected: onSelected,
              itemBuilder: (context) => [
                if (member.role != 'admin') const PopupMenuItem(value: 'admin', child: Text('Make admin')),
                if (member.role != 'member') const PopupMenuItem(value: 'member', child: Text('Make member')),
                const PopupMenuItem(value: 'remove', child: Text('Remove')),
              ],
            ),
        ],
      ),
    );
  }
}
