import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/remote/auth/auth_state.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/role_theme.dart';
import '../../core/utils/iterable_ext.dart';
import '../../state/auth_notifier.dart';
import '../../state/environments_notifier.dart';
import '../../state/settings_providers.dart';
import '../../state/sync_notifier.dart';

class StatusBar extends ConsumerWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final activeId = ref.watch(activeEnvironmentIdProvider);
    final environments = ref.watch(environmentsProvider).value ?? const [];
    final activeName = environments.where((e) => e.id == activeId).map((e) => e.name).firstOrNull;
    final auth = ref.watch(authNotifierProvider);
    final sync = ref.watch(syncNotifierProvider);

    return Container(
      height: AppSizes.statusBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          ..._syncIndicator(context, auth, sync),
          const SizedBox(width: AppSpacing.lg),
          Text('Environment: ${activeName ?? 'none'}', style: context.type.caption),
          const Spacer(),
          Text('Röle', style: context.type.caption),
        ],
      ),
    );
  }

  /// Shows the current mode first: local when signed out, remote when a
  /// role-node workspace is active. Remote mode keeps the sync detail.
  List<Widget> _syncIndicator(BuildContext context, AuthState auth, SyncState sync) {
    final colors = context.colors;
    if (auth is! AuthSignedIn) {
      return [Icon(Icons.lock_outline, size: 11, color: colors.success), const SizedBox(width: 4), Text('Local mode', style: context.type.caption)];
    }

    final (icon, color, label) = switch (sync) {
      SyncIdle() => (Icons.cloud_outlined, colors.textMuted, 'Remote mode'),
      SyncSyncing() => (Icons.sync, colors.textMuted, 'Remote mode · syncing…'),
      SyncSynced(:final lastSyncedAt) => (Icons.cloud_done_outlined, colors.success, 'Remote mode · synced ${_relativeTime(lastSyncedAt)}'),
      SyncOffline() => (Icons.cloud_off_outlined, colors.warning, 'Remote mode · offline, pending sync'),
      SyncError(:final message) => (Icons.error_outline, colors.danger, message),
    };
    return [Icon(icon, size: 11, color: color), const SizedBox(width: 4), Text(label, style: context.type.caption)];
  }

  String _relativeTime(DateTime at) {
    final seconds = DateTime.now().difference(at).inSeconds;
    if (seconds < 5) return 'just now';
    if (seconds < 60) return '${seconds}s ago';
    return '${seconds ~/ 60}m ago';
  }
}
