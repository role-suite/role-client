import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpAppWithProviders(WidgetTester tester, {required Widget child}) async {
  await tester.pumpWidget(ProviderScope(child: child));
  await tester.pump();
}
