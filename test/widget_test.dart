import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_couple/main.dart';

void main() {
  testWidgets('Check in and manage a plan', (tester) async {
    await tester.pumpWidget(const SmartCoupleApp());
    await tester.tap(find.text('Happy'));
    await tester.pump();
    expect(find.textContaining('Today you feel happy'), findsOneWidget);
    await tester.tap(find.text('Our plans'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add plan'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Evening walk');
    await tester.tap(find.widgetWithText(FilledButton, 'Add plan'));
    await tester.pumpAndSettle();
    expect(find.text('Evening walk'), findsOneWidget);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(find.text('1 of 1 complete'), findsOneWidget);
    await tester.tap(find.byTooltip('Delete plan'));
    await tester.pump();
    expect(find.text('Evening walk'), findsNothing);
  });
}
