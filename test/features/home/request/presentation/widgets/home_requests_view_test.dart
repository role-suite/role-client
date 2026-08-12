import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/models/api_request_model.dart';
import 'package:relay/core/utils/extension.dart';
import 'package:relay/features/home/request/presentation/widgets/home_requests_view.dart';

ApiRequestModel _request() {
  final now = DateTime.now();
  return ApiRequestModel(
    id: 'r1',
    name: 'Get Users',
    method: HttpMethod.get,
    urlTemplate: 'https://api.example.com/users',
    collectionId: 'default',
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  testWidgets('renders a compact single-line row with run and edit actions', (tester) async {
    ApiRequestModel? tapped;
    ApiRequestModel? edited;
    final request = _request();

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: HomeRequestsView(
              requests: [request],
              onTapRequest: (r) => tapped = r,
              onEditRequest: (r) => edited = r,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Get Users'), findsOneWidget);
    expect(find.text('https://api.example.com/users'), findsOneWidget);
    expect(find.text('GET'), findsOneWidget);

    await tester.tap(find.byTooltip('Run'));
    expect(tapped?.id, 'r1');

    await tester.tap(find.byTooltip('Edit'));
    expect(edited?.id, 'r1');
  });
}
