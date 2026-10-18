import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:example/chat_message_hero/main.dart';
import 'package:example/chat_message_hero/message_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hero_here/hero_here.dart';

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

  testWidgets('keeps the input focused on an Enter with nothing typed', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HeroHereExample()));
    await tester.enterText(_input, 'Hello');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(_input).focusNode!.hasFocus, isTrue);
  });

  testWidgets('keeps what is typed while a sent message sets off', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HeroHereExample()));
    await tester.enterText(_input, 'Hello');
    await tester.testTextInput.receiveAction(TextInputAction.done);

    // Typed before the next frame, as a quick typist would.
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'Hellob',
        selection: TextSelection.collapsed(offset: 6),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(_input).controller!.text, 'b');

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    final list = find.byType(ListView);
    expect(
      find.descendant(of: list, matching: find.text('Hello')),
      findsOneWidget,
    );
    expect(find.descendant(of: list, matching: find.text('b')), findsOneWidget);
  });

  testWidgets('keeps a sent message in the input until its shuttle shows it', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HeroHereExample()));
    await tester.enterText(_input, 'Hello');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    // Lands, and runs the scroll the send scheduled, even if a check fails.
    addTearDown(tester.pumpAndSettle);
    // What the input laid out on the last frame.
    String shown() =>
        tester.allRenderObjects.whereType<RenderEditable>().single.plainText;

    // The frame of the send, before the message flies.
    await tester.pump();
    expect(shown(), 'Hello');

    // The flight's first frame, with the message in the list hidden.
    await tester.pump(const Duration(milliseconds: 16));
    expect(shown(), isEmpty);
    expect(
      find.descendant(
        of: find.byType(HeroHereSwitcher),
        matching: find.text('Hello'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byType(ListView), matching: find.text('Hello')),
      findsNothing,
    );
  });

  testWidgets('shows a sent message as text, without a text field', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HeroHereExample()));
    await tester.enterText(_input, 'Hello');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final list = find.byType(ListView);
    expect(
      find.descendant(of: list, matching: find.text('Hello')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: list, matching: find.byType(EditableText)),
      findsNothing,
    );
  });

  for (final text in ['Hello', 'A message too long for one line' * 3]) {
    testWidgets(
      'paints a read-only message as a read-only text field paints it, '
      'for ${text.length} characters',
      (tester) async {
        const decoration = InputDecoration(
          border: OutlineInputBorder(borderSide: BorderSide.none),
        );
        final controller = TextEditingController(text: text);
        addTearDown(controller.dispose);
        const message = Key('message'), field = Key('field');
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 300,
                child: Column(
                  children: [
                    RepaintBoundary(
                      key: message,
                      child: MessageWidget.readOnly(
                        text: text,
                        decoration: decoration,
                      ),
                    ),
                    RepaintBoundary(
                      key: field,
                      child: TextField(
                        readOnly: true,
                        controller: controller,
                        decoration: decoration,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        expect(
          tester.getSize(find.byKey(message)),
          tester.getSize(find.byKey(field)),
        );
        expect(
          await _pixelsOf(tester, find.byKey(message)),
          await _pixelsOf(tester, find.byKey(field)),
        );
      },
    );
  }
}

Future<Uint8List> _pixelsOf(WidgetTester tester, Finder boundary) async {
  final render = tester.renderObject<RenderRepaintBoundary>(boundary);
  return (await tester.runAsync(() async {
    final image = await render.toImage();
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return bytes!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }))!;
}
