import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/features/auth/presentation/providers/auth_providers.dart';
import 'package:relay_server_client/relay_server_client.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';

/// Email sign-in / register screen for Serverpod backend.
class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signInUiState = ref.watch(serverpodSignInUiStateProvider);
    final isServerpod = signInUiState != ServerpodSignInUiState.unavailable;
    final refreshClient = ref.read(refreshServerpodSignInClientProvider);

    if (!isServerpod) {
      return Scaffold(
        body: _GradientBackground(
          child: SafeArea(
            child: _CenteredCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.settings_suggest_rounded, size: 48, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8)),
                  const SizedBox(height: 16),
                  Text(
                    'Sign in not available',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Switch to API mode and set Serverpod RPC with a valid base URL in data source settings.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded, size: 20),
                    label: const Text('Back'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final clientAsync = ref.watch(serverpodSignInClientProvider);

    return Scaffold(
      body: _GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _AppBarRow(onBack: () => Navigator.of(context).pop()),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: clientAsync.when(
                    data: (client) {
                      if (client == null) {
                        return _CenteredCard(
                          key: const ValueKey('failed'),
                          child: _ConnectionFailedContent(onBack: () => Navigator.of(context).pop(), onRetry: refreshClient),
                        );
                      }
                      return _SignInFormView(key: const ValueKey('form'), client: client);
                    },
                    loading: () => _CenteredCard(key: const ValueKey('loading'), child: _LoadingContent()),
                    error: (err, _) => _CenteredCard(
                      key: ValueKey('error-$err'),
                      child: _ErrorContent(error: err, onBack: () => Navigator.of(context).pop(), onRetry: refreshClient),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Soft gradient behind content (theme-aware).
class _GradientBackground extends StatelessWidget {
  const _GradientBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  theme.colorScheme.surface,
                  theme.colorScheme.surface.withValues(alpha: 0.98),
                  theme.colorScheme.primaryContainer.withValues(alpha: 0.08),
                ]
              : [theme.colorScheme.surface, theme.colorScheme.primaryContainer.withValues(alpha: 0.06), theme.colorScheme.surface],
        ),
      ),
      child: child,
    );
  }
}

/// Minimal top row with back and title.
class _AppBarRow extends StatelessWidget {
  const _AppBarRow({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            style: IconButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6)),
          ),
          const SizedBox(width: 12),
          Text('Sign in', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Centered, max-width card with padding and subtle elevation.
class _CenteredCard extends StatelessWidget {
  const _CenteredCard({super.key, required this.child});

  final Widget child;

  static const double _maxWidth = 420;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          child: child,
        ),
      ),
    );
  }
}

/// Loading spinner and label.
class _LoadingContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 2.5, color: theme.colorScheme.primary)),
          const SizedBox(height: 20),
          Text('Connecting…', style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// Error message and back button.
class _ErrorContent extends StatelessWidget {
  const _ErrorContent({required this.error, required this.onBack, required this.onRetry});

  final Object error;
  final VoidCallback onBack;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: 48, color: theme.colorScheme.error),
          const SizedBox(height: 16),
          Text(
            'Connection error',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded, size: 20), label: const Text('Back')),
              const SizedBox(width: 12),
              FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded, size: 20), label: const Text('Retry')),
            ],
          ),
        ],
      ),
    );
  }
}

/// Connection failed (null client).
class _ConnectionFailedContent extends StatelessWidget {
  const _ConnectionFailedContent({required this.onBack, required this.onRetry});

  final VoidCallback onBack;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.link_off_rounded, size: 48, color: theme.colorScheme.error),
          const SizedBox(height: 16),
          Text(
            'Could not connect to server',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded, size: 20), label: const Text('Back')),
              const SizedBox(width: 12),
              FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded, size: 20), label: const Text('Retry')),
            ],
          ),
        ],
      ),
    );
  }
}

/// Sign-in form: welcome line + card with EmailSignInWidget.
class _SignInFormView extends StatelessWidget {
  const _SignInFormView({super.key, required this.client});

  final Client client;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Text('Welcome back', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.5)),
              const SizedBox(height: 4),
              Text(
                'Sign in or create an account to continue',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 28),
              _FormCard(
                child: EmailSignInWidget(
                  client: client,
                  onAuthenticated: () {
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  onError: (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $error'), behavior: SnackBarBehavior.floating));
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Elevated card with blur and rounded corners for the form.
class _FormCard extends StatelessWidget {
  const _FormCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? theme.colorScheme.surface.withValues(alpha: 0.7) : theme.colorScheme.surface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2), width: 1),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.shadow.withValues(alpha: isDark ? 0.3 : 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(padding: const EdgeInsets.all(24), child: child),
        ),
      ),
    );
  }
}
