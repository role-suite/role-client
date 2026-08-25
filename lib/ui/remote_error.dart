import 'package:flutter/material.dart';

import '../core/remote/remote_api_exception.dart';

String remoteErrorMessage(Object error) {
  if (error is! RemoteApiException) return error.toString();

  final fieldErrors = error.details?['fieldErrors'];
  if (fieldErrors is Map && fieldErrors.isNotEmpty) {
    final details = fieldErrors.entries.map((entry) => '${entry.key}: ${entry.value}').join('; ');
    return '${error.message} $details';
  }

  return error.message;
}

void showRemoteErrorSnackBar(BuildContext context, String prefix, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$prefix: ${remoteErrorMessage(error)}')));
}
