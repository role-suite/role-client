import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:relay/core/theme/app_theme.dart';
import 'package:relay/state/settings_providers.dart';
import 'package:relay/ui/shell/status_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpStatusBar(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(bottomNavigationBar: StatusBar()),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('shows the running version and opens About on tap', (tester) async {
    PackageInfo.setMockInitialValues(appName: 'Röle', packageName: 'com.devora.relay', version: '1.1.2', buildNumber: '5', buildSignature: '');

    await _pumpStatusBar(tester);
    expect(find.text('Röle v1.1.2'), findsOneWidget);

    await tester.tap(find.text('Röle v1.1.2'));
    await tester.pumpAndSettle();
    expect(find.text('About Röle'), findsOneWidget);
  });

  testWidgets('falls back to the app name when the version is unavailable', (tester) async {
    PackageInfo.setMockInitialValues(appName: 'Röle', packageName: 'com.devora.relay', version: '', buildNumber: '', buildSignature: '');

    await _pumpStatusBar(tester);
    expect(find.text('Röle'), findsOneWidget);
  });
}
