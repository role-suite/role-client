import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:relay/core/theme/app_theme.dart';
import 'package:relay/state/settings_providers.dart';
import 'package:relay/ui/auth/sign_in_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _harness(SharedPreferences prefs) {
  return ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: MaterialApp(
      theme: AppTheme.dark,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(onPressed: () => showSignInDialog(context), child: const Text('open')),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('asks for a role-node server before account creation when none is configured', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(_harness(prefs));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Connect to a server'), findsOneWidget);
    expect(find.text('Server URL'), findsOneWidget);
    expect(find.text('Create account'), findsNothing);
  });

  testWidgets('goes straight to sign-in when a server is already configured', (tester) async {
    SharedPreferences.setMockInitialValues({'settings.remoteBaseUrl': 'https://role.example.com'});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(_harness(prefs));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Connect to a server'), findsNothing);
    expect(find.text('Sign in'), findsWidgets);
  });
}
