import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('switches the hero from red to green', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HeroHereExample()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey(HeroType.red)), findsOneWidget);
    expect(find.byKey(const ValueKey(HeroType.green)), findsNothing);

    await tester.tap(find.byIcon(Icons.radio_button_off));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey(HeroType.red)), findsNothing);
    expect(find.byKey(const ValueKey(HeroType.green)), findsOneWidget);
  });
}
