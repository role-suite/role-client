import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/remote/api_client.dart';
import 'package:relay/core/remote/workspace/workspace_service.dart';

ResponseBody _jsonBody(Object body, int statusCode) => ResponseBody.fromString(
  jsonEncode(body),
  statusCode,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this._respond);
  final ResponseBody Function(RequestOptions options) _respond;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async => _respond(options);
}

WorkspaceService _serviceWith(ResponseBody Function(RequestOptions options) respond) {
  final dio = Dio(BaseOptions(baseUrl: 'https://role.example.com/api/v1'))..httpClientAdapter = _ScriptedAdapter(respond);
  return WorkspaceService(RemoteApiClient(baseUrl: 'https://role.example.com', dio: dio));
}

const _workspaceSummary = {'id': 2, '_id': 2, 'name': 'Platform Team', 'slug': 'platform-team', 'type': 'team', 'role': 'owner'};

void main() {
  test('createWorkspace POSTs the name and maps the workspace summary', () async {
    RequestOptions? sent;
    final service = _serviceWith((options) {
      sent = options;
      return _jsonBody({'success': true, 'data': _workspaceSummary}, 201);
    });

    final workspace = await service.createWorkspace('Platform Team');

    expect(sent!.method, 'POST');
    expect(sent!.path, '/workspaces');
    expect(sent!.data, {'name': 'Platform Team'});
    expect(workspace.id, 2);
    expect(workspace.type, 'team');
  });

  test('listMembers unwraps the {items} envelope', () async {
    final service = _serviceWith(
      (options) => _jsonBody({
        'success': true,
        'data': {
          'items': [
            {'userId': 1, 'name': 'Altay', 'email': 'altay@example.com', 'role': 'owner'},
            {'userId': 2, 'name': 'Core', 'email': 'core@example.com', 'role': 'member'},
          ],
        },
      }, 200),
    );

    final members = await service.listMembers(2);

    expect(members, hasLength(2));
    expect(members.first.role, 'owner');
  });

  test('createInvitation POSTs email+role and maps the token response', () async {
    RequestOptions? sent;
    final service = _serviceWith((options) {
      sent = options;
      return _jsonBody({
        'success': true,
        'data': {
          'id': 5,
          'workspaceId': 2,
          'email': 'invitee@example.com',
          'role': 'member',
          'token': 'raw-token',
          'expiresAt': '2026-08-01T10:00:00.000Z',
        },
      }, 201);
    });

    final invitation = await service.createInvitation(2, email: 'invitee@example.com');

    expect(sent!.path, '/workspaces/2/invitations');
    expect(sent!.data, {'email': 'invitee@example.com', 'role': 'member'});
    expect(invitation.token, 'raw-token');
  });

  test('join POSTs the token to the global join route', () async {
    RequestOptions? sent;
    final service = _serviceWith((options) {
      sent = options;
      return _jsonBody({'success': true, 'data': _workspaceSummary}, 200);
    });

    final workspace = await service.join('invite-token');

    expect(sent!.path, '/workspaces/join');
    expect(sent!.data, {'token': 'invite-token'});
    expect(workspace.id, 2);
  });

  test('updateMemberRole PATCHes the nested member route', () async {
    RequestOptions? sent;
    final service = _serviceWith((options) {
      sent = options;
      return _jsonBody({
        'success': true,
        'data': {'userId': 3, 'name': 'Someone', 'email': 'someone@example.com', 'role': 'admin'},
      }, 200);
    });

    final member = await service.updateMemberRole(2, 3, 'admin');

    expect(sent!.method, 'PATCH');
    expect(sent!.path, '/workspaces/2/members/3');
    expect(sent!.data, {'role': 'admin'});
    expect(member.role, 'admin');
  });

  test('removeMember/leave hit the expected routes', () async {
    final calls = <String>[];
    final service = _serviceWith((options) {
      calls.add('${options.method} ${options.path}');
      return _jsonBody({
        'success': true,
        'data': {'action': 'deleted'},
      }, 200);
    });

    await service.removeMember(2, 3);
    await service.leave(2);

    expect(calls, ['DELETE /workspaces/2/members/3', 'POST /workspaces/2/leave']);
  });

  test('convertToTeam POSTs an optional rename', () async {
    RequestOptions? sent;
    final service = _serviceWith((options) {
      sent = options;
      return _jsonBody({
        'success': true,
        'data': {..._workspaceSummary, 'type': 'team'},
      }, 200);
    });

    await service.convertToTeam(2, name: 'New Name');
    expect(sent!.data, {'name': 'New Name'});

    await service.convertToTeam(2);
    expect(sent!.data, <String, dynamic>{});
  });
}
