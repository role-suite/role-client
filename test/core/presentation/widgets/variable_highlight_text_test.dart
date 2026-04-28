import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/presentation/widgets/variable_highlight_text.dart';

void main() {
  Widget app(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  testWidgets('renders plain Text when there are no placeholders', (tester) async {
    await tester.pumpWidget(app(const VariableHighlightText(text: 'Hello world')));

    expect(find.byType(Text), findsOneWidget);
    expect(find.byType(SelectableText), findsNothing);
    expect(find.text('Hello world'), findsOneWidget);
  });

  testWidgets('renders SelectableText when selectable is true and no placeholders', (tester) async {
    await tester.pumpWidget(app(const VariableHighlightText(text: 'Copy me', selectable: true)));

    expect(find.byType(SelectableText), findsOneWidget);
    expect(find.text('Copy me'), findsOneWidget);
  });

  testWidgets('renders highlighted spans for placeholders', (tester) async {
    await tester.pumpWidget(app(const VariableHighlightText(text: 'GET {{baseUrl}}/users/{{id}}')));

    final richText = tester.widget<RichText>(find.byType(RichText));
    final rootSpan = richText.text as TextSpan;
    final spans = rootSpan.children!.cast<TextSpan>();

    expect(spans.map((span) => span.text).toList(), ['GET ', '{{baseUrl}}', '/users/', '{{id}}']);
    expect(spans[1].style?.fontWeight, FontWeight.w600);
    expect(spans[3].style?.fontWeight, FontWeight.w600);
  });
}
