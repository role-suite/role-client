import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/models/request_result.dart';
import 'package:relay/core/theme/app_theme.dart';
import 'package:relay/ui/widgets/response_body_view.dart';

RequestResult _result(String body) => RequestResult(ok: true, statusCode: 200, body: body, duration: const Duration(milliseconds: 1));

Future<void> _pumpView(WidgetTester tester, RequestResult result, {int? maxPrettyChars, int? maxDisplayChars}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: SizedBox(
          height: 300,
          child: ResponseBodyView(result: result, maxPrettyChars: maxPrettyChars ?? 2 * 1024 * 1024, maxDisplayChars: maxDisplayChars ?? 512 * 1024),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders pretty-printed JSON bodies', (tester) async {
    await _pumpView(tester, _result('{"a":1,"b":[1,2]}'));

    expect(find.text('  "a": 1,'), findsOneWidget);
    expect(find.text('    1,'), findsOneWidget);
    expect(find.byTooltip('Copy full body'), findsOneWidget);
  });

  testWidgets('shows a hint instead of a blank tab for empty bodies', (tester) async {
    await _pumpView(tester, RequestResult(ok: true, statusCode: 204, duration: Duration.zero));
    expect(find.text('No response body.'), findsOneWidget);
  });

  testWidgets('skips pretty-printing above the size limit and says so', (tester) async {
    await _pumpView(tester, _result('x' * 300), maxPrettyChars: 100);

    expect(find.textContaining('pretty-printing is disabled above 100 B'), findsOneWidget);
    expect(find.text('x' * 300), findsOneWidget);
  });

  testWidgets('caps the rendered text and copies the full body', (tester) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    final body = 'y' * 5000;
    await _pumpView(tester, _result(body), maxDisplayChars: 1000);

    expect(find.textContaining('showing the first 1000 B'), findsOneWidget);
    expect(find.text('y' * 5000), findsNothing);

    await tester.tap(find.byTooltip('Copy full body'));
    await tester.pump();

    final copy = calls.firstWhere((call) => call.method == 'Clipboard.setData');
    expect((copy.arguments as Map)['text'], body);
  });

  testWidgets('hard-wraps very long single lines so no text blob is huge', (tester) async {
    await _pumpView(tester, _result('z' * 5000), maxDisplayChars: 10000);

    final texts = tester
        .widgetList<Text>(find.descendant(of: find.byType(ResponseBodyView), matching: find.byType(Text)))
        .map((text) => text.data ?? '')
        .where((text) => text.isNotEmpty)
        .toList();
    expect(texts, isNotEmpty);
    expect(texts.every((text) => text.length <= 2000), isTrue, reason: 'each built line must be a bounded chunk');
    expect(('z' * 5000).startsWith(texts.join()), isTrue, reason: 'the built chunks are a prefix of the body');
  });

  testWidgets('keeps the end of a long body reachable by scrolling', (tester) async {
    final lines = List.generate(400, (index) => 'line $index');
    lines.add('END-MARKER');
    await _pumpView(tester, _result(lines.join('\n')), maxDisplayChars: 1024 * 1024);

    expect(find.text('END-MARKER'), findsNothing);
    await tester.scrollUntilVisible(find.text('END-MARKER'), 300);
    expect(find.text('END-MARKER'), findsOneWidget);
  });
}
