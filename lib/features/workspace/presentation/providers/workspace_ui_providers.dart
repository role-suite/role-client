import 'package:flutter_riverpod/flutter_riverpod.dart';

enum WorkspaceSection { requests, history, runs, flows, environments }

enum WorkbenchTabType { request, runSetup, runReport, flow, environment }

class WorkbenchTabModel {
  const WorkbenchTabModel({
    required this.id,
    required this.type,
    required this.title,
    this.subtitle,
    this.isDirty = false,
  });

  final String id;
  final WorkbenchTabType type;
  final String title;
  final String? subtitle;
  final bool isDirty;

  WorkbenchTabModel copyWith({
    String? title,
    Object? subtitle = _noChange,
    bool? isDirty,
  }) {
    return WorkbenchTabModel(
      id: id,
      type: type,
      title: title ?? this.title,
      subtitle: identical(subtitle, _noChange) ? this.subtitle : subtitle as String?,
      isDirty: isDirty ?? this.isDirty,
    );
  }
}

class WorkspaceLayoutState {
  const WorkspaceLayoutState({
    this.activeSection = WorkspaceSection.requests,
    this.tabs = const <WorkbenchTabModel>[],
    this.activeTabId,
    this.isInspectorVisible = true,
    this.isSidebarCollapsed = false,
    this.sidebarWidth = 320,
  });

  final WorkspaceSection activeSection;
  final List<WorkbenchTabModel> tabs;
  final String? activeTabId;
  final bool isInspectorVisible;
  final bool isSidebarCollapsed;
  final double sidebarWidth;

  WorkspaceLayoutState copyWith({
    WorkspaceSection? activeSection,
    List<WorkbenchTabModel>? tabs,
    Object? activeTabId = _noChange,
    bool? isInspectorVisible,
    bool? isSidebarCollapsed,
    double? sidebarWidth,
  }) {
    return WorkspaceLayoutState(
      activeSection: activeSection ?? this.activeSection,
      tabs: tabs ?? this.tabs,
      activeTabId: identical(activeTabId, _noChange) ? this.activeTabId : activeTabId as String?,
      isInspectorVisible: isInspectorVisible ?? this.isInspectorVisible,
      isSidebarCollapsed: isSidebarCollapsed ?? this.isSidebarCollapsed,
      sidebarWidth: sidebarWidth ?? this.sidebarWidth,
    );
  }
}

const Object _noChange = Object();

class WorkspaceLayoutNotifier extends Notifier<WorkspaceLayoutState> {
  @override
  WorkspaceLayoutState build() => const WorkspaceLayoutState();

  void setActiveSection(WorkspaceSection section) {
    state = state.copyWith(activeSection: section);
  }

  void toggleInspector() {
    state = state.copyWith(isInspectorVisible: !state.isInspectorVisible);
  }

  void setInspectorVisible(bool visible) {
    state = state.copyWith(isInspectorVisible: visible);
  }

  void setSidebarCollapsed(bool collapsed) {
    state = state.copyWith(isSidebarCollapsed: collapsed);
  }

  void setSidebarWidth(double width) {
    state = state.copyWith(sidebarWidth: width.clamp(260, 420));
  }

  void activateTab(String tabId) {
    state = state.copyWith(activeTabId: tabId);
  }

  void openRequestTab({required String requestId, required String title}) {
    const section = WorkspaceSection.requests;
    final tabId = _requestTabId(requestId);
    WorkbenchTabModel? existingTab;
    for (final tab in state.tabs) {
      if (tab.id == tabId) {
        existingTab = tab;
        break;
      }
    }

    if (existingTab != null) {
      state = state.copyWith(activeSection: section, activeTabId: existingTab.id);
      return;
    }

    final tab = WorkbenchTabModel(
      id: tabId,
      type: WorkbenchTabType.request,
      title: title,
      subtitle: requestId,
    );

    state = state.copyWith(
      activeSection: section,
      tabs: [...state.tabs, tab],
      activeTabId: tab.id,
    );
  }

  void openRunSetupTab() {
    _openSingletonTab(
      section: WorkspaceSection.runs,
      tab: const WorkbenchTabModel(
        id: _runSetupTabId,
        type: WorkbenchTabType.runSetup,
        title: 'Collection Runner',
      ),
    );
  }

  void openRunHistoryTab() {
    _openSingletonTab(
      section: WorkspaceSection.runs,
      tab: const WorkbenchTabModel(
        id: _runHistoryTabId,
        type: WorkbenchTabType.runReport,
        title: 'Run History',
      ),
    );
  }

  void openFlowTab() {
    _openSingletonTab(
      section: WorkspaceSection.flows,
      tab: const WorkbenchTabModel(
        id: _flowTabId,
        type: WorkbenchTabType.flow,
        title: 'Request Chain',
      ),
    );
  }

  void closeTab(String tabId) {
    final nextTabs = state.tabs.where((tab) => tab.id != tabId).toList(growable: false);
    final isClosingActive = state.activeTabId == tabId;

    state = state.copyWith(
      tabs: nextTabs,
      activeTabId: isClosingActive ? (nextTabs.isEmpty ? null : nextTabs.last.id) : state.activeTabId,
    );
  }

  void updateRequestTab({required String requestId, String? title, bool? isDirty}) {
    final tabId = _requestTabId(requestId);
    final nextTabs = state.tabs
        .map((tab) => tab.id == tabId ? tab.copyWith(title: title, isDirty: isDirty) : tab)
        .toList(growable: false);
    state = state.copyWith(tabs: nextTabs);
  }

  String? activeRequestId() {
    final activeTabId = state.activeTabId;
    if (activeTabId == null || !activeTabId.startsWith(_requestTabPrefix)) {
      return null;
    }

    return activeTabId.substring(_requestTabPrefix.length);
  }

  WorkbenchTabModel? activeTab() {
    final activeTabId = state.activeTabId;
    if (activeTabId == null) {
      return null;
    }

    for (final tab in state.tabs) {
      if (tab.id == activeTabId) {
        return tab;
      }
    }

    return null;
  }

  void _openSingletonTab({required WorkspaceSection section, required WorkbenchTabModel tab}) {
    WorkbenchTabModel? existingTab;
    for (final candidate in state.tabs) {
      if (candidate.id == tab.id) {
        existingTab = candidate;
        break;
      }
    }

    if (existingTab != null) {
      state = state.copyWith(activeSection: section, activeTabId: existingTab.id);
      return;
    }

    state = state.copyWith(
      activeSection: section,
      tabs: [...state.tabs, tab],
      activeTabId: tab.id,
    );
  }
}

final workspaceLayoutProvider = NotifierProvider<WorkspaceLayoutNotifier, WorkspaceLayoutState>(WorkspaceLayoutNotifier.new);

const _requestTabPrefix = 'request:';
const _runSetupTabId = 'run:setup';
const _runHistoryTabId = 'run:history';
const _flowTabId = 'flow:request-chain';

String _requestTabId(String requestId) => '$_requestTabPrefix$requestId';
