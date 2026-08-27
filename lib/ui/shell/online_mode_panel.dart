import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/remote/auth/auth_state.dart';
import '../../core/remote/workspace_permissions.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/role_theme.dart';
import '../../state/auth_notifier.dart';
import '../../state/settings_providers.dart';
import '../../state/sync_notifier.dart';
import '../auth/sessions_dialog.dart';
import '../auth/sign_in_dialog.dart';
import '../widgets/widgets.dart';
import '../workspace/workspace_dialog.dart';
import 'server_settings_dialog.dart';

class OnlineModePanel extends ConsumerWidget {
  const OnlineModePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final auth = ref.watch(authNotifierProvider);
    final sync = ref.watch(syncNotifierProvider);
    final baseUrl = ref.watch(remoteBaseUrlProvider);
    final status = onlineModeStatus(context, auth, sync);
    final lastSyncedAt = syncLastSyncedAt(sync);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        _StatusCard(status: status),
        const SizedBox(height: AppSpacing.md),
        _PanelSection(
          title: 'Server',
          children: [
            _InfoRow(icon: Icons.dns_outlined, title: 'Server URL', subtitle: baseUrl ?? 'No server configured'),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: baseUrl == null ? 'Configure server' : 'Server settings',
              icon: Icons.settings_outlined,
              onPressed: () => showServerSettingsDialog(context),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _PanelSection(
          title: 'Account',
          children: [
            if (auth is AuthSignedIn) ...[
              _InfoRow(icon: Icons.account_circle_outlined, title: auth.user.name, subtitle: auth.user.email),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  AppButton(label: 'Workspace', icon: Icons.groups_outlined, onPressed: () => showWorkspaceDialog(context)),
                  AppButton(label: 'Manage devices', icon: Icons.devices_outlined, onPressed: () => showSessionsDialog(context)),
                  AppButton(
                    label: 'Sign out',
                    icon: Icons.logout,
                    variant: AppButtonVariant.danger,
                    onPressed: () => ref.read(authNotifierProvider.notifier).logout(),
                  ),
                ],
              ),
            ] else ...[
              Text('Sign in to enable remote workspaces and sync.', style: context.type.body.copyWith(color: colors.textSecondary)),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Sign in / Create account',
                icon: Icons.login,
                variant: AppButtonVariant.primary,
                onPressed: () => showSignInDialog(context),
              ),
            ],
          ],
        ),
        if (auth is AuthSignedIn) ...[
          const SizedBox(height: AppSpacing.md),
          _PanelSection(
            title: 'Active workspace',
            children: [
              _InfoRow(
                icon: Icons.workspaces_outline,
                title: auth.activeWorkspace.name,
                subtitle: '${auth.activeWorkspace.type} · ${auth.activeWorkspace.role}',
              ),
              const SizedBox(height: AppSpacing.sm),
              _InfoRow(
                icon: canWriteRemoteWorkspaceRole(auth.activeWorkspace.role) ? Icons.edit_outlined : Icons.visibility_outlined,
                title: 'Access',
                subtitle: canWriteRemoteWorkspaceRole(auth.activeWorkspace.role)
                    ? 'Can modify remote workspace'
                    : 'Read-only: owners and admins can modify',
              ),
              const SizedBox(height: AppSpacing.sm),
              _InfoRow(
                icon: Icons.schedule_outlined,
                title: 'Last sync',
                subtitle: lastSyncedAt == null ? 'Not synced yet' : _relativeTime(lastSyncedAt),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class OnlineModeStatus {
  const OnlineModeStatus({required this.icon, required this.color, required this.label});

  final IconData icon;
  final Color color;
  final String label;
}

OnlineModeStatus onlineModeStatus(BuildContext context, AuthState auth, SyncState sync) {
  final colors = context.colors;
  if (auth is! AuthSignedIn) {
    return OnlineModeStatus(icon: Icons.lock_outline, color: colors.success, label: 'Local mode');
  }

  return switch (sync) {
    SyncIdle() => OnlineModeStatus(icon: Icons.cloud_outlined, color: colors.textMuted, label: 'Remote mode'),
    SyncSyncing() => OnlineModeStatus(icon: Icons.sync, color: colors.textMuted, label: 'Remote mode · syncing...'),
    SyncSynced(:final lastSyncedAt) => OnlineModeStatus(
      icon: Icons.cloud_done_outlined,
      color: colors.success,
      label: 'Remote mode · synced ${_relativeTime(lastSyncedAt)}',
    ),
    SyncOffline() => OnlineModeStatus(icon: Icons.cloud_off_outlined, color: colors.warning, label: 'Remote mode · offline, pending sync'),
    SyncError(:final message) => OnlineModeStatus(icon: Icons.error_outline, color: colors.danger, label: message),
  };
}

DateTime? syncLastSyncedAt(SyncState sync) {
  return switch (sync) {
    SyncSynced(:final lastSyncedAt) => lastSyncedAt,
    SyncOffline(:final lastSyncedAt) => lastSyncedAt,
    _ => null,
  };
}

String _relativeTime(DateTime at) {
  final seconds = DateTime.now().difference(at).inSeconds;
  if (seconds < 5) return 'just now';
  if (seconds < 60) return '${seconds}s ago';
  return '${seconds ~/ 60}m ago';
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status});

  final OnlineModeStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: AppRadius.lgRadius,
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(status.icon, size: 24, color: status.color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Online mode', style: context.type.title),
                const SizedBox(height: AppSpacing.xs),
                Text(status.label, style: context.type.body.copyWith(color: colors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelSection extends StatelessWidget {
  const _PanelSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.lgRadius,
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: context.type.sectionHeader),
          const SizedBox(height: AppSpacing.sm),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: colors.textSecondary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.type.bodyStrong, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: context.type.label.copyWith(color: colors.textMuted),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
