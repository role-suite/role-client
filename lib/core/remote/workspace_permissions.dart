const remoteWorkspaceReadOnlyMessage = 'Only workspace owners and admins can modify this workspace.';

bool canWriteRemoteWorkspaceRole(String? role) => role == 'owner' || role == 'admin';
