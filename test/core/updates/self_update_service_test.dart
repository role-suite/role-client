import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/updates/self_update_service.dart';
import 'package:relay/core/updates/update_applier.dart';

class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this._respond);

  final Future<ResponseBody> Function(RequestOptions options) _respond;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) => _respond(options);
}

class _RecordingApplier implements UpdateApplier {
  final List<String> appliedFiles = <String>[];

  @override
  Future<void> apply({required String downloadedFile, required String tag, required String version}) async {
    appliedFiles.add(downloadedFile);
  }
}

const _assetName = 'relay-1.2.0-windows-x64-setup.exe';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('relay-update-test');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  SelfUpdateService serviceWith({required _RecordingApplier applier, required String assetContent, required String checksums}) {
    final dio = Dio()
      ..httpClientAdapter = _ScriptedAdapter((options) async {
        if (options.path.endsWith('SHA256SUMS')) {
          return ResponseBody.fromString(
            checksums,
            200,
            headers: {
              Headers.contentTypeHeader: ['text/plain'],
            },
          );
        }
        return ResponseBody.fromString(
          assetContent,
          200,
          headers: {
            Headers.contentLengthHeader: ['${assetContent.length}'],
          },
        );
      });
    return SelfUpdateService(applier: applier, dio: dio, temporaryDirectory: () async => tempDir);
  }

  test('downloads, verifies against SHA256SUMS, and applies the update', () async {
    const asset = 'installer-bytes';
    final digest = sha256.convert(utf8.encode(asset)).toString();
    final applier = _RecordingApplier();
    final service = serviceWith(applier: applier, assetContent: asset, checksums: '$digest  $_assetName\n');

    var verified = false;
    await service.downloadAndInstall(tag: 'v1.2.0', version: '1.2.0', assetName: _assetName, onVerified: () => verified = true);

    expect(verified, isTrue);
    expect(applier.appliedFiles, hasLength(1));
    expect(File(applier.appliedFiles.single).readAsStringSync(), asset);
  });

  test('reports download progress', () async {
    const asset = 'installer-bytes';
    final digest = sha256.convert(utf8.encode(asset)).toString();
    final service = serviceWith(applier: _RecordingApplier(), assetContent: asset, checksums: '$digest  $_assetName\n');

    final progress = <double>[];
    await service.downloadAndInstall(
      tag: 'v1.2.0',
      version: '1.2.0',
      assetName: _assetName,
      onProgress: (received, total) => progress.add(total > 0 ? received / total : 0),
    );

    expect(progress, isNotEmpty);
    expect(progress.last, 1.0);
  });

  test('discards the download when verification fails', () async {
    final applier = _RecordingApplier();
    final service = serviceWith(applier: applier, assetContent: 'tampered', checksums: '${'0' * 64}  $_assetName\n');

    await expectLater(
      service.downloadAndInstall(tag: 'v1.2.0', version: '1.2.0', assetName: _assetName),
      throwsA(isA<SelfUpdateException>().having((e) => e.message, 'message', contains('verification'))),
    );
    expect(applier.appliedFiles, isEmpty);
    expect(File('${tempDir.path}/$_assetName').existsSync(), isFalse);
  });

  test('fails when the checksum file does not list the asset', () async {
    final applier = _RecordingApplier();
    final service = serviceWith(applier: applier, assetContent: 'bytes', checksums: '${'a' * 64}  some-other-file.zip\n');

    await expectLater(
      service.downloadAndInstall(tag: 'v1.2.0', version: '1.2.0', assetName: _assetName),
      throwsA(isA<SelfUpdateException>().having((e) => e.message, 'message', contains('does not list'))),
    );
    expect(applier.appliedFiles, isEmpty);
  });

  test('maps a missing release file to a friendly message', () async {
    final dio = Dio()..httpClientAdapter = _ScriptedAdapter((options) async => ResponseBody.fromString('not found', 404));
    final service = SelfUpdateService(applier: _RecordingApplier(), dio: dio, temporaryDirectory: () async => tempDir);

    await expectLater(
      service.downloadAndInstall(tag: 'v1.2.0', version: '1.2.0', assetName: _assetName),
      throwsA(isA<SelfUpdateException>().having((e) => e.message, 'message', contains('not found on GitHub'))),
    );
  });

  test('sha256OfFile matches crypto', () async {
    final file = File('${tempDir.path}/sample.bin');
    await file.writeAsBytes(utf8.encode('hello'));
    expect(await sha256OfFile(file), sha256.convert(utf8.encode('hello')).toString());
  });
}
