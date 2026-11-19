import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/remote/server_health.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/role_theme.dart';
import '../../state/auth_notifier.dart';
import '../../state/settings_providers.dart';
import '../remote_error.dart';
import '../shell/server_settings_dialog.dart';
import '../widgets/widgets.dart';

/// Sign in / create account. Reachable only from the account menu — never a
/// gate in front of the rest of the app. Local-only users never see this.
Future<void> showSignInDialog(BuildContext context) {
  return showDialog<void>(context: context, builder: (context) => const _SignInDialog());
}

class _SignInDialog extends ConsumerStatefulWidget {
  const _SignInDialog();

  @override
  ConsumerState<_SignInDialog> createState() => _SignInDialogState();
}

class _SignInDialogState extends ConsumerState<_SignInDialog> {
  bool _isRegistering = false;
  bool _isTeam = false;
  bool _passwordVisible = false;
  bool _submitting = false;
  bool _checkingServer = false;
  String? _error;
  String? _serverError;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _teamNameController = TextEditingController();
  final _serverController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _teamNameController.dispose();
    _serverController.dispose();
    super.dispose();
  }

  /// Online mode is additive and optional, but it still needs somewhere to
  /// talk to. Gathering the server URL here (instead of letting account
  /// creation fail with a raw "no remote base URL configured" error) keeps the
  /// sign-in flow self-contained and understandable on a fresh install.
  Future<void> _connectServer() async {
    final normalized = normalizeRoleNodeBaseUrl(_serverController.text);
    if (normalized == null) {
      setState(() => _serverError = 'Enter the full server URL, e.g. https://role.example.com');
      return;
    }

    setState(() {
      _checkingServer = true;
      _serverError = null;
    });
    try {
      await checkRoleNodeHealth(normalized);
      await ref.read(remoteBaseUrlProvider.notifier).setRemoteBaseUrl(normalized);
    } catch (error) {
      if (mounted) setState(() => _serverError = remoteErrorMessage(error));
    } finally {
      if (mounted) setState(() => _checkingServer = false);
    }
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final notifier = ref.read(authNotifierProvider.notifier);
      if (_isRegistering) {
        await notifier.register(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          accountType: _isTeam ? 'team' : 'single',
          teamName: _isTeam ? _teamNameController.text.trim() : null,
        );
      } else {
        await notifier.login(email: _emailController.text.trim(), password: _passwordController.text);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) setState(() => _error = remoteErrorMessage(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseUrl = ref.watch(remoteBaseUrlProvider);

    if (baseUrl == null) {
      return AlertDialog(
        title: const Text('Connect to a server'),
        content: SizedBox(width: 360, child: _buildServerSetup(context)),
        actions: [
          TextButton(onPressed: _checkingServer ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
          AppButton(
            label: _checkingServer ? 'Checking…' : 'Connect',
            variant: AppButtonVariant.primary,
            onPressed: _checkingServer ? null : _connectServer,
          ),
        ],
      );
    }

    return AlertDialog(
      title: Text(_isRegistering ? 'Create account' : 'Sign in'),
      content: SizedBox(width: 340, child: _buildAuthForm(context, baseUrl)),
      actions: [
        TextButton(onPressed: _submitting ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        AppButton(label: _isRegistering ? 'Create account' : 'Sign in', variant: AppButtonVariant.primary, onPressed: _submitting ? null : _submit),
      ],
    );
  }

  Widget _buildServerSetup(BuildContext context) {
    final colors = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Röle works fully offline for requests, collections, environments, history, and flows — no account or server needed.',
          style: context.type.body,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Signing in and team workspaces connect to a role-node server. Enter the URL provided by your team or your self-hosted instance.',
          style: context.type.body,
        ),
        const SizedBox(height: AppSpacing.md),
        LabeledField(
          label: 'Server URL',
          child: TextField(
            controller: _serverController,
            keyboardType: TextInputType.url,
            autofocus: true,
            decoration: const InputDecoration(isDense: true, hintText: 'https://role.example.com'),
            onSubmitted: (_) => _checkingServer ? null : _connectServer(),
          ),
        ),
        if (_serverError != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(_serverError!, style: context.type.body.copyWith(color: colors.danger)),
        ],
      ],
    );
  }

  Widget _buildAuthForm(BuildContext context, String baseUrl) {
    final colors = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.dns_outlined, size: 13, color: colors.textMuted),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(baseUrl, style: context.type.caption, overflow: TextOverflow.ellipsis),
            ),
            TextButton(onPressed: _submitting ? null : () => showServerSettingsDialog(context), child: const Text('Change')),
          ],
        ),
        if (_isRegistering) ...[
          LabeledField(
            label: 'Name',
            child: TextField(controller: _nameController, decoration: const InputDecoration(isDense: true)),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        LabeledField(
          label: 'Email',
          child: TextField(controller: _emailController, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(isDense: true)),
        ),
        const SizedBox(height: AppSpacing.sm),
        LabeledField(
          label: 'Password',
          child: TextField(
            controller: _passwordController,
            obscureText: !_passwordVisible,
            decoration: InputDecoration(
              isDense: true,
              suffixIcon: IconButton(
                tooltip: _passwordVisible ? 'Hide password' : 'Show password',
                icon: Icon(_passwordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
              ),
            ),
          ),
        ),
        if (_isRegistering) ...[
          const SizedBox(height: AppSpacing.sm),
          CheckboxListTile(
            value: _isTeam,
            onChanged: (v) => setState(() => _isTeam = v ?? false),
            title: const Text('Team account'),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
          if (_isTeam) ...[
            LabeledField(
              label: 'Team name',
              child: TextField(controller: _teamNameController, decoration: const InputDecoration(isDense: true)),
            ),
          ],
        ],
        if (_error != null) ...[const SizedBox(height: AppSpacing.sm), Text(_error!, style: context.type.body.copyWith(color: colors.danger))],
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: _submitting ? null : () => setState(() => _isRegistering = !_isRegistering),
          child: Text(_isRegistering ? 'Already have an account? Sign in' : "Don't have an account? Create one"),
        ),
      ],
    );
  }
}
