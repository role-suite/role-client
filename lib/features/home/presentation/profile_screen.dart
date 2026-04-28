import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/core/constants/data_source_mode.dart';
import 'package:relay/core/models/user_profile_model.dart';
import 'package:relay/core/presentation/widgets/app_button.dart';
import 'package:relay/core/utils/error_utils.dart';
import 'package:relay/features/home/presentation/providers/data_source_providers.dart';
import 'package:relay/features/home/presentation/providers/profile_providers.dart';
import 'package:relay/features/home/presentation/utils/api_auth_flow.dart';
import 'package:relay/features/home/presentation/widgets/dialogs/data_source_config_dialog.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isBusy = false;

  Future<bool> _ensureAuthenticated() async {
    final state = ref.read(currentDataSourceStateProvider);
    if (state == null || !state.config.isValid) {
      _showSnack('Configure API base URL first.');
      return false;
    }
    if (!mounted) return false;
    final ok = await ensureApiSourceAuthenticated(context, ref, state.config);
    if (!ok) {
      _showSnack('Sign in required to load your profile.');
    }
    return ok;
  }

  Future<void> _signIn() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      final ok = await _ensureAuthenticated();
      if (ok) {
        ref.invalidate(userProfileProvider);
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _configureApi() async {
    final state = ref.read(dataSourceStateNotifierProvider).asData?.value;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => DataSourceConfigDialog(initialConfig: state?.config),
    );
    ref.invalidate(userProfileProvider);
  }

  Future<void> _logout() async {
    final confirmed = await _confirmDialog(
      title: 'Sign out',
      message: 'You will be switched back to local mode after signing out.',
      confirmLabel: 'Sign out',
      isDestructive: true,
    );
    if (!confirmed) return;
    setState(() => _isBusy = true);
    try {
      await ref.read(profileActionsProvider).logout();
      if (mounted) {
        _showSnack('Signed out.');
      }
    } catch (e) {
      if (mounted) {
        _showSnack(_humanizeError(e), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<bool> _confirmDialog({required String title, required String message, required String confirmLabel, bool isDestructive = false}) async {
    if (!mounted) return false;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: isDestructive ? Theme.of(context).colorScheme.error : null),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showSnack(String message, {bool isError = false}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(content: Text(message), backgroundColor: isError ? Theme.of(context).colorScheme.error : null));
  }

  String _humanizeError(Object error) {
    return humanizeApiError(error);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dataSourceAsync = ref.watch(dataSourceStateNotifierProvider);
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            onPressed: _isBusy
                ? null
                : () {
                    ref.invalidate(userProfileProvider);
                  },
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colorScheme.secondaryContainer.withValues(alpha: 0.25), colorScheme.surface],
          ),
        ),
        child: SafeArea(
          child: dataSourceAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text(_humanizeError(error))),
            data: (state) {
              final config = state.config;
              final isApiConfigured = config.isValid;
              final hasToken = config.apiKey?.trim().isNotEmpty ?? false;
              final isApiMode = state.mode == DataSourceMode.api;

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                children: [
                  _ProfileHero(hasToken: hasToken, isApiMode: isApiMode),
                  const SizedBox(height: 14),
                  _ProfileSectionCard(
                    icon: Icons.hub_outlined,
                    title: 'Connection',
                    subtitle: 'Data source configuration and auth state',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isApiConfigured ? 'Base URL: ${config.baseUrl}' : 'API base URL is not configured.', style: theme.textTheme.bodyMedium),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Chip(
                              avatar: Icon(isApiMode ? Icons.cloud_done_outlined : Icons.phone_android_outlined, size: 16),
                              label: Text(isApiMode ? 'API mode' : 'Local mode'),
                            ),
                            Chip(
                              avatar: Icon(hasToken ? Icons.verified_user_outlined : Icons.lock_outline, size: 16),
                              label: Text(hasToken ? 'Authenticated' : 'Signed out'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        AppButton(
                          label: _isBusy ? 'Opening...' : 'Configure API',
                          icon: Icons.settings,
                          isFullWidth: true,
                          onPressed: _isBusy ? null : _configureApi,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ProfileSectionCard(
                    icon: Icons.person_outline,
                    title: 'Account',
                    subtitle: 'Your profile details and identity',
                    child: !hasToken
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Sign in to view your profile details.', style: theme.textTheme.bodyMedium),
                              const SizedBox(height: 12),
                              AppButton(
                                label: _isBusy ? 'Signing in...' : 'Sign in',
                                icon: Icons.login,
                                isFullWidth: true,
                                onPressed: _isBusy ? null : _signIn,
                              ),
                            ],
                          )
                        : profileAsync.when(
                            data: (profile) => _ProfileDetails(profile: profile),
                            loading: () => const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                            ),
                            error: (error, _) =>
                                Text(_humanizeError(error), style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error)),
                          ),
                  ),
                  const SizedBox(height: 12),
                  _ProfileSectionCard(
                    icon: Icons.shield_outlined,
                    title: 'Security',
                    subtitle: 'Session controls for this device',
                    isDanger: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sign out of the current account and switch to local mode.', style: theme.textTheme.bodyMedium),
                        const SizedBox(height: 12),
                        AppButton(
                          label: _isBusy ? 'Signing out...' : 'Sign out',
                          icon: Icons.logout,
                          variant: AppButtonVariant.danger,
                          isFullWidth: true,
                          onPressed: _isBusy || !hasToken ? null : _logout,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.hasToken, required this.isApiMode});

  final bool hasToken;
  final bool isApiMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(colors: [colorScheme.secondary.withValues(alpha: 0.18), colorScheme.primary.withValues(alpha: 0.12)]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: colorScheme.surface,
                child: Icon(Icons.manage_accounts_outlined, color: colorScheme.primary),
              ),
              const SizedBox(width: 10),
              Text('Your Profile', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          Text('Keep your account, connection, and workspace identity organized in one place.', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text(isApiMode ? 'Connected mode' : 'Offline mode')),
              Chip(label: Text(hasToken ? 'Session active' : 'Session required')),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileSectionCard extends StatelessWidget {
  const _ProfileSectionCard({required this.icon, required this.title, required this.subtitle, required this.child, this.isDanger = false});

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = isDanger ? colorScheme.error : colorScheme.secondary;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: accent.withValues(alpha: 0.16)),
                  child: Icon(icon, size: 18, color: accent),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _ProfileDetails extends StatelessWidget {
  const _ProfileDetails({required this.profile});

  final UserProfileModel? profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = profile;
    if (p == null) {
      return Text('Profile information is unavailable.', style: theme.textTheme.bodySmall);
    }
    final createdAt = p.createdAt;
    final createdLabel = createdAt == null ? 'Unknown' : '${createdAt.year}-${_two(createdAt.month)}-${_two(createdAt.day)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoRow(label: 'Name', value: p.displayName),
        _InfoRow(label: 'Email', value: p.email.isEmpty ? 'Not provided' : p.email),
        _InfoRow(label: 'Account type', value: p.accountType.isEmpty ? 'Unknown' : p.accountType),
        if (p.teamName.trim().isNotEmpty) _InfoRow(label: 'Team', value: p.teamName),
        _InfoRow(label: 'Member since', value: createdLabel),
      ],
    );
  }

  static String _two(int value) => value < 10 ? '0$value' : value.toString();
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}
