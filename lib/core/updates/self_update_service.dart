import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../constants.dart';
import 'update_applier.dart';
import 'update_assets.dart';

typedef DownloadProgressCallback = void Function(int received, int total);

/// Downloads a release asset, verifies it against the release's `SHA256SUMS`,
/// then hands it to the platform [UpdateApplier]. On every real platform the
/// applier ends the process as part of applying, so [downloadAndInstall]
/// normally never returns.
class SelfUpdateService {
  SelfUpdateService({required this.applier, Dio? dio, Future<Directory> Function()? temporaryDirectory})
    : _dio = dio ?? Dio(BaseOptions(connectTimeout: AppConstants.defaultConnectTimeout, receiveTimeout: AppConstants.defaultReceiveTimeout)),
      _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  final UpdateApplier applier;
  final Dio _dio;
  final Future<Directory> Function() _temporaryDirectory;

  Future<void> downloadAndInstall({
    required String tag,
    required String version,
    required String assetName,
    DownloadProgressCallback? onProgress,
    void Function()? onVerified,
  }) async {
    final file = File('${(await _temporaryDirectory()).path}/$assetName');
    if (file.existsSync()) file.deleteSync();

    try {
      await _dio.download(
        assetDownloadUrl(tag: tag, assetName: assetName),
        file.path,
        onReceiveProgress: onProgress,
      );

      final checksums = await _dio.get<String>(checksumsDownloadUrl(tag), options: Options(responseType: ResponseType.plain));
      final expected = findChecksum(checksums.data ?? '', assetName);
      if (expected == null) {
        throw const SelfUpdateException('The release checksum file does not list this download.');
      }

      final actual = await sha256OfFile(file);
      if (actual != expected) {
        file.deleteSync();
        throw const SelfUpdateException('The downloaded update failed verification and was discarded.');
      }

      onVerified?.call();
      await applier.apply(downloadedFile: file.path, tag: tag, version: version);
    } on DioException catch (error) {
      throw SelfUpdateException(_messageFor(error));
    }
  }

  static String _messageFor(DioException error) {
    final status = error.response?.statusCode;
    if (status == 404) return 'The update file was not found on GitHub.';
    if (status != null) return 'Download failed ($status).';
    return 'Could not download the update. Check your connection and try again.';
  }
}

Future<String> sha256OfFile(File file) async {
  final digest = await sha256.bind(file.openRead()).first;
  return digest.toString();
}
