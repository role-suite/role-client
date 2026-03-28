import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/core/constants/app_constants.dart';
import 'package:relay/core/constants/data_source_mode.dart';
import 'package:relay/core/models/api_request_model.dart';
import 'package:relay/core/models/collection_model.dart';
import 'package:relay/core/models/environment_model.dart';
import 'package:relay/core/models/workspace_bundle.dart';
import 'package:relay/core/utils/logger.dart';
import 'package:relay/core/utils/uuid.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:relay/features/home/presentation/providers/providers.dart';
import 'package:relay/features/home/presentation/providers/collection_selection_utils.dart';
import 'package:relay/features/home/collection/presentation/widgets/collection_selector.dart';
import 'package:relay/features/home/environment/presentation/widgets/environment_selector.dart';
import 'package:relay/features/home/presentation/widgets/home_drawer.dart';
import 'package:relay/features/home/presentation/widgets/home_empty_state.dart';
import 'package:relay/features/home/request/presentation/widgets/home_requests_list.dart';
import 'package:relay/features/home/collection/presentation/widgets/dialogs/create_collection_dialog.dart';
import 'package:relay/features/home/request/presentation/widgets/dialogs/create_request_dialog.dart';
import 'package:relay/features/home/collection/presentation/widgets/dialogs/delete_collection_dialog.dart';
import 'package:relay/features/home/environment/presentation/widgets/dialogs/delete_environment_dialog.dart';
import 'package:relay/features/home/request/presentation/widgets/dialogs/delete_request_dialog.dart';
import 'package:relay/features/home/environment/presentation/widgets/dialogs/environment_dialog.dart';
import 'package:relay/features/home/presentation/widgets/dialogs/data_source_config_dialog.dart';
import 'package:relay/features/home/presentation/utils/api_auth_flow.dart';
import 'package:relay/features/home/request/presentation/widgets/request_runner_screen.dart';
import 'package:relay/features/home/presentation/providers/update_providers.dart';
import 'package:relay/features/home/presentation/widgets/dialogs/update_dialog.dart';
import 'package:relay/features/request_chain/presentation/request_chain_config_screen.dart';
import 'package:relay/features/collection_runner/presentation/collection_runner_screen.dart';
import '../../../core/presentation/widgets/loading_indicator.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _hasCheckedForUpdates = false;
  String _requestSearchQuery = '';
  static const int _navHttp = 0;
  int _activeTopNav = _navHttp;

  @override
  Widget build(BuildContext context) {
    ref.watch(workspaceUpdatesPollingProvider);

    // Listen for update availability and show dialog
    ref.listen<AsyncValue<dynamic>>(updateAvailableProvider, (previous, next) async {
      if (!_hasCheckedForUpdates && next.hasValue && next.value != null) {
        _hasCheckedForUpdates = true;
        final release = next.value;
        final updateService = ref.read(updateServiceProvider);
        final downloadUrl = updateService.getDownloadUrl(release);
        final currentVersion = await updateService.getCurrentVersion();

        // Show update dialog after the current frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            showUpdateDialog(context: context, release: release, downloadUrl: downloadUrl, currentVersion: currentVersion);
          }
        });
      }
    });

    final selectedCollectionId = ref.watch(selectedCollectionIdProvider);
    final collectionsAsync = ref.watch(collectionsNotifierProvider);
    final dataSourceState = ref.watch(currentDataSourceStateProvider);
    final filteredRequestsAsync = ref.watch(filteredRequestsProvider);
    final environmentsAsync = ref.watch(environmentsNotifierProvider);
    final activeEnvName = ref.watch(activeEnvironmentNameProvider);
    final isMobileLayout = MediaQuery.of(context).size.width < 600;

    final loadedCollections = collectionsAsync.asData?.value;
    if (loadedCollections != null && loadedCollections.isNotEmpty) {
      final preferredId = resolvePreferredCollectionId(
        loadedCollections: loadedCollections,
        selectedCollectionId: selectedCollectionId,
        mode: dataSourceState?.mode ?? DataSourceMode.local,
      );
      if (preferredId != selectedCollectionId) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ref.read(selectedCollectionIdProvider.notifier).select(preferredId);
        });
      }
    }

    final requestBody = filteredRequestsAsync.when(
      data: (filteredRequests) {
        final visibleRequests = filteredRequests.where((request) {
          if (_requestSearchQuery.trim().isEmpty) {
            return true;
          }
          final q = _requestSearchQuery.toLowerCase();
          return request.name.toLowerCase().contains(q) ||
              request.urlTemplate.toLowerCase().contains(q) ||
              request.method.name.toLowerCase().contains(q);
        }).toList();

        if (visibleRequests.isEmpty) {
          return HomeEmptyState(
            onCreateRequest: () => _openCreateRequestDialog(context, selectedCollectionId),
            title: filteredRequests.isEmpty ? 'No Requests Yet' : 'No Results',
            message: filteredRequests.isEmpty
                ? 'Create your first request to start building and testing APIs.'
                : 'Try another search term or clear your filters to see more requests.',
          );
        }

        return HomeRequestsList(
          requests: visibleRequests,
          onTapRequest: (request) => _showRequestDetails(context, ref, request),
          onEditRequest: (request) => _showRequestDetails(context, ref, request, startInEditMode: true),
        );
      },
      loading: () => const LoadingIndicator(message: 'Loading requests...'),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error loading requests: $error'),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => ref.read(requestsNotifierProvider.notifier).refresh(), child: const Text('Retry')),
          ],
        ),
      ),
    );

    final drawer = HomeDrawer(
      onCreateCollection: () => _openCreateCollectionDialog(context),
      onCreateEnvironment: () => _openCreateEnvironmentDialog(context),
      onImportWorkspace: () => _handleImportWorkspace(context, ref),
      onExportWorkspace: () => _handleExportWorkspace(context, ref),
    );

    return Scaffold(
      drawer: isMobileLayout ? drawer : null,
      floatingActionButton: isMobileLayout
          ? FloatingActionButton.extended(
              onPressed: () => _openCreateRequestDialog(context, selectedCollectionId),
              icon: const Icon(Icons.add),
              label: const Text('New Request'),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopToolbar(context, isMobileLayout, collectionsAsync, environmentsAsync, selectedCollectionId, activeEnvName),
            Expanded(
              child: isMobileLayout
                  ? requestBody
                  : Row(
                      children: [
                        _buildWorkspaceSidebar(context, collectionsAsync, environmentsAsync, selectedCollectionId, activeEnvName),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 16, 16),
                            child: Column(
                              children: [
                                _buildRequestListHeader(context, selectedCollectionId),
                                const SizedBox(height: 10),
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.surface,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.8)),
                                    ),
                                    child: requestBody,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopToolbar(
    BuildContext context,
    bool isMobileLayout,
    AsyncValue<List<CollectionModel>> collectionsAsync,
    AsyncValue<List<EnvironmentModel>> environmentsAsync,
    String? selectedCollectionId,
    String? activeEnvName,
  ) {
    final theme = Theme.of(context);
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark ? const Color(0xFF161A20) : const Color(0xFFF7F8FA),
        border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.8))),
      ),
      child: Row(
        children: [
          if (isMobileLayout)
            Builder(
              builder: (context) =>
                  IconButton(icon: const Icon(Icons.menu), tooltip: 'Open menu', onPressed: () => Scaffold.of(context).openDrawer()),
            ),
          const SizedBox(width: 6),
          Text(AppConstants.appName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.2)),
          const SizedBox(width: 12),
          if (!isMobileLayout) ...[
            _topChip(context, Icons.http, 'HTTP', selected: _activeTopNav == _navHttp, onTap: () => setState(() => _activeTopNav = _navHttp)),
            const SizedBox(width: 8),
            _topChip(
              context,
              Icons.play_circle_outline,
              'Runner',
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CollectionRunnerScreen()));
              },
            ),
            const SizedBox(width: 8),
            _topChip(
              context,
              Icons.account_tree_outlined,
              'Flows',
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RequestChainConfigScreen()));
              },
            ),
            const SizedBox(width: 10),
            _topCompactAction(context, icon: Icons.file_download_outlined, label: 'Import', onTap: () => _handleImportWorkspace(context, ref)),
            const SizedBox(width: 6),
            _topCompactAction(context, icon: Icons.file_upload_outlined, label: 'Export', onTap: () => _handleExportWorkspace(context, ref)),
            const SizedBox(width: 6),
            _topCompactAction(context, icon: Icons.add_box_outlined, label: 'Collection', onTap: () => _openCreateCollectionDialog(context)),
            const SizedBox(width: 6),
            _topCompactAction(context, icon: Icons.add_circle_outline, label: 'Environment', onTap: () => _openCreateEnvironmentDialog(context)),
          ],
          const Spacer(),
          if (!isMobileLayout) ...[
            const SizedBox.shrink(),
          ] else ...[
            collectionsAsync.when(
              data: (collections) => CollectionSelector(
                collections: collections,
                selectedCollectionId: selectedCollectionId,
                onSelect: (id) {
                  ref.read(selectedCollectionIdProvider.notifier).select(id);
                },
                onDelete: (collection) => _onDeleteCollection(context, collection),
                iconOnly: true,
              ),
              loading: () => const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
              error: (_, _) => const SizedBox.shrink(),
            ),
            IconButton(tooltip: 'Create collection', onPressed: () => _openCreateCollectionDialog(context), icon: const Icon(Icons.add_box_outlined)),
            const SizedBox(width: 4),
            environmentsAsync.when(
              data: (envs) => EnvironmentSelector(
                envs: envs,
                activeEnvName: activeEnvName,
                onSelect: (name) {
                  if (name != null && name.startsWith('__action__')) {
                    return;
                  }
                  ref.read(activeEnvironmentNameProvider.notifier).setActiveName(name);
                  ref.read(activeEnvironmentNotifierProvider.notifier).setActiveEnvironment(name);
                },
                onEdit: (env) => _openEditEnvironmentDialog(context, env),
                onDelete: (env) => _onDeleteEnvironment(context, env),
                iconOnly: true,
              ),
              loading: () => const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
              error: (_, _) => const SizedBox.shrink(),
            ),
            IconButton(
              tooltip: 'Create environment',
              onPressed: () => _openCreateEnvironmentDialog(context),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ],
      ),
    );
  }

  Widget _topChip(BuildContext context, IconData icon, String label, {required VoidCallback onTap, bool selected = false}) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35) : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? theme.colorScheme.primary.withValues(alpha: 0.6) : theme.colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topCompactAction(BuildContext context, {required IconData icon, required String label, required VoidCallback onTap}) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.9)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(label, style: theme.textTheme.labelSmall),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkspaceSidebar(
    BuildContext context,
    AsyncValue<List<CollectionModel>> collectionsAsync,
    AsyncValue<List<EnvironmentModel>> environmentsAsync,
    String? selectedCollectionId,
    String? activeEnvName,
  ) {
    final theme = Theme.of(context);

    Widget sectionCard({required String title, required Widget child}) {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.9)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            child,
          ],
        ),
      );
    }

    return Container(
      width: 300,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark ? const Color(0xFF101318) : const Color(0xFFFBFCFD),
        border: Border(right: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.8))),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: () => _openCreateRequestDialog(context, selectedCollectionId),
              icon: const Icon(Icons.add),
              label: const Text('New Request'),
            ),
            const SizedBox(height: 10),
            sectionCard(
              title: 'Collection',
              child: collectionsAsync.when(
                data: (collections) => CollectionSelector(
                  collections: collections,
                  selectedCollectionId: selectedCollectionId,
                  onSelect: (id) => ref.read(selectedCollectionIdProvider.notifier).select(id),
                  onDelete: (collection) => _onDeleteCollection(context, collection),
                ),
                loading: () => const SizedBox(height: 36, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                error: (_, _) => Text('Failed to load collections', style: theme.textTheme.bodySmall),
              ),
            ),
            sectionCard(
              title: 'Environment',
              child: environmentsAsync.when(
                data: (envs) => EnvironmentSelector(
                  envs: envs,
                  activeEnvName: activeEnvName,
                  onSelect: (name) {
                    if (name != null && name.startsWith('__action__')) return;
                    ref.read(activeEnvironmentNameProvider.notifier).setActiveName(name);
                    ref.read(activeEnvironmentNotifierProvider.notifier).setActiveEnvironment(name);
                  },
                  onEdit: (env) => _openEditEnvironmentDialog(context, env),
                  onDelete: (env) => _onDeleteEnvironment(context, env),
                ),
                loading: () => const SizedBox(height: 36, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                error: (_, _) => Text('Failed to load environments', style: theme.textTheme.bodySmall),
              ),
            ),
            sectionCard(title: 'Data Source', child: _buildDesktopDataSourceCard(context)),
            sectionCard(title: 'Appearance', child: _buildDesktopThemeCard(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopDataSourceCard(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(dataSourceStateNotifierProvider);

    return state.when(
      loading: () => const SizedBox(height: 36, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      error: (_, _) => Text('Data source unavailable. Using local.', style: theme.textTheme.bodySmall),
      data: (s) {
        final isApi = s.mode == DataSourceMode.api;
        final configValid = s.config.isValid;

        Future<void> switchMode(DataSourceMode mode) async {
          if (mode == DataSourceMode.api && !configValid) {
            if (!context.mounted) return;
            await showDialog<void>(
              context: context,
              builder: (_) => DataSourceConfigDialog(initialConfig: s.config),
            );
            final latest = ref.read(dataSourceStateNotifierProvider).asData?.value;
            if (!(latest?.config.isValid ?? false)) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('API source is not configured. Kept Local mode.')));
              }
              return;
            }
          }

          if (mode == DataSourceMode.api) {
            if (!context.mounted) return;
            final latest = ref.read(dataSourceStateNotifierProvider).asData?.value;
            final currentConfig = latest?.config ?? s.config;
            final isAuthenticated = await ensureApiSourceAuthenticated(context, ref, currentConfig);
            if (!isAuthenticated) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign in required to use API source. Kept Local mode.')));
              }
              return;
            }
          }

          await ref.read(dataSourceStateNotifierProvider.notifier).setMode(mode);
          _invalidateWorkspaceProviders();
          await _resetSelectionAndEnvironment();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(label: const Text('Local'), selected: !isApi, onSelected: (_) => switchMode(DataSourceMode.local)),
                ChoiceChip(label: const Text('API'), selected: isApi, onSelected: (_) => switchMode(DataSourceMode.api)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isApi
                  ? (configValid ? 'Connected to ${_shortUrl(s.config.baseUrl)}' : 'API selected but not configured')
                  : 'Using local workspace storage',
              style: theme.textTheme.bodySmall,
            ),
            if (isApi || !configValid)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => DataSourceConfigDialog(initialConfig: s.config),
                  ),
                  icon: const Icon(Icons.settings, size: 16),
                  label: const Text('Configure'),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildDesktopThemeCard(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final themeMode = ref.watch(themeModeNotifierProvider);
    final isSystemMode = themeMode == ThemeMode.system;
    final isDark = themeMode == ThemeMode.dark || (isSystemMode && mediaQuery.platformBrightness == Brightness.dark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(isDark ? Icons.nightlight_round : Icons.wb_sunny_outlined, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(isSystemMode ? 'System theme' : (isDark ? 'Dark theme' : 'Light theme'), style: theme.textTheme.bodySmall)),
            Switch.adaptive(
              value: isDark,
              onChanged: (value) => ref.read(themeModeNotifierProvider.notifier).setThemeMode(value ? ThemeMode.dark : ThemeMode.light),
            ),
          ],
        ),
        if (!isSystemMode)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => ref.read(themeModeNotifierProvider.notifier).setThemeMode(ThemeMode.system),
              child: const Text('Use system'),
            ),
          ),
      ],
    );
  }

  Widget _buildRequestListHeader(BuildContext context, String? selectedCollectionId) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.8)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: (value) => setState(() => _requestSearchQuery = value),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search requests by name, URL, method...',
                prefixIcon: const Icon(Icons.search, size: 18),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: () => _openCreateRequestDialog(context, selectedCollectionId),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New'),
          ),
        ],
      ),
    );
  }

  // Collection and environment selectors are implemented as separate widgets
  // in `CollectionSelector` and `EnvironmentSelector`.

  void _showRequestDetails(BuildContext context, WidgetRef ref, ApiRequestModel request, {bool startInEditMode = false}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (pageContext) => RequestRunnerPage(
          request: request,
          startInEditMode: startInEditMode,
          onDelete: () {
            Navigator.of(pageContext).pop();
            _onDeleteRequest(context, request);
          },
        ),
      ),
    );
  }

  void _openCreateCollectionDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => const CreateCollectionDialog());
  }

  void _openCreateRequestDialog(BuildContext context, String? collectionId) {
    showDialog(
      context: context,
      builder: (_) => CreateRequestDialog(initialCollectionId: collectionId),
    );
  }

  void _openCreateEnvironmentDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => const CreateEnvironmentDialog());
  }

  void _openEditEnvironmentDialog(BuildContext context, EnvironmentModel environment) {
    showDialog(
      context: context,
      builder: (_) => EditEnvironmentDialog(environment: environment),
    );
  }

  void _onDeleteRequest(BuildContext context, ApiRequestModel request) {
    showDialog(
      context: context,
      builder: (_) => DeleteRequestDialog(request: request),
    );
  }

  void _onDeleteCollection(BuildContext context, CollectionModel collection) {
    if (collection.id == 'default') {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cannot delete the default collection'), backgroundColor: Colors.orange));
      return;
    }

    showDialog(
      context: context,
      builder: (_) => DeleteCollectionDialog(collection: collection),
    );
  }

  void _onDeleteEnvironment(BuildContext context, EnvironmentModel environment) {
    showDialog(
      context: context,
      builder: (_) => DeleteEnvironmentDialog(environment: environment),
    );
  }

  Future<void> _handleExportWorkspace(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    if (kIsWeb) {
      messenger.showSnackBar(const SnackBar(content: Text('Export is not supported on web.')));
      return;
    }

    try {
      final service = ref.read(workspaceImportExportServiceProvider);
      final bundle = await service.buildBundle();
      final json = const JsonEncoder.withIndent('  ').convert(bundle.toJson());
      final defaultFileName = 'relay_workspace_${DateTime.now().millisecondsSinceEpoch}.json';
      Directory? targetDir;
      try {
        targetDir = await getDownloadsDirectory();
      } catch (_) {
        targetDir = null;
      }
      targetDir ??= await getApplicationDocumentsDirectory();
      final filePath = p.join(targetDir.path, defaultFileName);
      await File(filePath).writeAsString(json);
      messenger.showSnackBar(SnackBar(content: Text('Workspace exported to $filePath'), duration: const Duration(seconds: 4)));
    } catch (e) {
      AppLogger.debug(e.toString());
      messenger.showSnackBar(SnackBar(content: Text('Failed to export workspace: $e')));
    }
  }

  Future<void> _handleImportWorkspace(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    if (kIsWeb) {
      messenger.showSnackBar(const SnackBar(content: Text('Import is not supported on web.')));
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: false, // IMPORTANT FIX FOR DESKTOP
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;

      // SAFEST cross-platform read:
      final rawJson = file.path != null ? await File(file.path!).readAsString() : utf8.decode(file.bytes ?? []);

      if (rawJson.isEmpty) {
        throw const FormatException('Selected file is empty.');
      }

      final service = ref.read(workspaceImportExportServiceProvider);
      final bundle = await service.parseImportFile(rawJson);

      await _importBundle(ref, bundle);
      await _refreshData(ref);

      messenger.showSnackBar(
        SnackBar(content: Text('Imported ${bundle.collections.length} collections and ${bundle.environments.length} environments.')),
      );
    } catch (e) {
      AppLogger.debug(e.toString());
      messenger.showSnackBar(SnackBar(content: Text('Failed to import workspace: $e')));
    }
  }

  Future<void> _importBundle(WidgetRef ref, WorkspaceBundle bundle) async {
    final collectionRepository = ref.read(collectionRepositoryProvider);
    final requestRepository = ref.read(requestRepositoryProvider);
    final environmentRepository = ref.read(environmentRepositoryProvider);

    final existingCollections = await collectionRepository.getAllCollections();
    final existingCollectionNames = {for (final collection in existingCollections) collection.name.toLowerCase(): collection};
    final existingEnvironments = await environmentRepository.getAllEnvironments();
    final existingEnvironmentNames = {for (final env in existingEnvironments) env.name.toLowerCase(): env};

    for (final env in bundle.environments) {
      var targetEnv = env;
      final conflict = existingEnvironmentNames[targetEnv.name.toLowerCase()];
      if (conflict != null) {
        final resolution = await _showConflictDialog(
          title: 'Environment conflict',
          message: 'An environment named "${targetEnv.name}" already exists. What would you like to do?',
        );
        if (resolution == ConflictResolution.skip) {
          continue;
        } else if (resolution == ConflictResolution.keepBoth) {
          final uniqueName = _generateUniqueName(targetEnv.name, existingEnvironmentNames.keys);
          targetEnv = targetEnv.copyWith(name: uniqueName);
        }
        // overwrite simply falls through and saves with same name
      }
      await environmentRepository.saveEnvironment(targetEnv);
      existingEnvironmentNames[targetEnv.name.toLowerCase()] = targetEnv;
    }

    for (final bundleCollection in bundle.collections) {
      var targetCollection = bundleCollection.collection;
      final conflict = existingCollectionNames[targetCollection.name.toLowerCase()];

      if (conflict != null) {
        final resolution = await _showConflictDialog(
          title: 'Collection conflict',
          message: 'A collection named "${targetCollection.name}" already exists. What would you like to do?',
        );
        if (resolution == ConflictResolution.skip) {
          continue;
        } else if (resolution == ConflictResolution.keepBoth || (resolution == ConflictResolution.overwrite && conflict.id == 'default')) {
          final uniqueName = _generateUniqueName(targetCollection.name, existingCollectionNames.keys);
          targetCollection = targetCollection.copyWith(
            id: '${targetCollection.id}-${UuidUtils.generate()}',
            name: uniqueName,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
        } else if (resolution == ConflictResolution.overwrite) {
          await collectionRepository.deleteCollection(conflict.id);
        }
      } else {
        targetCollection = targetCollection.copyWith(createdAt: DateTime.now(), updatedAt: DateTime.now());
      }

      await collectionRepository.saveCollection(targetCollection);
      existingCollectionNames[targetCollection.name.toLowerCase()] = targetCollection;

      for (final request in bundleCollection.requests) {
        final normalizedRequest = request.copyWith(
          id: UuidUtils.generate(),
          collectionId: targetCollection.id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await requestRepository.saveRequest(normalizedRequest);
      }
    }
  }

  Future<void> _refreshData(WidgetRef ref) async {
    ref.read(collectionsNotifierProvider.notifier).refresh();
    ref.read(requestsNotifierProvider.notifier).refresh();
    ref.read(environmentsNotifierProvider.notifier).refresh();
  }

  void _invalidateWorkspaceProviders() {
    ref.invalidate(collectionsNotifierProvider);
    ref.invalidate(requestsNotifierProvider);
    ref.invalidate(environmentsNotifierProvider);
    ref.invalidate(activeEnvironmentNotifierProvider);
  }

  Future<void> _resetSelectionAndEnvironment() async {
    ref.read(selectedCollectionIdProvider.notifier).select(null);
    await ref.read(activeEnvironmentNotifierProvider.notifier).setActiveEnvironment(null);
    ref.read(activeEnvironmentNameProvider.notifier).setActiveName(null);
  }

  String _shortUrl(String url) {
    if (url.length <= 40) return url;
    return '${url.substring(0, 20)}...${url.substring(url.length - 15)}';
  }

  String _generateUniqueName(String baseName, Iterable<String> existingNames) {
    final normalized = baseName.trim().isEmpty ? 'Untitled' : baseName.trim();
    final lowerSet = existingNames.map((e) => e.toLowerCase()).toSet();
    var candidate = normalized;
    var index = 2;
    while (lowerSet.contains(candidate.toLowerCase())) {
      candidate = '$normalized ($index)';
      index++;
    }
    return candidate;
  }

  Future<ConflictResolution> _showConflictDialog({required String title, required String message}) async {
    final result = await showDialog<ConflictResolution>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(ConflictResolution.skip), child: const Text('Skip')),
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(ConflictResolution.keepBoth), child: const Text('Keep both')),
            FilledButton(onPressed: () => Navigator.of(dialogContext).pop(ConflictResolution.overwrite), child: const Text('Overwrite')),
          ],
        );
      },
    );
    return result ?? ConflictResolution.skip;
  }
}

enum ConflictResolution { overwrite, keepBoth, skip }
