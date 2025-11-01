// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:misa_rin/app/app.dart';
import 'package:misa_rin/app/widgets/pen_tool_button.dart';

void main() {
  testWidgets('加载 misa rin 主界面', (WidgetTester tester) async {
    await tester.pumpWidget(const MisarinApp());

    expect(find.byType(FluentApp), findsOneWidget);
    expect(find.byType(PenToolButton), findsWidgets);
  });
}
