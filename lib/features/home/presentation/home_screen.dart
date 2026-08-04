import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/core/constants/app_constants.dart';
import 'package:relay/core/presentation/shell/role_inspector.dart';
import 'package:relay/core/presentation/shell/role_left_rail.dart';
import 'package:relay/core/presentation/shell/role_shell.dart';
import 'package:relay/core/presentation/shell/role_sidebar_panel.dart';
import 'package:relay/core/presentation/shell/role_status_bar.dart';
import 'package:relay/core/presentation/shell/role_top_bar.dart';
import 'package:relay/core/presentation/shell/role_workbench.dart';
import 'package:relay/core/presentation/layout/responsive_layout.dart';
import 'package:relay/core/models/api_request_model.dart';
import 'package:relay/core/models/collection_model.dart';
import 'package:relay/core/models/environment_model.dart';
import 'package:relay/core/models/workspace_bundle.dart';
import 'package:relay/core/presentation/widgets/widgets.dart';
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
import 'package:relay/features/home/request/presentation/widgets/home_requests_view.dart';
import 'package:relay/features/home/collection/presentation/widgets/dialogs/create_collection_dialog.dart';
import 'package:relay/features/home/request/presentation/widgets/dialogs/create_request_dialog.dart';
import 'package:relay/features/home/collection/presentation/widgets/dialogs/delete_collection_dialog.dart';
import 'package:relay/features/home/environment/presentation/widgets/dialogs/delete_environment_dialog.dart';
import 'package:relay/features/home/request/presentation/widgets/dialogs/delete_request_dialog.dart';
import 'package:relay/features/home/environment/presentation/widgets/dialogs/environment_dialog.dart';
import 'package:relay/features/home/request/presentation/widgets/request_runner_screen.dart';
import 'package:relay/features/home/request/presentation/widgets/request_workbench_tab.dart';
import 'package:relay/features/request_chain/presentation/request_chain_config_screen.dart';
import 'package:relay/features/request_chain/presentation/request_chain_workbench_tab.dart';
import 'package:relay/features/collection_runner/presentation/collection_runner_screen.dart';
import 'package:relay/features/collection_runner/presentation/collection_run_history_screen.dart';
import 'package:relay/features/collection_runner/presentation/collection_runner_workbench_tab.dart';
import 'package:relay/features/collection_runner/presentation/collection_run_history_workbench_tab.dart';
import 'package:relay/features/workspace/presentation/providers/workspace_ui_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _requestSearchQuery = '';
  static const int _navHttp = 0;
  int _activeTopNav = _navHttp;
  int _mobileNavIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final selectedCollectionId = ref.watch(selectedCollectionIdProvider);
    final collectionsAsync = ref.watch(collectionsNotifierProvider);
    final allRequestsAsync = ref.watch(requestsNotifierProvider);
    final filteredRequestsAsync = ref.watch(filteredRequestsProvider);
    final environmentsAsync = ref.watch(environmentsNotifierProvider);
    final activeEnvName = ref.watch(activeEnvironmentNameProvider);
    final isDesktopShell = screenWidth >= AppBreakpoints.desktop;
    final isMobileLayout = !isDesktopShell;
    final workspaceLayout = ref.watch(workspaceLayoutProvider);
    final activeSection = workspaceLayout.activeSection;

    final loadedCollections = collectionsAsync.asData?.value;
    if (loadedCollections != null && loadedCollections.isNotEmpty) {
      final preferredId = resolvePreferredCollectionId(
        loadedCollections: loadedCollections,
        selectedCollectionId: selectedCollectionId,
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

        return HomeRequestsView(
          requests: visibleRequests,
          onTapRequest: (request) => _showRequestDetails(context, request),
          onEditRequest: (request) => _showRequestDetails(context, request),
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

    if (isMobileLayout) {
      return Scaffold(
        drawer: drawer,
        floatingActionButton: _mobileNavIndex == 0
            ? FloatingActionButton.extended(
                onPressed: () => _openCreateRequestDialog(context, selectedCollectionId),
                icon: const Icon(Icons.add),
                label: const Text('New Request'),
              )
            : null,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _mobileNavIndex,
          onDestinationSelected: (index) => setState(() => _mobileNavIndex = index),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.http), label: 'Requests'),
            NavigationDestination(icon: Icon(Icons.play_circle_outline), label: 'Runner'),
            NavigationDestination(icon: Icon(Icons.account_tree_outlined), label: 'Flows'),
            NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          ],
        ),
        body: IndexedStack(
          index: _mobileNavIndex,
          children: [
            Column(
              children: [
                _buildTopToolbar(context, isMobileLayout, collectionsAsync, environmentsAsync, selectedCollectionId, activeEnvName),
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                  child: _buildSearchField(context),
                ),
                Expanded(child: SafeArea(top: false, child: requestBody)),
              ],
            ),
            const CollectionRunnerScreen(),
            const RequestChainConfigScreen(),
            const CollectionRunHistoryScreen(),
          ],
        ),
      );
    }

    final showInspector = workspaceLayout.isInspectorVisible && screenWidth >= 1280;
    final sidebarWidth = screenWidth >= 1360 ? workspaceLayout.sidebarWidth : 280.0;
    final inspectorWidth = screenWidth >= 1440 ? 280.0 : 240.0;

    return RoleShell(
      sidebarWidth: workspaceLayout.isSidebarCollapsed ? 0 : sidebarWidth,
      inspectorWidth: inspectorWidth,
      showSidebar: !workspaceLayout.isSidebarCollapsed,
      showInspector: showInspector,
      topBar: _buildDesktopShellTopBar(context, environmentsAsync, activeEnvName, showInspector),
      leftRail: _buildDesktopLeftRail(activeSection),
      sidebarPanel: _buildDesktopSidebarPanel(
        context,
        activeSection,
        collectionsAsync,
        filteredRequestsAsync,
        environmentsAsync,
        selectedCollectionId,
        activeEnvName,
      ),
      workbench: _buildDesktopWorkbench(
        context,
        activeSection,
        allRequestsAsync,
        selectedCollectionId,
      ),
      inspector: _buildDesktopInspector(
        context,
        activeSection,
        selectedCollectionId,
        activeEnvName,
        collectionsAsync,
        filteredRequestsAsync,
      ),
      statusBar: _buildDesktopStatusBar(activeSection, activeEnvName, filteredRequestsAsync),
    );
  }

  Widget _buildDesktopShellTopBar(
    BuildContext context,
    AsyncValue<List<EnvironmentModel>> environmentsAsync,
    String? activeEnvName,
    bool inspectorVisible,
  ) {
    return RoleTopBar(
      title: AppConstants.appName,
      searchPlaceholder: 'Command bar and global search will land in the next phase.',
      inspectorVisible: inspectorVisible,
      onToggleInspector: () => ref.read(workspaceLayoutProvider.notifier).toggleInspector(),
      environmentSelector: environmentsAsync.when(
        data: (envs) => EnvironmentSelector(
          envs: envs,
          activeEnvName: activeEnvName,
          iconOnly: true,
          onSelect: (name) {
            if (name != null && name.startsWith('__action__')) return;
            ref.read(activeEnvironmentNameProvider.notifier).setActiveName(name);
            ref.read(activeEnvironmentNotifierProvider.notifier).setActiveEnvironment(name);
          },
          onEdit: (env) => _openEditEnvironmentDialog(context, env),
          onDelete: (env) => _onDeleteEnvironment(context, env),
        ),
        loading: () => const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2)),
        error: (_, _) => const SizedBox.shrink(),
      ),
      actions: [
        IconButton(
          tooltip: 'Import workspace',
          onPressed: () => _handleImportWorkspace(context, ref),
          icon: const Icon(Icons.file_download_outlined),
        ),
        IconButton(
          tooltip: 'Export workspace',
          onPressed: () => _handleExportWorkspace(context, ref),
          icon: const Icon(Icons.file_upload_outlined),
        ),
        IconButton(
          tooltip: 'Theme settings',
          onPressed: () => _showThemeMenu(context),
          icon: const Icon(Icons.palette_outlined),
        ),
      ],
    );
  }

  Widget _buildDesktopLeftRail(WorkspaceSection activeSection) {
    return RoleLeftRail(
      destinations: const [
        RoleRailDestination(icon: Icons.http, label: 'Req'),
        RoleRailDestination(icon: Icons.history, label: 'Hist'),
        RoleRailDestination(icon: Icons.play_circle_outline, label: 'Runs'),
        RoleRailDestination(icon: Icons.account_tree_outlined, label: 'Flows'),
        RoleRailDestination(icon: Icons.cloud_outlined, label: 'Env'),
      ],
      selectedIndex: activeSection.index,
      onSelect: (index) => ref.read(workspaceLayoutProvider.notifier).setActiveSection(WorkspaceSection.values[index]),
    );
  }

  Widget _buildDesktopSidebarPanel(
    BuildContext context,
    WorkspaceSection activeSection,
    AsyncValue<List<CollectionModel>> collectionsAsync,
    AsyncValue<List<ApiRequestModel>> filteredRequestsAsync,
    AsyncValue<List<EnvironmentModel>> environmentsAsync,
    String? selectedCollectionId,
    String? activeEnvName,
  ) {
    return RoleSidebarPanel(
      title: _sidebarTitle(activeSection),
      subtitle: _sidebarSubtitle(activeSection),
      child: switch (activeSection) {
        WorkspaceSection.requests => _buildRequestsSidebarContent(
            context,
            collectionsAsync,
            filteredRequestsAsync,
            environmentsAsync,
            selectedCollectionId,
            activeEnvName,
          ),
        WorkspaceSection.history => _buildShortcutSidebarContent(
            context,
            title: 'Run History',
            message: 'Open run history inside the workbench or use the standalone history screen when needed.',
            actions: [
              _SidebarAction(label: 'Open In Workbench', icon: Icons.history, onPressed: _openRunHistoryTab),
              _SidebarAction(label: 'Open Standalone', icon: Icons.open_in_new, onPressed: () => _openRunHistory(context)),
            ],
          ),
        WorkspaceSection.runs => _buildShortcutSidebarContent(
            context,
            title: 'Run Tools',
            message: 'Collection Runner and run history now open directly inside the desktop workbench.',
            actions: [
              _SidebarAction(label: 'Open Runner Tab', icon: Icons.play_circle_outline, onPressed: _openRunSetupTab),
              _SidebarAction(label: 'Open History Tab', icon: Icons.history, onPressed: _openRunHistoryTab),
              _SidebarAction(label: 'Open Standalone Runner', icon: Icons.open_in_new, onPressed: () => _openCollectionRunner(context)),
            ],
          ),
        WorkspaceSection.flows => _buildShortcutSidebarContent(
            context,
            title: 'Flow Tools',
            message: 'Request chains now open inside the desktop workbench.',
            actions: [
              _SidebarAction(label: 'Open Flow Tab', icon: Icons.account_tree_outlined, onPressed: _openFlowTab),
              _SidebarAction(label: 'Open Standalone Flow', icon: Icons.open_in_new, onPressed: () => _openRequestChain(context)),
            ],
          ),
        WorkspaceSection.environments => _buildEnvironmentsSidebarContent(context, environmentsAsync, activeEnvName),
      },
    );
  }

  Widget _buildDesktopWorkbench(
    BuildContext context,
    WorkspaceSection activeSection,
    AsyncValue<List<ApiRequestModel>> allRequestsAsync,
    String? selectedCollectionId,
  ) {
    final workspaceLayout = ref.watch(workspaceLayoutProvider);
    final allRequests = allRequestsAsync.asData?.value ?? const <ApiRequestModel>[];
    final requestTabs = workspaceLayout.tabs.where((tab) => tab.type == WorkbenchTabType.request).toList(growable: false);
    final runTabs = workspaceLayout.tabs.where((tab) => tab.type == WorkbenchTabType.runSetup || tab.type == WorkbenchTabType.runReport).toList(growable: false);
    final flowTabs = workspaceLayout.tabs.where((tab) => tab.type == WorkbenchTabType.flow).toList(growable: false);
    final activeRequestTab = _resolveActiveTabForTypes(
      workspaceLayout.tabs,
      workspaceLayout.activeTabId,
      {WorkbenchTabType.request},
    );
    final activeRunTab = _resolveActiveTabForTypes(
      workspaceLayout.tabs,
      workspaceLayout.activeTabId,
      {WorkbenchTabType.runSetup, WorkbenchTabType.runReport},
    );
    final activeFlowTab = _resolveActiveTabForTypes(
      workspaceLayout.tabs,
      workspaceLayout.activeTabId,
      {WorkbenchTabType.flow},
    );
    final activeRequest = _resolveRequestById(allRequests, activeRequestTab?.subtitle);

    return RoleWorkbench(
      title: _workbenchTitle(activeSection),
      subtitle: _workbenchSubtitle(activeSection),
      child: switch (activeSection) {
        WorkspaceSection.requests => Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.lg, AppSpacing.lg),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.6)),
              ),
              child: requestTabs.isNotEmpty && activeRequestTab != null && activeRequest != null
                  ? Column(
                      children: [
                        _buildRequestTabStrip(context, requestTabs, activeRequestTab.id, allRequests),
                        const Divider(height: 1),
                        Expanded(
                          child: RequestWorkbenchTab(
                            request: activeRequest,
                            onDelete: () => _onDeleteRequest(context, activeRequest),
                            onRequestSaved: (updatedRequest) => ref.read(workspaceLayoutProvider.notifier).updateRequestTab(
                                  requestId: updatedRequest.id,
                                  title: updatedRequest.name,
                                ),
                          ),
                        ),
                      ],
                    )
                  : _buildRequestWorkbenchEmptyState(context, selectedCollectionId),
            ),
          ),
        WorkspaceSection.history => Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.lg, AppSpacing.lg),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.6)),
              ),
              child: const CollectionRunHistoryWorkbenchTab(),
            ),
          ),
        WorkspaceSection.runs => Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.lg, AppSpacing.lg),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.6)),
              ),
              child: activeRunTab != null
                  ? Column(
                      children: [
                        _buildRunTabStrip(context, runTabs, activeRunTab.id),
                        const Divider(height: 1),
                        Expanded(
                          child: switch (activeRunTab.type) {
                            WorkbenchTabType.runSetup => const CollectionRunnerWorkbenchTab(),
                            WorkbenchTabType.runReport => const CollectionRunHistoryWorkbenchTab(),
                            _ => const SizedBox.shrink(),
                          },
                        ),
                      ],
                    )
                  : _buildWorkbenchPlaceholder(
                      context,
                      title: 'Collection Runner',
                      message: 'Open the collection runner or run history into the workbench from the left panel.',
                      actions: [
                        _SidebarAction(label: 'Open Runner Tab', icon: Icons.play_arrow, onPressed: _openRunSetupTab),
                        _SidebarAction(label: 'Open History Tab', icon: Icons.history, onPressed: _openRunHistoryTab),
                      ],
                    ),
            ),
          ),
        WorkspaceSection.flows => Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.lg, AppSpacing.lg),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.6)),
              ),
              child: activeFlowTab != null
                  ? Column(
                      children: [
                        _buildFlowTabStrip(context, flowTabs, activeFlowTab.id),
                        const Divider(height: 1),
                        const Expanded(child: RequestChainWorkbenchTab()),
                      ],
                    )
                  : _buildWorkbenchPlaceholder(
                      context,
                      title: 'Request Chains',
                      message: 'Open the request chain tool into the workbench from the left panel.',
                      actions: [
                        _SidebarAction(label: 'Open Flow Tab', icon: Icons.account_tree_outlined, onPressed: _openFlowTab),
                      ],
                    ),
            ),
          ),
        WorkspaceSection.environments => _buildWorkbenchPlaceholder(
            context,
            title: 'Environment Workbench',
            message: 'Environment editing will become a first-class workbench surface in a later phase. Selection and management remain available from the shell today.',
            actions: [
              _SidebarAction(label: 'Create Environment', icon: Icons.add_circle_outline, onPressed: () => _openCreateEnvironmentDialog(context)),
            ],
          ),
      },
    );
  }

  Widget _buildDesktopInspector(
    BuildContext context,
    WorkspaceSection activeSection,
    String? selectedCollectionId,
    String? activeEnvName,
    AsyncValue<List<CollectionModel>> collectionsAsync,
    AsyncValue<List<ApiRequestModel>> filteredRequestsAsync,
  ) {
    final collectionName = _resolveCollectionName(collectionsAsync.asData?.value, selectedCollectionId);
    final visibleRequestCount = filteredRequestsAsync.asData?.value.length;

    return RoleInspector(
      title: 'Context',
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          AppCard(
            title: 'Workspace',
            margin: EdgeInsets.zero,
            elevation: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInspectorRow(context, 'Mode', 'Local-only'),
                _buildInspectorRow(context, 'Section', _workbenchTitle(activeSection)),
                _buildInspectorRow(context, 'Collection', collectionName ?? 'Not selected'),
                _buildInspectorRow(context, 'Environment', activeEnvName ?? 'No environment'),
                _buildInspectorRow(context, 'Visible requests', visibleRequestCount?.toString() ?? 'Loading...'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            title: 'Phase 1',
            subtitle: 'Desktop shell foundation',
            margin: EdgeInsets.zero,
            elevation: 0,
            child: Text(
              'This inspector is part of the new persistent shell. Requests remain the primary inline workflow while runner, history, and flow screens are still available through compatibility actions.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopStatusBar(
    WorkspaceSection activeSection,
    String? activeEnvName,
    AsyncValue<List<ApiRequestModel>> filteredRequestsAsync,
  ) {
    return RoleStatusBar(
      items: [
        const RoleStatusItem(label: 'Mode', value: 'Local-only'),
        RoleStatusItem(label: 'Section', value: _workbenchTitle(activeSection)),
        RoleStatusItem(label: 'Environment', value: activeEnvName ?? 'None'),
        RoleStatusItem(label: 'Visible requests', value: filteredRequestsAsync.asData?.value.length.toString() ?? '...'),
      ],
    );
  }

  Widget _buildRequestsSidebarContent(
    BuildContext context,
    AsyncValue<List<CollectionModel>> collectionsAsync,
    AsyncValue<List<ApiRequestModel>> filteredRequestsAsync,
    AsyncValue<List<EnvironmentModel>> environmentsAsync,
    String? selectedCollectionId,
    String? activeEnvName,
  ) {
    final theme = Theme.of(context);

    Widget sectionCard({required String title, required Widget child}) {
      return AppCard(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.md),
        elevation: 0,
        title: title,
        child: child,
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              AppButton(label: 'New Request', icon: Icons.add, isFullWidth: true, onPressed: () => _openCreateRequestDialog(context, selectedCollectionId)),
              const SizedBox(height: AppSpacing.md),
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
              sectionCard(
                title: 'Quick Actions',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppButton(
                      label: 'New Collection',
                      icon: Icons.add_box_outlined,
                      variant: AppButtonVariant.outlined,
                      onPressed: () => _openCreateCollectionDialog(context),
                      isFullWidth: true,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppButton(
                      label: 'New Environment',
                      icon: Icons.cloud_outlined,
                      variant: AppButtonVariant.outlined,
                      onPressed: () => _openCreateEnvironmentDialog(context),
                      isFullWidth: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7))),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
                child: _buildSearchField(context),
              ),
              SizedBox(
                height: 280,
                child: filteredRequestsAsync.when(
                  data: (requests) {
                    final visibleRequests = requests.where((request) {
                      if (_requestSearchQuery.trim().isEmpty) {
                        return true;
                      }
                      final q = _requestSearchQuery.toLowerCase();
                      return request.name.toLowerCase().contains(q) ||
                          request.urlTemplate.toLowerCase().contains(q) ||
                          request.method.name.toLowerCase().contains(q);
                    }).toList();

                    if (visibleRequests.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Text(
                            requests.isEmpty ? 'No requests in this collection yet.' : 'No requests match your search.',
                            style: theme.textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    return HomeRequestsView(
                      requests: visibleRequests,
                      onTapRequest: (request) => _showRequestDetails(context, request),
                      onEditRequest: (request) => _showRequestDetails(context, request),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  error: (error, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Text('Failed to load requests: $error', style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEnvironmentsSidebarContent(
    BuildContext context,
    AsyncValue<List<EnvironmentModel>> environmentsAsync,
    String? activeEnvName,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: environmentsAsync.when(
        data: (envs) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppButton(label: 'New Environment', icon: Icons.add, isFullWidth: true, onPressed: () => _openCreateEnvironmentDialog(context)),
            const SizedBox(height: AppSpacing.md),
            EnvironmentSelector(
              envs: envs,
              activeEnvName: activeEnvName,
              onSelect: (name) {
                ref.read(activeEnvironmentNameProvider.notifier).setActiveName(name);
                ref.read(activeEnvironmentNotifierProvider.notifier).setActiveEnvironment(name);
              },
              onEdit: (env) => _openEditEnvironmentDialog(context, env),
              onDelete: (env) => _onDeleteEnvironment(context, env),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Text('Failed to load environments', style: theme.textTheme.bodySmall),
      ),
    );
  }

  Widget _buildShortcutSidebarContent(
    BuildContext context, {
    required String title,
    required String message,
    required List<_SidebarAction> actions,
  }) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: AppCard(
        title: title,
        subtitle: 'Compatibility tools',
        margin: EdgeInsets.zero,
        elevation: 0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(message, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppSpacing.md),
            for (var i = 0; i < actions.length; i++) ...[
              AppButton(label: actions[i].label, icon: actions[i].icon, onPressed: actions[i].onPressed, isFullWidth: true),
              if (i != actions.length - 1) const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWorkbenchPlaceholder(
    BuildContext context, {
    required String title,
    required String message,
    required List<_SidebarAction> actions,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.lg, AppSpacing.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: AppCard(
            title: title,
            subtitle: 'Phase 1 foundation',
            margin: EdgeInsets.zero,
            elevation: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(message, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final action in actions)
                      AppButton(label: action.label, icon: action.icon, onPressed: action.onPressed),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequestWorkbenchEmptyState(BuildContext context, String? selectedCollectionId) {
    return HomeEmptyState(
      onCreateRequest: () => _openCreateRequestDialog(context, selectedCollectionId),
      title: 'No Request Tab Open',
      message: 'Select a request from the left sidebar to open it here, or create a new one to start building your workspace.',
    );
  }

  Widget _buildRequestTabStrip(
    BuildContext context,
    List<WorkbenchTabModel> tabs,
    String? activeTabId,
    List<ApiRequestModel> allRequests,
  ) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, 0),
      child: Row(
        children: [
          for (final tab in tabs)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: _buildRequestTabChip(
                context,
                tab,
                activeTabId == tab.id,
                _resolveTabRequest(allRequests, tab),
                theme,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRunTabStrip(
    BuildContext context,
    List<WorkbenchTabModel> tabs,
    String? activeTabId,
  ) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, 0),
      child: Row(
        children: [
          for (final tab in tabs)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: Material(
                color: activeTabId == tab.id ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: InkWell(
                  onTap: () => ref.read(workspaceLayoutProvider.notifier).activateTab(tab.id),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 240),
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          tab.type == WorkbenchTabType.runSetup ? Icons.play_circle_outline : Icons.history,
                          size: 16,
                          color: activeTabId == tab.id ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Text(
                            tab.title,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: activeTabId == tab.id ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        InkWell(
                          onTap: () => ref.read(workspaceLayoutProvider.notifier).closeTab(tab.id),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: (activeTabId == tab.id ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface).withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFlowTabStrip(
    BuildContext context,
    List<WorkbenchTabModel> tabs,
    String? activeTabId,
  ) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, 0),
      child: Row(
        children: [
          for (final tab in tabs)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: Material(
                color: activeTabId == tab.id ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: InkWell(
                  onTap: () => ref.read(workspaceLayoutProvider.notifier).activateTab(tab.id),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 240),
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.account_tree_outlined, size: 16, color: activeTabId == tab.id ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface),
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Text(
                            tab.title,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: activeTabId == tab.id ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        InkWell(
                          onTap: () => ref.read(workspaceLayoutProvider.notifier).closeTab(tab.id),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: (activeTabId == tab.id ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface).withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRequestTabChip(
    BuildContext context,
    WorkbenchTabModel tab,
    bool isActive,
    ApiRequestModel? request,
    ThemeData theme,
  ) {
    final backgroundColor = isActive ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerLowest;
    final foregroundColor = isActive ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface;

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: () => ref.read(workspaceLayoutProvider.notifier).activateTab(tab.id),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 260),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (request != null) ...[
                MethodBadge(method: request.method, size: MethodBadgeSize.small),
                const SizedBox(width: AppSpacing.sm),
              ],
              Flexible(
                child: Text(
                  request?.name ?? tab.title,
                  style: theme.textTheme.labelMedium?.copyWith(color: foregroundColor, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              InkWell(
                onTap: () => ref.read(workspaceLayoutProvider.notifier).closeTab(tab.id),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(Icons.close, size: 16, color: foregroundColor.withValues(alpha: 0.8)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInspectorRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 96, child: Text(label, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
          Expanded(child: Text(value, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }

  String _sidebarTitle(WorkspaceSection section) => switch (section) {
        WorkspaceSection.requests => 'Requests',
        WorkspaceSection.history => 'History',
        WorkspaceSection.runs => 'Runs',
        WorkspaceSection.flows => 'Flows',
        WorkspaceSection.environments => 'Environments',
      };

  String _sidebarSubtitle(WorkspaceSection section) => switch (section) {
        WorkspaceSection.requests => 'Collections, environment, and creation tools',
        WorkspaceSection.history => 'History shortcuts during the shell migration',
        WorkspaceSection.runs => 'Runner shortcuts during the shell migration',
        WorkspaceSection.flows => 'Request chain shortcuts during the shell migration',
        WorkspaceSection.environments => 'Active environment and management tools',
      };

  String _workbenchTitle(WorkspaceSection section) => switch (section) {
        WorkspaceSection.requests => 'Request Workbench',
        WorkspaceSection.history => 'History',
        WorkspaceSection.runs => 'Runs',
        WorkspaceSection.flows => 'Flows',
        WorkspaceSection.environments => 'Environments',
      };

  String _workbenchSubtitle(WorkspaceSection section) => switch (section) {
        WorkspaceSection.requests => 'Requests stay inline while the new shell architecture lands.',
        WorkspaceSection.history => 'A dedicated history workbench will replace route-based navigation next.',
        WorkspaceSection.runs => 'Collection Runner will move into the central workbench in the next phase.',
        WorkspaceSection.flows => 'Request chains remain available while the shell is established.',
        WorkspaceSection.environments => 'Environment editing will become a first-class workbench surface later.',
      };

  String? _resolveCollectionName(List<CollectionModel>? collections, String? selectedCollectionId) {
    if (collections == null || selectedCollectionId == null) {
      return null;
    }

    for (final collection in collections) {
      if (collection.id == selectedCollectionId) {
        return collection.name;
      }
    }

    return null;
  }

  WorkbenchTabModel? _resolveActiveTabForTypes(
    List<WorkbenchTabModel> tabs,
    String? activeTabId,
    Set<WorkbenchTabType> types,
  ) {
    WorkbenchTabModel? fallback;

    for (final tab in tabs) {
      if (!types.contains(tab.type)) {
        continue;
      }

      fallback ??= tab;
      if (tab.id == activeTabId) {
        return tab;
      }
    }

    return fallback;
  }

  ApiRequestModel? _resolveRequestById(List<ApiRequestModel> requests, String? requestId) {
    if (requestId == null) {
      return null;
    }

    for (final request in requests) {
      if (request.id == requestId) {
        return request;
      }
    }

    return null;
  }

  ApiRequestModel? _resolveTabRequest(List<ApiRequestModel> requests, WorkbenchTabModel tab) {
    final requestId = tab.subtitle;
    return _resolveRequestById(requests, requestId);
  }

  void _showThemeMenu(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Appearance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.light_mode_outlined),
              title: const Text('Light'),
              onTap: () {
                ref.read(themeModeNotifierProvider.notifier).setThemeMode(ThemeMode.light);
                Navigator.of(dialogContext).pop();
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.dark_mode_outlined),
              title: const Text('Dark'),
              onTap: () {
                ref.read(themeModeNotifierProvider.notifier).setThemeMode(ThemeMode.dark);
                Navigator.of(dialogContext).pop();
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.settings_suggest_outlined),
              title: const Text('System'),
              onTap: () {
                ref.read(themeModeNotifierProvider.notifier).setThemeMode(ThemeMode.system);
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openCollectionRunner(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CollectionRunnerScreen()));
  }

  void _openRunSetupTab() {
    ref.read(workspaceLayoutProvider.notifier).openRunSetupTab();
  }

  void _openRunHistory(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CollectionRunHistoryScreen()));
  }

  void _openRunHistoryTab() {
    ref.read(workspaceLayoutProvider.notifier).openRunHistoryTab();
  }

  void _openFlowTab() {
    ref.read(workspaceLayoutProvider.notifier).openFlowTab();
  }

  void _openRequestChain(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RequestChainConfigScreen()));
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
    final titleStyle = theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.2);
    final titleWidget = Text(AppConstants.appName, style: titleStyle, maxLines: 1, overflow: TextOverflow.ellipsis);

    return Container(
      color: theme.colorScheme.surfaceContainerLow,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: kToolbarHeight,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)))),
          child: Row(
            children: [
              if (isMobileLayout)
                Builder(
                  builder: (context) =>
                      IconButton(icon: const Icon(Icons.menu), tooltip: 'Open menu', onPressed: () => Scaffold.of(context).openDrawer()),
                ),
              const SizedBox(width: AppSpacing.xs),
              if (isMobileLayout) Flexible(child: titleWidget) else titleWidget,
              const SizedBox(width: AppSpacing.lg),
              if (!isMobileLayout) ...[
                AppNavChip(
                  icon: Icons.http,
                  label: 'HTTP',
                  selected: _activeTopNav == _navHttp,
                  onTap: () => setState(() => _activeTopNav = _navHttp),
                ),
                AppNavChip(
                  icon: Icons.play_circle_outline,
                  label: 'Runner',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CollectionRunnerScreen())),
                ),
                AppNavChip(
                  icon: Icons.account_tree_outlined,
                  label: 'Flows',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RequestChainConfigScreen())),
                ),
                const SizedBox(width: AppSpacing.md),
                VerticalDivider(width: 1, thickness: 1, indent: 10, endIndent: 10, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
                const SizedBox(width: AppSpacing.xs),
                AppToolbarAction(icon: Icons.file_download_outlined, label: 'Import', onTap: () => _handleImportWorkspace(context, ref)),
                AppToolbarAction(icon: Icons.file_upload_outlined, label: 'Export', onTap: () => _handleExportWorkspace(context, ref)),
                AppToolbarAction(icon: Icons.add_box_outlined, label: 'Collection', onTap: () => _openCreateCollectionDialog(context)),
                AppToolbarAction(icon: Icons.add_circle_outline, label: 'Environment', onTap: () => _openCreateEnvironmentDialog(context)),
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
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      onChanged: (value) => setState(() => _requestSearchQuery = value),
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Search requests by name, URL, method...',
        prefixIcon: const Icon(Icons.search, size: 18),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
      ),
    );
  }

  // Collection and environment selectors are implemented as separate widgets
  // in `CollectionSelector` and `EnvironmentSelector`.

  void _showRequestDetails(BuildContext context, ApiRequestModel request) {
    if (MediaQuery.of(context).size.width >= AppBreakpoints.desktop) {
      ref.read(workspaceLayoutProvider.notifier).openRequestTab(requestId: request.id, title: request.name);
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (pageContext) => RequestRunnerPage(
          request: request,
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

class _SidebarAction {
  const _SidebarAction({required this.label, required this.icon, required this.onPressed});

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
}
