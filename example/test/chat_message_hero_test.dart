import 'package:example/chat_message_hero/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _input = find.byWidgetPredicate(
  (widget) => widget is TextField && !widget.readOnly,
);

void main() {
  testWidgets('sends a message into the list and clears the input', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HeroHereExample()));
    await tester.enterText(_input, 'Hello');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: find.byType(ListView), matching: find.text('Hello')),
      findsOneWidget,
    );
    expect(tester.widget<TextField>(_input).controller!.text, isEmpty);
  });

  testWidgets('keeps the typed text when the page rebuilds', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HeroHereExample()));
    await tester.enterText(_input, 'Hel');

    // Rebuild the page, as a theme change while typing would.
    tester.element(find.byType(HeroHereExample)).markNeedsBuild();
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(_input).controller!.text, 'Hel');
  });
}
