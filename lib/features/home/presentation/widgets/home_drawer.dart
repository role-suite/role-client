import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/core/constants/app_constants.dart';
import 'package:relay/features/collection_runner/presentation/collection_run_history_screen.dart';
import 'package:relay/features/collection_runner/presentation/collection_runner_screen.dart';
import 'package:relay/features/home/presentation/providers/theme_providers.dart';

class HomeDrawer extends ConsumerWidget {
  const HomeDrawer({
    super.key,
    required this.onCreateCollection,
    required this.onCreateEnvironment,
    required this.onImportWorkspace,
    required this.onExportWorkspace,
  });

  final VoidCallback onCreateCollection;
  final VoidCallback onCreateEnvironment;
  final Future<void> Function() onImportWorkspace;
  final Future<void> Function() onExportWorkspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final themeMode = ref.watch(themeModeNotifierProvider);
    final isSystemMode = themeMode == ThemeMode.system;
    final bool isSystemDark = mediaQuery.platformBrightness == Brightness.dark;
    final bool isDarkMode = themeMode == ThemeMode.dark || (isSystemMode && isSystemDark);

    void updateThemeMode(ThemeMode mode) {
      ref.read(themeModeNotifierProvider.notifier).setThemeMode(mode);
    }

    final themeSubtitle = isSystemMode
        ? 'Following system theme (${isSystemDark ? 'Dark' : 'Light'})'
        : isDarkMode
        ? 'Dark mode is on'
        : 'Light mode is on';

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: theme.colorScheme.primaryContainer),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    AppConstants.appName,
                    style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Quick actions',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8)),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add_box_outlined),
              title: const Text('Create New Collection'),
              subtitle: const Text('Group and share related requests'),
              onTap: () {
                Navigator.of(context).pop();
                onCreateCollection();
              },
            ),
            const Divider(height: 0),
            ListTile(
              leading: const Icon(Icons.cloud_outlined),
              title: const Text('Create New Environment'),
              subtitle: const Text('Store URLs, secrets, and configs'),
              onTap: () {
                Navigator.of(context).pop();
                onCreateEnvironment();
              },
            ),
            const Divider(height: 0),
            ListTile(
              leading: const Icon(Icons.file_download_outlined),
              title: const Text('Import JSON'),
              subtitle: const Text('Relay or Postman exports'),
              onTap: () async {
                Navigator.of(context).pop();
                await onImportWorkspace();
              },
            ),
            ListTile(
              leading: const Icon(Icons.file_upload_outlined),
              title: const Text('Export Workspace'),
              subtitle: const Text('Collections & environments'),
              onTap: () async {
                Navigator.of(context).pop();
                await onExportWorkspace();
              },
            ),
            const Divider(height: 0),
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: const Text('Collection Runner'),
              subtitle: const Text('Run collections sequentially'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(builder: (context) => const CollectionRunnerScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Test Run History'),
              subtitle: const Text('View previous collection test runs'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(builder: (context) => const CollectionRunHistoryScreen()));
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(isDarkMode ? Icons.nightlight_round : Icons.wb_sunny_outlined, color: theme.colorScheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Appearance', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(themeSubtitle, style: theme.textTheme.bodySmall),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: isDarkMode,
                          onChanged: (value) => updateThemeMode(value ? ThemeMode.dark : ThemeMode.light),
                          activeThumbColor: theme.colorScheme.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Toggle to quickly switch between light and dark themes.', style: theme.textTheme.bodySmall),
                    if (!isSystemMode)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(onPressed: () => updateThemeMode(ThemeMode.system), child: const Text('Use system')),
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
