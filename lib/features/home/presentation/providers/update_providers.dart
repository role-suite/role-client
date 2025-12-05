import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/core/model/app_release_model.dart';
import 'package:relay/core/service/update_service.dart';

/// Provider for the UpdateService instance.
final updateServiceProvider = Provider<UpdateService>((ref) {
  return UpdateService();
});

/// Provider that checks for available updates.
/// Returns the latest release if an update is available, null otherwise.
final updateAvailableProvider = FutureProvider<AppReleaseModel?>((ref) async {
  final updateService = ref.watch(updateServiceProvider);
  return updateService.checkForUpdate();
});

/// Provider to manually trigger an update check.
/// Call ref.refresh(updateCheckProvider) to re-check for updates.
final updateCheckProvider = FutureProvider.autoDispose<AppReleaseModel?>((ref) async {
  final updateService = ref.watch(updateServiceProvider);
  return updateService.checkForUpdate();
});
