/// API style for the remote workspace.
enum ApiStyle { rest }

extension ApiStyleX on ApiStyle {
  String get displayName => switch (this) {
    ApiStyle.rest => 'REST',
  };
}
