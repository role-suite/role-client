import 'package:dio/dio.dart';

import '../constants.dart';

/// Latest stable GitHub release for this repository.
class ReleaseInfo {
  const ReleaseInfo({required this.tagName, required this.htmlUrl});

  final String tagName;
  final String htmlUrl;
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
///
/// The check follows GitHub's `/releases/latest` redirect instead of calling
/// `api.github.com`. The unauthenticated API shares a 60-requests/hour quota
/// per source IP, which produced spurious "rate limit reached" errors on
/// shared networks; the redirect is not API-limited.
class ReleaseChecker {
  ReleaseChecker({Dio? dio})
    : _dio = dio ?? Dio(BaseOptions(connectTimeout: AppConstants.defaultConnectTimeout, receiveTimeout: AppConstants.defaultReceiveTimeout));

  static const String latestReleaseUrl = 'https://github.com/role-suite/role-client/releases/latest';

  final Dio _dio;

  Future<ReleaseInfo> fetchLatest() async {
    try {
      final response = await _dio.get<void>(
        latestReleaseUrl,
        options: Options(
          followRedirects: false,
          validateStatus: (status) => status != null && status >= 200 && status < 400,
          headers: const {
            // GitHub's web endpoints also reject requests without a User-Agent.
            'User-Agent': 'role-client',
          },
        ),
      );

      final tag = _tagFromLocation(response.headers.value('location'));
      if (tag == null) {
        throw const ReleaseCheckException('GitHub returned an unexpected response.');
      }
      return ReleaseInfo(tagName: tag, htmlUrl: 'https://github.com/role-suite/role-client/releases/tag/$tag');
    } on DioException catch (error) {
      throw ReleaseCheckException(_messageFor(error));
    }
  }

  /// Extracts `vX.Y.Z` from a `.../releases/tag/vX.Y.Z` redirect target.
  static String? _tagFromLocation(String? location) {
    if (location == null || location.isEmpty) return null;
    final segments = Uri.tryParse(location)?.pathSegments ?? const <String>[];
    if (segments.length < 2 || segments[segments.length - 2] != 'tag') return null;
    final tag = segments.last;
    return tag.startsWith('v') ? tag : null;
  }

  static String _messageFor(DioException error) {
    final status = error.response?.statusCode;
    if (status == 429) {
      return 'GitHub is temporarily rate-limiting this network. Try again later.';
    }
    if (status == 403) {
      // Only claim rate limiting when GitHub's own headers say so; a 403 from
      // a proxy or an IP-level block is not a quota problem.
      final remaining = error.response?.headers.value('x-ratelimit-remaining');
      if (remaining == '0') {
        return 'GitHub is temporarily rate-limiting this network. Try again later.';
      }
      return 'GitHub refused the request (403). Try again later.';
    }
    if (status != null) {
      return 'GitHub request failed ($status).';
    }
    return 'Could not reach GitHub. Check your connection and try again.';
  }
}
