import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'workbench_state.dart';

class WorkbenchNotifier extends Notifier<WorkbenchState> {
  @override
  WorkbenchState build() => const WorkbenchState();

  void selectSection(WorkspaceSection section) {
    state = state.copyWith(section: section);
  }

  void toggleSidebar() {
    state = state.copyWith(sidebarCollapsed: !state.sidebarCollapsed);
  }

  void toggleInspector() {
    state = state.copyWith(inspectorVisible: !state.inspectorVisible);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  /// Opens a tab, focusing an existing one instead of duplicating it.
  void openTab({required WorkbenchTabType type, required String title, String? payloadId}) {
    final id = WorkbenchTab.idFor(type, payloadId);
    final exists = state.tabs.any((t) => t.id == id);
    final tabs = exists ? state.tabs : [...state.tabs, WorkbenchTab(id: id, type: type, title: title, payloadId: payloadId)];
    state = state.copyWith(tabs: tabs, activeTabId: id, openSignal: state.openSignal + 1);
  }

  void focusTab(String tabId) {
    if (state.tabs.any((t) => t.id == tabId)) {
      state = state.copyWith(activeTabId: tabId);
    }
  }

  void closeTab(String tabId) {
    final tabs = state.tabs.where((t) => t.id != tabId).toList();
    String? nextActive = state.activeTabId;
    if (state.activeTabId == tabId) {
      final closedIndex = state.tabs.indexWhere((t) => t.id == tabId);
      nextActive = tabs.isEmpty ? null : tabs[(closedIndex - 1).clamp(0, tabs.length - 1)].id;
    }
    state = state.copyWith(tabs: tabs, activeTabId: nextActive, clearActiveTab: nextActive == null);
  }

  void setTabDirty(String tabId, bool isDirty) {
    state = state.copyWith(tabs: state.tabs.map((t) => t.id == tabId ? t.copyWith(isDirty: isDirty) : t).toList());
  }

  void renameTab(String tabId, String title) {
    state = state.copyWith(tabs: state.tabs.map((t) => t.id == tabId ? t.copyWith(title: title) : t).toList());
  }
}

final workbenchProvider = NotifierProvider<WorkbenchNotifier, WorkbenchState>(WorkbenchNotifier.new);
