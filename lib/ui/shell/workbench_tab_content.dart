import 'package:flutter/material.dart';

import '../../state/workbench_state.dart';
import '../environments/environment_tab_view.dart';
import '../flows/flow_run_tab_view.dart';
import '../flows/flow_tab_view.dart';
import '../request/request_tab_view.dart';
import '../runner/run_report_tab_view.dart';
import '../runner/runner_setup_tab_view.dart';

/// Maps a [WorkbenchTab] to its content widget — shared by the desktop
/// workbench (tabbed) and the mobile shell (pushed as a route).
Widget buildWorkbenchTabContent(WorkbenchTab tab) {
  final content = switch (tab.type) {
    WorkbenchTabType.request => RequestTabView(requestId: tab.payloadId!),
    WorkbenchTabType.environment => EnvironmentTabView(environmentId: tab.payloadId!),
    WorkbenchTabType.runnerSetup => RunnerSetupTabView(collectionId: tab.payloadId!),
    WorkbenchTabType.runReport => RunReportTabView(runId: tab.payloadId!),
    WorkbenchTabType.flow => FlowTabView(chainId: tab.payloadId!),
    WorkbenchTabType.flowRun => FlowRunTabView(chainId: tab.payloadId!),
  };
  return KeyedSubtree(key: ValueKey(tab.id), child: content);
}
