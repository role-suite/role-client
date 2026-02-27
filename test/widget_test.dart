import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:relay/features/home/presentation/providers/theme_providers.dart';
import 'test_helpers/pump_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Riverpod scope resolves app providers', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await pumpAppWithProviders(
      tester,
      child: Consumer(
        builder: (context, ref, _) {
          final themeMode = ref.watch(themeModeNotifierProvider);
          return Directionality(textDirection: TextDirection.ltr, child: Text(themeMode.name));
        },
      ),
    );

    expect(find.text('system'), findsOneWidget);
  });
}
