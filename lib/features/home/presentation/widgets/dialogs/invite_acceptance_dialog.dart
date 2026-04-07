import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/core/presentation/widgets/app_button.dart';
import 'package:relay/core/presentation/widgets/app_text_field.dart';
import 'package:relay/features/home/presentation/providers/data_source_providers.dart';
import 'package:relay/features/home/presentation/providers/workspace_team_providers.dart';
import 'package:relay/features/home/presentation/utils/api_auth_flow.dart';
import 'package:relay/core/utils/error_utils.dart';

enum InviteErrorType { expired, alreadyUsed, emailMismatch, generic }

class InviteAcceptanceDialog extends ConsumerStatefulWidget {
  const InviteAcceptanceDialog({super.key, this.initialToken});

  final String? initialToken;

  @override
  ConsumerState<InviteAcceptanceDialog> createState() => _InviteAcceptanceDialogState();
}

class _InviteAcceptanceDialogState extends ConsumerState<InviteAcceptanceDialog> {
  late final TextEditingController _tokenController;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tokenController = TextEditingController(text: widget.initialToken ?? '');
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _acceptInvite() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      setState(() {
        _errorMessage = 'Invite token is required.';
      });
      return;
    }

    final state = ref.read(currentDataSourceStateProvider);
    if (state == null || !state.config.isValid) {
      setState(() {
        _errorMessage = 'Configure API base URL before accepting invites.';
      });
      return;
    }

    if (!mounted) return;
    final ok = await ensureApiSourceAuthenticated(context, ref, state.config);
    if (!ok) {
      setState(() {
        _errorMessage = 'Sign in required to accept the invite.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final actions = ref.read(workspaceTeamActionsProvider);
      await actions.joinWorkspace(token: token);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      final mapped = _mapInviteError(e.toString());
      if (mounted) {
        setState(() {
          _errorMessage = mapped.message;
          _isSubmitting = false;
        });
      }
    }
  }

  _InviteError _mapInviteError(String message) {
    final normalized = message.toLowerCase();
    final status = _extractStatusCode(message);

    if (status == 410 || normalized.contains('expired')) {
      return const _InviteError(InviteErrorType.expired, 'This invite has expired. Request a new invite from the workspace owner.');
    }
    if (status == 403 || normalized.contains('email') || normalized.contains('mismatch')) {
      return const _InviteError(InviteErrorType.emailMismatch, 'This invite is for a different email address.');
    }
    if (status == 409 || normalized.contains('already') || normalized.contains('pending') || normalized.contains('member')) {
      return const _InviteError(InviteErrorType.alreadyUsed, 'This invite is already used or you are already a member.');
    }
    final cleaned = humanizeApiError(message);
    return _InviteError(InviteErrorType.generic, cleaned.isEmpty ? 'Failed to accept invite.' : cleaned);
  }

  int? _extractStatusCode(String message) {
    final match = RegExp(r'HTTP\s+(\d{3})').firstMatch(message);
    if (match == null) return null;
    return int.tryParse(match.group(1) ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Accept team invite'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              controller: _tokenController,
              label: 'Invite token',
              hint: 'Paste invite token',
              onChanged: (_) => setState(() {
                _errorMessage = null;
              }),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(_errorMessage!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        AppButton(label: _isSubmitting ? 'Accepting...' : 'Accept invite', icon: Icons.check, onPressed: _isSubmitting ? null : _acceptInvite),
      ],
    );
  }
}

class _InviteError {
  const _InviteError(this.type, this.message);

  final InviteErrorType type;
  final String message;
}
