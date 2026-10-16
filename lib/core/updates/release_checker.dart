import 'package:dio/dio.dart';

import '../constants.dart';

/// Latest stable GitHub release for this repository, as returned by the
/// public releases API.
class ReleaseInfo {
  const ReleaseInfo({required this.tagName, required this.htmlUrl, required this.name, required this.body, this.publishedAt});

  final String tagName;
  final String htmlUrl;
  final String name;
  final String body;
  final DateTime? publishedAt;

  static ReleaseInfo? tryParse(Map<String, dynamic> json) {
    final tag = json['tag_name'];
    final url = json['html_url'];
    if (tag is! String || tag.isEmpty || url is! String || url.isEmpty) return null;
    final name = json['name'];
    final body = json['body'];
    final publishedAt = json['published_at'];
    return ReleaseInfo(
      tagName: tag,
      htmlUrl: url,
      name: name is String && name.isNotEmpty ? name : tag,
      body: body is String ? body : '',
      publishedAt: publishedAt is String ? DateTime.tryParse(publishedAt) : null,
    );
  }
}

class ReleaseCheckException implements Exception {
  const ReleaseCheckException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Fetches the repository's latest stable GitHub release — the single outbound
/// call Röle makes outside the user's own endpoints and role-node. It runs
/// only when the user clicks "Check for updates" in About, or opts into the
/// daily automatic check (default off), so the local-only promise holds for
/// anyone who never asks.
class ReleaseChecker {
  ReleaseChecker({Dio? dio})
    : _dio = dio ?? Dio(BaseOptions(connectTimeout: AppConstants.defaultConnectTimeout, receiveTimeout: AppConstants.defaultReceiveTimeout));

  static const String latestReleaseUrl = 'https://api.github.com/repos/role-suite/role-client/releases/latest';

  final Dio _dio;

  Future<ReleaseInfo> fetchLatest() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        latestReleaseUrl,
        options: Options(
          headers: const {
            'Accept': 'application/vnd.github+json',
            // GitHub's API rejects requests that don't send a User-Agent.
            'User-Agent': 'role-client',
          },
        ),
      );
      final data = response.data;
      final release = data == null ? null : ReleaseInfo.tryParse(data);
      if (release == null) {
        throw const ReleaseCheckException('GitHub returned an unexpected response.');
      }
      return release;
    } on DioException catch (error) {
      throw ReleaseCheckException(_messageFor(error));
    }
  }

  static String _messageFor(DioException error) {
    final status = error.response?.statusCode;
    if (status == 403 || status == 429) {
      return 'GitHub rate limit reached. Try again later.';
    }
    if (status != null) {
      return 'GitHub request failed ($status).';
    }
    return 'Could not reach GitHub. Check your connection and try again.';
  }
}
