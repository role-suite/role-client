/// Whether the remote workspace API is REST (GET/PUT) or Serverpod RPC.
enum ApiStyle {
  rest,
  serverpod,
}

extension ApiStyleX on ApiStyle {
  String get displayName => switch (this) {
        ApiStyle.rest => 'REST',
        ApiStyle.serverpod => 'Serverpod RPC',
      };
}
