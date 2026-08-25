import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/theme/role_theme.dart';
import '../../state/auth_notifier.dart';
import '../remote_error.dart';
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
  String? _error;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _teamNameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _teamNameController.dispose();
    super.dispose();
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
    final colors = context.colors;

    return AlertDialog(
      title: Text(_isRegistering ? 'Create account' : 'Sign in'),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isRegistering) ...[
              LabeledField(
                label: 'Name',
                child: TextField(controller: _nameController, decoration: const InputDecoration(isDense: true)),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            LabeledField(
              label: 'Email',
              child: TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(isDense: true),
              ),
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
        ),
      ),
      actions: [
        TextButton(onPressed: _submitting ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        AppButton(label: _isRegistering ? 'Create account' : 'Sign in', variant: AppButtonVariant.primary, onPressed: _submitting ? null : _submit),
      ],
    );
  }
}
