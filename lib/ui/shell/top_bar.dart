import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/remote/auth/auth_state.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/role_theme.dart';
import '../../state/auth_notifier.dart';
import '../../state/environments_notifier.dart';
import '../../state/settings_providers.dart';
import '../../state/workbench_notifier.dart';
import '../auth/sessions_dialog.dart';
import '../auth/sign_in_dialog.dart';
import '../widgets/widgets.dart';
import '../workspace/workspace_dialog.dart';
import 'responsive.dart';
import 'server_settings_dialog.dart';

class TopBar extends ConsumerWidget {
  const TopBar({super.key, this.onImport, this.onExport});

  final VoidCallback? onImport;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final desktop = isDesktop(context);

    return Container(
      height: AppSizes.topBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Icon(Icons.bolt, size: 18, color: colors.accent),
          const SizedBox(width: AppSpacing.xs),
          Text(AppConstants.appName, style: context.type.title),
          const SizedBox(width: AppSpacing.lg),
          if (desktop) ...[Expanded(child: _SearchField()), const SizedBox(width: AppSpacing.lg)] else const Spacer(),
          const EnvironmentSwitcher(),
          const SizedBox(width: AppSpacing.sm),
          AppIconButton(icon: Icons.file_upload_outlined, tooltip: 'Import workspace', onPressed: onImport),
          AppIconButton(icon: Icons.file_download_outlined, tooltip: 'Export workspace', onPressed: onExport),
          const _InspectorToggle(),
          const _ThemeToggle(),
          const _AccountMenu(),
        ],
      ),
    );
  }
}

/// Sign in/out, current workspace, "manage devices" — additive, never a gate
/// in front of the rest of the app. A local-only user who never opens this
/// sees nothing beyond a plain "Sign in" affordance.
class _AccountMenu extends ConsumerWidget {
  const _AccountMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final colors = context.colors;

    if (authState is AuthSigningIn) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (authState is! AuthSignedIn) {
      // No popup shape change once signed in below would be needed if this
      // were still a single icon button jumping straight to sign-in — but
      // that's exactly why "Server settings" (§9) had nowhere to live: you
      // can't sign in before a base URL exists. A local-only user still sees
      // pixel-for-pixel the same icon; only what an explicit click opens differs.
      return PopupMenuButton<String>(
        tooltip: 'Account',
        offset: const Offset(0, 32),
        color: colors.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mdRadius,
          side: BorderSide(color: colors.border),
        ),
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'sign-in', child: Text('Sign in')),
          PopupMenuItem(value: 'server-settings', child: Text('Server settings')),
        ],
        onSelected: (value) {
          switch (value) {
            case 'sign-in':
              showSignInDialog(context);
            case 'server-settings':
              showServerSettingsDialog(context);
          }
        },
        child: const AppIconButton(icon: Icons.account_circle_outlined, tooltip: 'Sign in'),
      );
    }

    return PopupMenuButton<String>(
      tooltip: '${authState.user.name} · ${authState.activeWorkspace.name}',
      offset: const Offset(0, 32),
      color: colors.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.mdRadius,
        side: BorderSide(color: colors.border),
      ),
      itemBuilder: (context) => [
        PopupMenuItem<String>(enabled: false, child: Text(authState.user.email, style: context.type.label)),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'workspace', child: Text('Workspace')),
        const PopupMenuItem(value: 'devices', child: Text('Manage devices')),
        const PopupMenuItem(value: 'server-settings', child: Text('Server settings')),
        const PopupMenuItem(value: 'sign-out', child: Text('Sign out')),
      ],
      onSelected: (value) {
        switch (value) {
          case 'workspace':
            showWorkspaceDialog(context);
          case 'devices':
            showSessionsDialog(context);
          case 'server-settings':
            showServerSettingsDialog(context);
          case 'sign-out':
            ref.read(authNotifierProvider.notifier).logout();
        }
      },
      child: Container(
        height: AppSizes.controlHeightSm + 4,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        decoration: BoxDecoration(
          color: colors.surfaceSunken,
          borderRadius: AppRadius.smRadius,
          border: Border.all(color: colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_circle, size: 14, color: colors.accent),
            const SizedBox(width: AppSpacing.xs),
            Text(authState.activeWorkspace.name, style: context.type.label),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends ConsumerStatefulWidget {
  @override
  ConsumerState<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends ConsumerState<_SearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSizes.controlHeightSm + 4,
      child: TextField(
        controller: _controller,
        style: context.type.body,
        onChanged: (v) => ref.read(workbenchProvider.notifier).setSearchQuery(v),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search requests…',
          prefixIcon: Icon(Icons.search, size: 15, color: context.colors.textMuted),
          prefixIconConstraints: const BoxConstraints(minWidth: 32),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm), borderSide: BorderSide.none),
        ),
      ),
    );
  }
}

/// Sentinel menu value for "No environment". PopupMenuButton can't use a
/// literal `null` item value: it pops the selection via Navigator, and a
/// popped `null` is indistinguishable from the menu being dismissed, so
/// onSelected would never fire for it.
const _noEnvironmentValue = '__no_environment__';

class EnvironmentSwitcher extends ConsumerWidget {
  const EnvironmentSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final environments = ref.watch(environmentsProvider).value ?? const [];
    final activeId = ref.watch(activeEnvironmentIdProvider);
    final active = environments.where((e) => e.id == activeId);

    return PopupMenuButton<String>(
      tooltip: 'Active environment',
      offset: const Offset(0, 32),
      color: colors.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.mdRadius,
        side: BorderSide(color: colors.border),
      ),
      itemBuilder: (context) => [
        const PopupMenuItem(value: _noEnvironmentValue, child: Text('No environment')),
        for (final env in environments) PopupMenuItem(value: env.id, child: Text(env.name)),
      ],
      onSelected: (id) => ref.read(activeEnvironmentIdProvider.notifier).setActiveEnvironment(id == _noEnvironmentValue ? null : id),
      child: Container(
        height: AppSizes.controlHeightSm + 4,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        decoration: BoxDecoration(
          color: colors.surfaceSunken,
          borderRadius: AppRadius.smRadius,
          border: Border.all(color: colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.public, size: 13, color: colors.textMuted),
            const SizedBox(width: AppSpacing.xs),
            Text(active.isEmpty ? 'No environment' : active.first.name, style: context.type.label),
            const SizedBox(width: AppSpacing.xs),
            Icon(Icons.expand_more, size: 14, color: colors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _InspectorToggle extends ConsumerWidget {
  const _InspectorToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(workbenchProvider.select((s) => s.inspectorVisible));
    return AppIconButton(
      icon: visible ? Icons.view_sidebar : Icons.view_sidebar_outlined,
      tooltip: visible ? 'Hide inspector' : 'Show inspector',
      onPressed: () => ref.read(workbenchProvider.notifier).toggleInspector(),
    );
  }
}

class _ThemeToggle extends ConsumerWidget {
  const _ThemeToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return AppIconButton(
      icon: themeModeIcon(mode),
      tooltip: 'Theme: ${mode.name}',
      onPressed: () => ref.read(themeModeProvider.notifier).cycleThemeMode(),
    );
  }
}
