import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/constants/data_source_mode.dart';
import 'package:relay/core/models/data_source_config.dart';
import 'package:relay/core/models/user_profile_model.dart';
import 'package:relay/features/home/presentation/profile_screen.dart';
import 'package:relay/features/home/presentation/providers/data_source_providers.dart';
import 'package:relay/features/home/presentation/providers/profile_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows signed out account prompt when token is missing', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dataSourceStateNotifierProvider.overrideWith(_SignedOutDataSourceNotifier.new),
          userProfileProvider.overrideWith(_ProfileNotifier.new),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Sign in to view your profile details.'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('shows profile details when authenticated', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dataSourceStateNotifierProvider.overrideWith(_SignedInDataSourceNotifier.new),
          userProfileProvider.overrideWith(_ProfileNotifier.new),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.text('ada@example.com'), findsOneWidget);
    expect(find.text('team'), findsOneWidget);
    expect(find.text('Platform'), findsOneWidget);
  });
}

class _SignedOutDataSourceNotifier extends DataSourceStateNotifier {
  @override
  Future<({DataSourceMode mode, DataSourceConfig config})> build() async {
    return (mode: DataSourceMode.local, config: const DataSourceConfig(baseUrl: ''));
  }
}

class _SignedInDataSourceNotifier extends DataSourceStateNotifier {
  @override
  Future<({DataSourceMode mode, DataSourceConfig config})> build() async {
    return (mode: DataSourceMode.api, config: const DataSourceConfig(baseUrl: 'https://api.example.com', apiKey: 'token-1'));
  }
}

class _ProfileNotifier extends UserProfileNotifier {
  @override
  Future<UserProfileModel?> build() async {
    return UserProfileModel(
      id: 'u-1',
      name: 'Ada Lovelace',
      email: 'ada@example.com',
      accountType: 'team',
      teamName: 'Platform',
      createdAt: DateTime(2024, 1, 1),
    );
  }
}
