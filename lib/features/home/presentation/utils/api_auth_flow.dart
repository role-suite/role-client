import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/core/models/data_source_config.dart';
import 'package:relay/core/services/relay_api/auth_api_client.dart';
import 'package:relay/features/home/presentation/auth_screen.dart';
import 'package:relay/features/home/presentation/providers/providers.dart';

Future<bool> ensureApiSourceAuthenticated(BuildContext context, WidgetRef ref, DataSourceConfig config) async {
  final authApi = AuthApiClient(baseUrl: config.baseUrl);
  final refreshToken = config.refreshToken?.trim();

  if (refreshToken != null && refreshToken.isNotEmpty) {
    try {
      final refreshed = await authApi.refresh(refreshToken);
      final accessToken = _extractToken(refreshed, 'accessToken');
      final nextRefreshToken = _extractToken(refreshed, 'refreshToken') ?? refreshToken;
      if (accessToken != null && accessToken.isNotEmpty) {
        await ref.read(dataSourceStateNotifierProvider.notifier).setConfig(config.copyWith(apiKey: accessToken, refreshToken: nextRefreshToken));
        return true;
      }
    } catch (_) {
      // Fall through to access token check and interactive sign in.
    }
  }

  final accessToken = config.apiKey?.trim();
  if (accessToken != null && accessToken.isNotEmpty) {
    try {
      await authApi.me(accessToken);
      return true;
    } catch (_) {
      // Fall through to interactive sign in.
    }
  }

  if (!context.mounted) return false;
  final result = await Navigator.of(context).push<DataSourceConfig>(MaterialPageRoute(builder: (_) => AuthScreen(initialConfig: config)));
  return result != null;
}

String? _extractToken(Map<String, dynamic> response, String key) {
  final tokens = response['tokens'];
  dynamic value;
  if (tokens is Map<String, dynamic>) {
    value = tokens[key];
  }
  value ??= response[key];
  final token = value?.toString().trim();
  if (token == null || token.isEmpty) return null;
  return token;
}
