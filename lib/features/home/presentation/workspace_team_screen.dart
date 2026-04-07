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
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Workspace details', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    workspaceIdAsync.when(
                      data: (workspaceId) => Text(
                        workspaceId == null ? 'Connect to API to load workspace.' : 'Workspace ID: $workspaceId',
                        style: theme.textTheme.bodySmall,
                      ),
                      loading: () => const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                      error: (error, _) => Text(_humanizeError(error), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Join a team', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
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
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Invite members', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    AppTextField(
                      controller: _inviteEmailController,
                      label: 'Email address',
                      hint: 'teammate@example.com',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _inviteRole,
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
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Convert to team', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
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
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Members', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    membersAsync.when(
                      data: (members) {
                        if (members.isEmpty) {
                          return Text('No members yet.', style: theme.textTheme.bodySmall);
                        }
                        return Column(
                          children: members
                              .map(
                                (member) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.person_outline),
                                  title: Text(member.displayName),
                                  subtitle: Text('${member.email.isEmpty ? member.userId : member.email} • ${member.role}'),
                                  trailing: member.userId.isEmpty
                                      ? null
                                      : PopupMenuButton<String>(
                                          onSelected: (value) {
                                            if (value == 'remove') {
                                              _removeMember(member);
                                            } else if (value == 'admin' || value == 'member') {
                                              _updateMemberRole(member, value);
                                            }
                                          },
                                          itemBuilder: (context) => [
                                            if (member.role != 'admin') const PopupMenuItem(value: 'admin', child: Text('Make admin')),
                                            if (member.role != 'member') const PopupMenuItem(value: 'member', child: Text('Make member')),
                                            const PopupMenuItem(value: 'remove', child: Text('Remove')),
                                          ],
                                        ),
                                ),
                              )
                              .toList(),
                        );
                      },
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      error: (error, _) => Text(_humanizeError(error), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Leave workspace', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text('Leave the current team workspace and return to your personal workspace.', style: theme.textTheme.bodySmall),
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
            ),
          ],
        ),
      ),
    );
  }
}
