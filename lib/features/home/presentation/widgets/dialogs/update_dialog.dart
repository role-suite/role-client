import 'package:flutter/material.dart';
import 'package:relay/core/constants/app_constants.dart';
import 'package:relay/core/models/app_release_model.dart';
import 'package:url_launcher/url_launcher.dart';

/// Dialog that shows when an app update is available.
/// Displays version info, release notes, and download options.
class UpdateDialog extends StatelessWidget {
  const UpdateDialog({
    super.key,
    required this.release,
    required this.downloadUrl,
  });

  final AppReleaseModel release;
  final String downloadUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.system_update,
              color: colorScheme.onPrimaryContainer,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Update Available'),
                Text(
                  'v${release.version}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 400,
          maxHeight: 300,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Version comparison
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _VersionChip(
                    label: 'Current',
                    version: AppConstants.appVersion,
                    isOld: true,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(
                      Icons.arrow_forward,
                      color: colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  _VersionChip(
                    label: 'Latest',
                    version: release.version,
                    isOld: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Release notes
            if (release.releaseNotes != null &&
                release.releaseNotes!.isNotEmpty) ...[
              Text(
                'What\'s New',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      release.releaseNotes!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],

            // Published date
            if (release.publishedAt != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Released ${_formatDate(release.publishedAt!)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Remind Me Later'),
        ),
        FilledButton.icon(
          onPressed: () => _openDownloadUrl(context),
          icon: const Icon(Icons.download, size: 18),
          label: const Text('Download Update'),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<void> _openDownloadUrl(BuildContext context) async {
    final uri = Uri.parse(downloadUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open: $downloadUrl'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening URL: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}

class _VersionChip extends StatelessWidget {
  const _VersionChip({
    required this.label,
    required this.version,
    required this.isOld,
  });

  final String label;
  final String version;
  final bool isOld;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isOld
                ? colorScheme.surfaceContainerHighest
                : colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isOld
                  ? colorScheme.outline.withOpacity(0.3)
                  : colorScheme.primary.withOpacity(0.5),
            ),
          ),
          child: Text(
            'v$version',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: isOld
                  ? colorScheme.onSurfaceVariant
                  : colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// Show the update dialog.
/// Returns a Future that completes when the dialog is dismissed.
Future<void> showUpdateDialog({
  required BuildContext context,
  required AppReleaseModel release,
  required String downloadUrl,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => UpdateDialog(
      release: release,
      downloadUrl: downloadUrl,
    ),
  );
}
