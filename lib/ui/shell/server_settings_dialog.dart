import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/remote/api_client.dart';
import '../../core/remote/auth/auth_state.dart';
import '../../core/remote/remote_api_exception.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/role_theme.dart';
import '../../state/auth_notifier.dart';
import '../../state/settings_providers.dart';
import '../widgets/widgets.dart';

/// Where to point this install at a role-node instance (§9 of
/// docs/08-ONLINE-MODE-INTEGRATION.md) — the one thing standing between a
/// fresh install and every other online-mode feature actually being
/// reachable. Reachable from the account menu whether signed in or out
/// (unlike everything under `lib/ui/auth|workspace/`, since signing in is
/// impossible until a base URL exists).
Future<void> showServerSettingsDialog(BuildContext context) {
  return showDialog<void>(context: context, builder: (context) => const _ServerSettingsDialog());
}

class _ServerSettingsDialog extends ConsumerStatefulWidget {
  const _ServerSettingsDialog();

  @override
  ConsumerState<_ServerSettingsDialog> createState() => _ServerSettingsDialogState();
}

class _ServerSettingsDialogState extends ConsumerState<_ServerSettingsDialog> {
  late final TextEditingController _controller;
  bool _checking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ref.read(remoteBaseUrlProvider) ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _messageFor(Object error) => error is RemoteApiException ? error.message : error.toString();

  Future<void> _save() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty) {
      await _disconnect();
      return;
    }

    final normalized = raw.replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(normalized);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https') || uri.host.isEmpty) {
      setState(() => _error = 'Enter a full URL, e.g. https://role.example.com');
      return;
    }

    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      await _checkHealth(normalized);
      // Tokens are scoped to whichever server was configured before —
      // best-effort, same as logout() already handles a server that's
      // unreachable or gone.
      if (ref.read(authNotifierProvider) is AuthSignedIn) {
        await ref.read(authNotifierProvider.notifier).logout();
      }
      await ref.read(remoteBaseUrlProvider.notifier).setRemoteBaseUrl(normalized);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not reach $normalized: ${_messageFor(error)}');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _disconnect() async {
    if (ref.read(authNotifierProvider) is AuthSignedIn) {
      await ref.read(authNotifierProvider.notifier).logout();
    }
    await ref.read(remoteBaseUrlProvider.notifier).setRemoteBaseUrl(null);
    if (mounted) Navigator.of(context).pop();
  }

  /// `GET /health` is mounted at the bare app root in role-node
  /// (`src/app.ts`), *not* under `/api/v1` like everything `RemoteApiClient`
  /// talks to — so this needs its own interceptor-free `Dio` pointed at the
  /// raw base URL, same pattern `AuthNotifier._rawRefresh` already uses.
  Future<void> _checkHealth(String baseUrl) async {
    final dio = Dio(
      BaseOptions(baseUrl: baseUrl, connectTimeout: AppConstants.defaultConnectTimeout, receiveTimeout: AppConstants.defaultReceiveTimeout),
    );
    try {
      final response = await dio.get('/health');
      parseEnvelope(response.data);
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasExisting = ref.watch(remoteBaseUrlProvider) != null;

    return AlertDialog(
      title: const Text('Server settings'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Point Röle at a self-hosted or hosted role-node instance to enable online mode. '
              'Leave this empty and save to disconnect.',
              style: context.type.body,
            ),
            const SizedBox(height: AppSpacing.sm),
            LabeledField(
              label: 'Server URL',
              child: TextField(
                controller: _controller,
                keyboardType: TextInputType.url,
                autofocus: true,
                decoration: const InputDecoration(isDense: true, hintText: 'https://role.example.com'),
                onSubmitted: (_) => _checking ? null : _save(),
              ),
            ),
            if (_error != null) ...[const SizedBox(height: AppSpacing.sm), Text(_error!, style: context.type.body.copyWith(color: colors.danger))],
          ],
        ),
      ),
      actions: [
        if (hasExisting) TextButton(onPressed: _checking ? null : _disconnect, child: const Text('Disconnect')),
        TextButton(onPressed: _checking ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        AppButton(label: _checking ? 'Checking…' : 'Save', variant: AppButtonVariant.primary, onPressed: _checking ? null : _save),
      ],
    );
  }
}
