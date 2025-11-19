import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/core/service/workspace_import_export_service.dart';
import 'package:relay/features/home/presentation/providers/repository_providers.dart';

final workspaceImportExportServiceProvider = Provider<WorkspaceImportExportService>((ref) {
  return WorkspaceImportExportService(
    requestRepository: ref.watch(requestRepositoryProvider),
    collectionRepository: ref.watch(collectionRepositoryProvider),
    environmentRepository: ref.watch(environmentRepositoryProvider),
  );
});

