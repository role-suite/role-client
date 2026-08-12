enum WorkspaceSection { requests, history, runs, flows, environments }

enum WorkbenchTabType { request, environment, runnerSetup, runReport, flow, flowRun }

class WorkbenchTab {
  const WorkbenchTab({required this.id, required this.type, required this.title, this.payloadId, this.isDirty = false});

  /// Stable per (type, payloadId) so opening the same request twice focuses one tab.
  final String id;
  final WorkbenchTabType type;
  final String title;
  final String? payloadId;
  final bool isDirty;

  WorkbenchTab copyWith({String? title, bool? isDirty}) {
    return WorkbenchTab(id: id, type: type, title: title ?? this.title, payloadId: payloadId, isDirty: isDirty ?? this.isDirty);
  }

  static String idFor(WorkbenchTabType type, String? payloadId) => '${type.name}:${payloadId ?? ''}';
}

class WorkbenchState {
  const WorkbenchState({
    this.section = WorkspaceSection.requests,
    this.tabs = const [],
    this.activeTabId,
    this.sidebarCollapsed = false,
    this.inspectorVisible = true,
    this.searchQuery = '',
    this.openSignal = 0,
  });

  final WorkspaceSection section;
  final List<WorkbenchTab> tabs;
  final String? activeTabId;
  final bool sidebarCollapsed;
  final bool inspectorVisible;
  final String searchQuery;

  /// Bumped every time openTab() is called, even to refocus an already-open
  /// tab — lets the mobile shell know to push a route even on a re-tap.
  final int openSignal;

  WorkbenchTab? get activeTab {
    if (activeTabId == null) return null;
    for (final tab in tabs) {
      if (tab.id == activeTabId) return tab;
    }
    return null;
  }

  WorkbenchState copyWith({
    WorkspaceSection? section,
    List<WorkbenchTab>? tabs,
    String? activeTabId,
    bool clearActiveTab = false,
    bool? sidebarCollapsed,
    bool? inspectorVisible,
    String? searchQuery,
    int? openSignal,
  }) {
    return WorkbenchState(
      section: section ?? this.section,
      tabs: tabs ?? this.tabs,
      activeTabId: clearActiveTab ? null : (activeTabId ?? this.activeTabId),
      sidebarCollapsed: sidebarCollapsed ?? this.sidebarCollapsed,
      inspectorVisible: inspectorVisible ?? this.inspectorVisible,
      searchQuery: searchQuery ?? this.searchQuery,
      openSignal: openSignal ?? this.openSignal,
    );
  }
}
