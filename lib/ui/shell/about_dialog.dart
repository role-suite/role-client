import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/theme/role_theme.dart';
import '../../core/utils/date_format.dart';
import '../../state/update_notifier.dart';
import '../widgets/widgets.dart';

/// Version info and the manual/opt-in release check. Reachable from the
/// account menu for both signed-in and local-only users.
Future<void> showAppAboutDialog(BuildContext context) {
  return showDialog<void>(context: context, builder: (context) => const _AboutDialog());
}

class _AboutDialog extends ConsumerWidget {
  const _AboutDialog();

  Future<void> _openRelease(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the release page.')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final update = ref.watch(updateNotifierProvider).value;
    final notifier = ref.read(updateNotifierProvider.notifier);

    return AlertDialog(
      title: const Text('About Röle'),
      content: SizedBox(
        width: 400,
        child: update == null
            ? const Text('Loading…')
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Image.asset('assets/image/app_logo.png', width: 40, height: 40),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Röle', style: context.type.bodyStrong),
                            Text('Version ${update.displayVersion}', style: context.type.caption),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'A local-first API testing client. Röle checks for updates against GitHub Releases only when you ask, '
                    'or daily if you enable it below.',
                    style: context.type.body,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(child: Text('Check for updates automatically (daily)', style: context.type.body)),
                      Switch(value: update.autoCheckEnabled, onChanged: update.versionKnown ? (value) => notifier.setAutoCheck(value) : null),
                    ],
                  ),
                  if (!update.versionKnown) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text('Version information is unavailable, so update checks are disabled.', style: context.type.caption),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  _StatusBlock(update: update, onOpenRelease: (url) => _openRelease(context, url), onDismiss: notifier.dismissUpdate),
                ],
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
        AppButton(
          label: update?.isChecking ?? false ? 'Checking…' : 'Check for updates',
          variant: AppButtonVariant.primary,
          onPressed: update == null || update.isChecking || !update.versionKnown ? null : notifier.checkForUpdates,
        ),
      ],
    );
  }
}

class _StatusBlock extends StatelessWidget {
  const _StatusBlock({required this.update, required this.onOpenRelease, required this.onDismiss});

  final UpdateState update;
  final void Function(String url) onOpenRelease;
  final Future<void> Function() onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final lastChecked = update.lastCheckedAt;
    final checkedLabel = lastChecked == null ? 'Never checked.' : 'Last checked ${formatDateTime(lastChecked)}.';

    if (update.isChecking) {
      return Row(
        children: [
          const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: AppSpacing.sm),
          Text('Checking…', style: context.type.caption),
        ],
      );
    }

    final error = update.errorMessage;
    if (error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(error, style: context.type.body.copyWith(color: colors.danger)),
          Text(checkedLabel, style: context.type.caption),
        ],
      );
    }

    if (update.updateAvailable) {
      final url = update.availableUrl;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Update available: ${update.availableTag}', style: context.type.bodyStrong.copyWith(color: colors.accent)),
          Text('You are on ${update.displayVersion}.', style: context.type.caption),
          if (url != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                AppButton(
                  label: 'Open release page',
                  icon: Icons.open_in_new,
                  variant: AppButtonVariant.secondary,
                  dense: true,
                  onPressed: () => onOpenRelease(url),
                ),
                const SizedBox(width: AppSpacing.sm),
                if (update.showBadge) TextButton(onPressed: onDismiss, child: const Text('Dismiss')),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Text(checkedLabel, style: context.type.caption),
        ],
      );
    }

    if (update.latest != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("You're on the latest version.", style: context.type.body.copyWith(color: colors.success)),
          Text(checkedLabel, style: context.type.caption),
        ],
      );
    }

    return Text(checkedLabel, style: context.type.caption);
  }
}
