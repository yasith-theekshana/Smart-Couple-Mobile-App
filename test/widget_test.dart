import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_couple/main.dart';

Future<void> openTab(WidgetTester tester, int index) async {
  await tester.tap(find.byKey(ValueKey('nav-$index')));
  await tester.pumpAndSettle();
}

Future<void> press(WidgetTester tester, String label) async {
  final target = find.text(label);
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      180,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('React home and all five tabs render on a small phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const SmartCoupleApp());
    await tester.pumpAndSettle();
    expect(find.text('Florian & Sophie'), findsOneWidget);
    for (int i = 1; i < 5; i++) {
      await openTab(tester, i);
    }
    await openTab(tester, 0);
    await tester.tap(find.byKey(const ValueKey('profile')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('WELCOME'), findsOneWidget);
  });
  testWidgets('Shopping totals update and lists retain their items', (
    tester,
  ) async {
    await tester.pumpWidget(const SmartCoupleApp());
    await openTab(tester, 2);
    expect(find.text('19,45 €'), findsOneWidget);
    await press(tester, 'Ajouter au panier');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Article'),
      'Coffee',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Quantité'), '2');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Prix unitaire (€)'),
      '3,50',
    );
    await press(tester, 'Enregistrer');
    await tester.scrollUntilVisible(
      find.text('26,45 €'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('26,45 €'), findsOneWidget);
    await openTab(tester, 0);
    await openTab(tester, 2);
    await tester.scrollUntilVisible(
      find.text('Coffee'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Coffee'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('26,45 €'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('26,45 €'), findsOneWidget);
  });
  testWidgets('A task created in household appears on its calendar date', (
    tester,
  ) async {
    await tester.pumpWidget(const SmartCoupleApp());
    await openTab(tester, 4);
    await press(tester, 'Ajouter une tâche');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nom de la tâche'),
      'Evening walk',
    );
    await press(tester, 'Enregistrer');
    await openTab(tester, 3);
    final target = find.text('Evening walk');
    await tester.scrollUntilVisible(
      target,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(target, findsOneWidget);
  });
  testWidgets('Expenses validate amounts and update the shared balance', (
    tester,
  ) async {
    await tester.pumpWidget(const SmartCoupleApp());
    await openTab(tester, 1);
    expect(find.text('4372,51 €'), findsWidgets);
    await press(tester, 'Nouvelle dépense');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Description'),
      'Dinner',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Montant (€)'),
      '-10',
    );
    await press(tester, 'Enregistrer');
    expect(find.text('Entrez un montant valide'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Montant (€)'),
      '50',
    );
    await press(tester, 'Enregistrer');
    expect(find.text('4322,51 €'), findsWidgets);
  });
}
