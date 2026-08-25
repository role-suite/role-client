import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/theme/role_theme.dart';
import '../../core/utils/iterable_ext.dart';
import '../../state/auth_notifier.dart';
import '../../state/environments_notifier.dart';
import '../../state/settings_providers.dart';
import '../../state/sync_notifier.dart';
import 'online_mode_panel.dart';

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
          ..._syncIndicator(context, onlineModeStatus(context, auth, sync)),
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
  List<Widget> _syncIndicator(BuildContext context, OnlineModeStatus status) => [
    Icon(status.icon, size: 11, color: status.color),
    const SizedBox(width: 4),
    Text(status.label, style: context.type.caption),
  ];
}
