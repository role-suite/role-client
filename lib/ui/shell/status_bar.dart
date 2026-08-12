import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/theme/role_theme.dart';
import '../../core/utils/iterable_ext.dart';
import '../../state/environments_notifier.dart';
import '../../state/settings_providers.dart';

class StatusBar extends ConsumerWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final activeId = ref.watch(activeEnvironmentIdProvider);
    final environments = ref.watch(environmentsProvider).value ?? const [];
    final activeName = environments.where((e) => e.id == activeId).map((e) => e.name).firstOrNull;

    return Container(
      height: AppSizes.statusBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(color: colors.surface, border: Border(top: BorderSide(color: colors.border))),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 11, color: colors.success),
          const SizedBox(width: 4),
          Text('Local-only', style: context.type.caption),
          const SizedBox(width: AppSpacing.lg),
          Text('Environment: ${activeName ?? 'none'}', style: context.type.caption),
          const Spacer(),
          Text('Röle', style: context.type.caption),
        ],
      ),
    );
  }
}
