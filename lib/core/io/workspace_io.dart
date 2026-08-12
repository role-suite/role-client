import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../models/environment.dart';
import '../models/workspace_bundle.dart';
import 'postman_import.dart';

class ImportedData {
  const ImportedData({this.collections = const [], this.environments = const []});

  final List<CollectionBundle> collections;
  final List<Environment> environments;
}

/// Exports and imports the workspace as JSON — Röle's own bundle format, or
/// Postman v2.x collection/environment exports for interop.
class WorkspaceIo {
  const WorkspaceIo._();

  static String buildBundleJson({required List<CollectionBundle> collections, required List<Environment> environments}) {
    final bundle = WorkspaceBundle(exportedAt: DateTime.now(), source: 'role', collections: collections, environments: environments);
    return const JsonEncoder.withIndent('  ').convert(bundle.toJson());
  }

  /// Opens a native "Save As" dialog and writes the export there.
  /// Returns the chosen path, or null if the user cancelled.
  static Future<String?> exportToFile(String jsonContent, {String fileName = 'role-workspace.json'}) {
    return FilePicker.platform.saveFile(
      dialogTitle: 'Export Röle workspace',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: Uint8List.fromList(utf8.encode(jsonContent)),
    );
  }

  /// Opens a native file picker, reads the chosen JSON file, and parses it
  /// as either a Röle workspace bundle or a Postman collection/environment.
  /// Returns null if the user cancelled or the file couldn't be parsed.
  static Future<ImportedData?> pickAndParse() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json'], withData: true);
    final file = result?.files.singleOrNull;
    if (file == null) return null;

    final bytes = file.bytes;
    if (bytes == null) return null;

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }

    return parse(json);
  }

  static ImportedData? parse(Map<String, dynamic> json) {
    if (WorkspaceBundle.matchesSchema(json)) {
      final bundle = WorkspaceBundle.fromJson(json);
      return ImportedData(collections: bundle.collections, environments: bundle.environments);
    }
    if (PostmanImport.looksLikeCollection(json)) {
      return ImportedData(collections: [PostmanImport.parseCollection(json)]);
    }
    if (PostmanImport.looksLikeEnvironment(json)) {
      return ImportedData(environments: [PostmanImport.parseEnvironment(json)]);
    }
    return null;
  }
}

extension _SingleOrNull<T> on List<T> {
  T? get singleOrNull => length == 1 ? first : null;
}
