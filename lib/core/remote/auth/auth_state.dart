import '../../models/auth_user.dart';
import '../../models/remote_workspace.dart';

/// `signedOut | signingIn | signedIn(user, workspaces, activeWorkspaceId)` per
/// §4 of docs/08-ONLINE-MODE-INTEGRATION.md.
sealed class AuthState {
  const AuthState();
}

class AuthSignedOut extends AuthState {
  const AuthSignedOut();
}

class AuthSigningIn extends AuthState {
  const AuthSigningIn();
}

class AuthSignedIn extends AuthState {
  const AuthSignedIn({required this.user, required this.workspaces, required this.activeWorkspaceId});

  final AuthUser user;
  final List<RemoteWorkspace> workspaces;
  final int activeWorkspaceId;

  RemoteWorkspace get activeWorkspace => workspaces.firstWhere((w) => w.id == activeWorkspaceId);
}
