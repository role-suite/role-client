import 'dart:io';

import 'package:path_provider/path_provider.dart';

class ExportDirectoryService {
  const ExportDirectoryService._();

  static Future<Directory> resolveDownloadsDirectory() async {
    final directory = switch (Platform.operatingSystem) {
      'macos' || 'linux' => Directory(_joinHomePath('HOME', 'Downloads')),
      'windows' => Directory(_joinHomePath('USERPROFILE', 'Downloads')),
      'android' => Directory(_resolveAndroidDownloadsPath()),
      'ios' => await _resolveIosExportDirectory(),
      _ => throw UnsupportedError('Exports are not supported on ${Platform.operatingSystem}.'),
    };

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  static Future<Directory> _resolveIosExportDirectory() async {
    return getApplicationDocumentsDirectory();
  }

  static String _joinHomePath(String key, String child) {
    final home = Platform.environment[key];
    if (home == null || home.isEmpty) {
      throw FileSystemException('Unable to resolve the user home directory from $key.');
    }
    return '$home/$child';
  }

  static String _resolveAndroidDownloadsPath() {
    const primary = '/storage/emulated/0/Download';
    if (Directory(primary).existsSync()) {
      return primary;
    }

    const secondary = '/sdcard/Download';
    if (Directory(secondary).existsSync()) {
      return secondary;
    }

    return primary;
  }
}
