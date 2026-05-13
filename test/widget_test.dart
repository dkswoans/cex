import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xx/main.dart';

void main() {
  testWidgets('shows cheap concept login page', (WidgetTester tester) async {
    await tester.pumpWidget(const ApdoApp());

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('압도정진\n올라잇삼창돌격'), findsOneWidget);
    expect(find.text('기구 예약 시스템 맞음'), findsOneWidget);
    expect(find.text('입 장 ㄱㄱ'), findsOneWidget);
  });
}
