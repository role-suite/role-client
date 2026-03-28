import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/core/constants/data_source_mode.dart';
import 'package:relay/core/models/data_source_config.dart';
import 'package:relay/core/presentation/widgets/app_button.dart';
import 'package:relay/core/presentation/widgets/app_text_field.dart';
import 'package:relay/core/services/role_node_api/auth_api_client.dart';
import 'package:relay/features/home/presentation/providers/providers.dart';

enum _AuthMode { signIn, register }

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, this.initialConfig});

  final DataSourceConfig? initialConfig;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  late final TextEditingController _baseUrlController;
  late final TextEditingController _nameController;
  late final TextEditingController _teamNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;

  _AuthMode _mode = _AuthMode.signIn;
  String _accountType = 'single';
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController(text: widget.initialConfig?.baseUrl ?? '');
    _nameController = TextEditingController();
    _teamNameController = TextEditingController();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _nameController.dispose();
    _teamNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final baseUrl = _baseUrlController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (baseUrl.isEmpty) {
      setState(() => _error = 'Base URL is required');
      return;
    }
    if (email.isEmpty) {
      setState(() => _error = 'Email is required');
      return;
    }
    if (password.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters');
      return;
    }

    if (_mode == _AuthMode.register) {
      if (_nameController.text.trim().length < 2) {
        setState(() => _error = 'Name must be at least 2 characters');
        return;
      }
      if (_accountType == 'team' && _teamNameController.text.trim().length < 2) {
        setState(() => _error = 'Team name must be at least 2 characters');
        return;
      }
      if (_confirmPasswordController.text != password) {
        setState(() => _error = 'Passwords do not match');
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final authApi = AuthApiClient(baseUrl: baseUrl);
      final response = _mode == _AuthMode.signIn
          ? await authApi.login(email: email, password: password)
          : await authApi.register(
              name: _nameController.text.trim(),
              email: email,
              password: password,
              accountType: _accountType,
              teamName: _accountType == 'team' ? _teamNameController.text.trim() : null,
            );

      final accessToken = _extractToken(response, 'accessToken');
      if (accessToken == null || accessToken.isEmpty) {
        throw Exception('Access token missing in auth response');
      }
      final refreshToken = _extractToken(response, 'refreshToken');

      final config = DataSourceConfig(baseUrl: baseUrl, apiKey: accessToken, refreshToken: refreshToken);
      await ref.read(dataSourceStateNotifierProvider.notifier).setConfig(config);
      await ref.read(dataSourceStateNotifierProvider.notifier).setMode(DataSourceMode.api);
      ref.invalidate(collectionsNotifierProvider);
      ref.invalidate(requestsNotifierProvider);
      ref.invalidate(environmentsNotifierProvider);
      ref.invalidate(activeEnvironmentNotifierProvider);
      ref.read(selectedCollectionIdProvider.notifier).select(null);
      await ref.read(activeEnvironmentNotifierProvider.notifier).setActiveEnvironment(null);
      ref.read(activeEnvironmentNameProvider.notifier).setActiveName(null);

      if (!mounted) return;
      Navigator.of(context).pop(config);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = _humanizeError(e);
          _isSubmitting = false;
        });
      }
    }
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

  String _humanizeError(Object error) {
    final message = error.toString();
    if (message.startsWith('Exception: ')) {
      return message.substring('Exception: '.length).trim();
    }
    return message;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Account authentication')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Sign in or create an account to get an access token for the Role backend.', style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 16),
                      SegmentedButton<_AuthMode>(
                        segments: const [
                          ButtonSegment<_AuthMode>(value: _AuthMode.signIn, label: Text('Sign in')),
                          ButtonSegment<_AuthMode>(value: _AuthMode.register, label: Text('Register')),
                        ],
                        selected: {_mode},
                        onSelectionChanged: (selection) {
                          final value = selection.first;
                          setState(() {
                            _mode = value;
                            _error = null;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: _baseUrlController,
                        label: 'Backend base URL',
                        hint: 'http://localhost:3000',
                        keyboardType: TextInputType.url,
                        onChanged: (_) => setState(() => _error = null),
                      ),
                      if (_mode == _AuthMode.register) ...[
                        const SizedBox(height: 12),
                        AppTextField(controller: _nameController, label: 'Name', hint: 'Jane Doe', onChanged: (_) => setState(() => _error = null)),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _accountType,
                          items: const [
                            DropdownMenuItem(value: 'single', child: Text('Single account')),
                            DropdownMenuItem(value: 'team', child: Text('Team account')),
                          ],
                          decoration: const InputDecoration(labelText: 'Account type', border: OutlineInputBorder()),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _accountType = value;
                              _error = null;
                            });
                          },
                        ),
                        if (_accountType == 'team') ...[
                          const SizedBox(height: 12),
                          AppTextField(
                            controller: _teamNameController,
                            label: 'Team name',
                            hint: 'Platform Team',
                            onChanged: (_) => setState(() => _error = null),
                          ),
                        ],
                      ],
                      const SizedBox(height: 12),
                      AppTextField(
                        controller: _emailController,
                        label: 'Email',
                        hint: 'you@example.com',
                        keyboardType: TextInputType.emailAddress,
                        onChanged: (_) => setState(() => _error = null),
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        controller: _passwordController,
                        label: 'Password',
                        obscureText: _obscurePassword,
                        onChanged: (_) => setState(() => _error = null),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                        ),
                      ),
                      if (_mode == _AuthMode.register) ...[
                        const SizedBox(height: 12),
                        AppTextField(
                          controller: _confirmPasswordController,
                          label: 'Confirm password',
                          obscureText: _obscurePassword,
                          onChanged: (_) => setState(() => _error = null),
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
                      ],
                      const SizedBox(height: 16),
                      AppButton(
                        label: _mode == _AuthMode.signIn ? 'Sign in' : 'Create account',
                        icon: _mode == _AuthMode.signIn ? Icons.login : Icons.person_add_alt_1,
                        isLoading: _isSubmitting,
                        isFullWidth: true,
                        onPressed: _isSubmitting ? null : _submit,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
