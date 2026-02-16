import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/core/constants/api_style.dart';
import 'package:relay/core/constants/app_constants.dart';
import 'package:relay/core/constants/data_source_mode.dart';
import 'package:relay/core/models/data_source_config.dart';
import 'package:relay/core/services/data_source_preferences_service.dart';
import 'package:relay/core/services/relay_api/serverpod_client_provider.dart';
import 'package:relay/core/services/sync_to_remote_service.dart';
import 'package:relay_server_client/relay_server_client.dart';
import 'package:relay/features/collection_runner/presentation/collection_run_history_screen.dart';
import 'package:relay/features/collection_runner/presentation/collection_runner_screen.dart';
import 'package:relay/features/request_chain/presentation/request_chain_config_screen.dart';
import 'package:relay/features/home/presentation/providers/providers.dart';
import 'package:relay/features/home/presentation/widgets/dialogs/data_source_config_dialog.dart';
import 'package:relay/features/auth/presentation/sign_in_screen.dart';

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
              leading: const Icon(Icons.link),
              title: const Text('Request Chain'),
              subtitle: const Text('Chain requests with delays and response passing'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(builder: (context) => const RequestChainConfigScreen()));
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
            const Divider(height: 0),
            _DataSourceSection(ref: ref),
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

class _DataSourceSection extends ConsumerWidget {
  const _DataSourceSection({required this.ref});

  final WidgetRef ref;

  void _invalidateWorkspaceProviders() {
    ref.invalidate(collectionsNotifierProvider);
    ref.invalidate(requestsNotifierProvider);
    ref.invalidate(environmentsNotifierProvider);
    ref.invalidate(activeEnvironmentNotifierProvider);
  }

  Future<void> _resetSelectionAndEnvironment(WidgetRef r) async {
    r.read(selectedCollectionIdProvider.notifier).state = 'default';
    await r.read(activeEnvironmentNotifierProvider.notifier).setActiveEnvironment(null);
    r.read(activeEnvironmentNameProvider.notifier).state = null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(dataSourceStateNotifierProvider);

    return state.when(
      loading: () => const ListTile(
        leading: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
        title: Text('Data source'),
      ),
      error: (error, stackTrace) => ListTile(
        leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
        title: const Text('Data source'),
        subtitle: const Text('Using local storage'),
      ),
      data: (s) {
        final isApi = s.mode == DataSourceMode.api;
        final configValid = s.config.isValid;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
                Text('Data source', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(
                  'Choose where to load collections and environments from.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilterChip(
                        label: const Text('Local'),
                        selected: !isApi,
                        onSelected: (_) async {
                          if (isApi) {
                            await ref.read(dataSourceStateNotifierProvider.notifier).setMode(DataSourceMode.local);
                            _invalidateWorkspaceProviders();
                            await _resetSelectionAndEnvironment(ref);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilterChip(
                        label: const Text('API'),
                        selected: isApi,
                        onSelected: (_) async {
                          if (!isApi) {
                            await ref.read(dataSourceStateNotifierProvider.notifier).setMode(DataSourceMode.api);
                            if (!configValid) {
                              if (context.mounted) {
                                await showDialog<void>(
                                  context: context,
                                  builder: (_) => DataSourceConfigDialog(initialConfig: s.config),
                                );
                              }
                            }
                            _invalidateWorkspaceProviders();
                            await _resetSelectionAndEnvironment(ref);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                if (isApi) ...[
                  const SizedBox(height: 12),
                  Text(
                    configValid
                        ? 'Base URL: ${_shortUrl(s.config.baseUrl)}'
                        : 'Set base URL to load workspace from API.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: () async {
                      await showDialog<void>(
                        context: context,
                        builder: (_) => DataSourceConfigDialog(initialConfig: s.config),
                      );
                      _invalidateWorkspaceProviders();
                    },
                    icon: const Icon(Icons.settings, size: 18),
                    label: Text(configValid ? 'Change API URL' : 'Configure API'),
                  ),
                  if (s.config.apiStyle == ApiStyle.serverpod) ...[
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => const SignInScreen()),
                        );
                      },
                      icon: const Icon(Icons.login, size: 18),
                      label: const Text('Sign in'),
                    ),
                  ],
                ],
                if (!isApi) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Push your local collections and environments to a remote server.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  FilledButton.tonalIcon(
                    onPressed: () => _onSyncToRemote(context, ref),
                    icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                    label: const Text('Sync to remote'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _onSyncToRemote(BuildContext context, WidgetRef ref) async {
    var config = await DataSourcePreferencesService.loadConfig();
    if (!config.isValid && context.mounted) {
      final result = await showDialog<DataSourceConfig?>(
        context: context,
        builder: (_) => DataSourceConfigDialog(initialConfig: config),
      );
      if (result == null || !context.mounted) return;
      config = result;
    } else if (!config.isValid) {
      return;
    }
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Client? serverpodClient;
    if (config.apiStyle == ApiStyle.serverpod && config.baseUrl.trim().isNotEmpty) {
      serverpodClient = await ref.read(serverpodClientProvider(config.baseUrl).future);
    }
    try {
      await SyncToRemoteService.sync(
        config: config,
        collectionRepository: ref.read(collectionRepositoryProvider),
        environmentRepository: ref.read(environmentRepositoryProvider),
        requestRepository: ref.read(requestRepositoryProvider),
        serverpodClient: serverpodClient,
      );
      if (context.mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Synced local data to remote.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  static String _shortUrl(String url) {
    if (url.length <= 40) return url;
    return '${url.substring(0, 20)}…${url.substring(url.length - 15)}';
  }
}
