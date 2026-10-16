import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/models/request_result.dart';
import 'package:relay/core/theme/app_theme.dart';
import 'package:relay/ui/widgets/response_body_view.dart';

RequestResult _result(String body) => RequestResult(ok: true, statusCode: 200, body: body, duration: const Duration(milliseconds: 1));

String _pretty(String body) => const JsonEncoder.withIndent('  ').convert(jsonDecode(body));

Future<void> _pumpView(WidgetTester tester, RequestResult result) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: SizedBox(height: 300, child: ResponseBodyView(result: result)),
      ),
    ),
  );
}

int? _renderedLineCount(WidgetTester tester) {
  final listView = tester.widget<ListView>(find.byType(ListView));
  final delegate = listView.childrenDelegate as SliverChildBuilderDelegate;
  return delegate.estimatedChildCount;
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

  testWidgets('pretty-prints and fully indexes multi-megabyte bodies', (tester) async {
    final body = '[${List.generate(40000, (i) => '{"index": $i, "ad": "MELİS $i", "soyad": "BALCILAR $i"}').join(',')}]';
    expect(body.length, greaterThan(2 * 1024 * 1024), reason: 'the fixture must exceed the old pretty-print skip limit');

    await _pumpView(tester, _result(body));

    final expectedLines = _pretty(body).split('\n').length;
    expect(_renderedLineCount(tester), expectedLines, reason: 'every line of the full pretty body must be indexed');
    expect(find.textContaining('pretty-printing is disabled'), findsNothing);
    expect(find.textContaining('showing the first'), findsNothing);
  });

  testWidgets('copies the full pretty-printed body', (tester) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    final body = '{"a":1,"nested":{"b":[1,2,3],"c":"text"}}';
    await _pumpView(tester, _result(body));

    await tester.tap(find.byTooltip('Copy full body'));
    await tester.pump();

    final copy = calls.firstWhere((call) => call.method == 'Clipboard.setData');
    expect((copy.arguments as Map)['text'], _pretty(body));
  });

  testWidgets('hard-wraps very long single lines so no text blob is huge', (tester) async {
    await _pumpView(tester, _result('z' * 5000));

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
    await _pumpView(tester, _result(lines.join('\n')));

    expect(find.text('END-MARKER'), findsNothing);
    await tester.scrollUntilVisible(find.text('END-MARKER'), 300);
    expect(find.text('END-MARKER'), findsOneWidget);
  });
}
