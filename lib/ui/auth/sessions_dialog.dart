import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/auth_session.dart';
import '../../core/theme/role_theme.dart';
import '../../state/auth_notifier.dart';
import '../remote_error.dart';
import '../widgets/widgets.dart';

/// "Manage devices": lists the caller's active sessions
/// (`GET /api/v1/auth/sessions`) with per-row revoke and a bulk
/// "sign out everywhere else". Reachable only from the account menu.
Future<void> showSessionsDialog(BuildContext context) {
  return showDialog<void>(context: context, builder: (context) => const _SessionsDialog());
}

class _SessionsDialog extends ConsumerStatefulWidget {
  const _SessionsDialog();

  @override
  ConsumerState<_SessionsDialog> createState() => _SessionsDialogState();
}

class _SessionsDialogState extends ConsumerState<_SessionsDialog> {
  late Future<List<AuthSession>> _sessionsFuture;
  String? _error;

  @override
  void initState() {
    super.initState();
    _sessionsFuture = ref.read(authNotifierProvider.notifier).listSessions();
  }

  void _reload() => setState(() => _sessionsFuture = ref.read(authNotifierProvider.notifier).listSessions());

  Future<void> _revoke(int sessionId) async {
    try {
      await ref.read(authNotifierProvider.notifier).revokeSession(sessionId);
      _reload();
    } catch (error) {
      setState(() => _error = remoteErrorMessage(error));
    }
  }

  Future<void> _revokeOthers() async {
    try {
      await ref.read(authNotifierProvider.notifier).revokeOtherSessions();
      _reload();
    } catch (error) {
      setState(() => _error = remoteErrorMessage(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AlertDialog(
      title: const Text('Manage devices'),
      content: SizedBox(
        width: 420,
        height: 320,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null) Text(_error!, style: context.type.body.copyWith(color: colors.danger)),
            Expanded(
              child: FutureBuilder<List<AuthSession>>(
                future: _sessionsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Could not load sessions: ${remoteErrorMessage(snapshot.error!)}', style: context.type.body));
                  }
                  final sessions = snapshot.data ?? const [];
                  if (sessions.isEmpty) {
                    return Center(child: Text('No active sessions.', style: context.type.body));
                  }
                  return ListView.separated(
                    itemCount: sessions.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(session.workspaceName, style: context.type.body),
                        subtitle: Text(
                          session.current ? 'This device · expires ${_formatDate(session.expiresAt)}' : 'Expires ${_formatDate(session.expiresAt)}',
                          style: context.type.label,
                        ),
                        trailing: session.current
                            ? null
                            : AppIconButton(icon: Icons.logout, tooltip: 'Revoke this session', onPressed: () => _revoke(session.id)),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _revokeOthers, child: const Text('Sign out everywhere else')),
        AppButton(label: 'Close', onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }

  String _formatDate(DateTime date) => '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
