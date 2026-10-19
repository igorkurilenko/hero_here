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
    await tester.pumpWidget(const MaterialApp(home: ChatMessageExample()));
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
    await tester.pumpWidget(const MaterialApp(home: ChatMessageExample()));
    await tester.enterText(_input, 'Hel');

    // Rebuild the page, as a theme change while typing would.
    tester.element(find.byType(ChatMessageExample)).markNeedsBuild();
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(_input).controller!.text, 'Hel');
  });

  testWidgets('keeps the input focused on an Enter with nothing typed', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ChatMessageExample()));
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
    await tester.pumpWidget(const MaterialApp(home: ChatMessageExample()));
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
    await tester.pumpWidget(const MaterialApp(home: ChatMessageExample()));
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
    await tester.pumpWidget(const MaterialApp(home: ChatMessageExample()));
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

  testWidgets('moves the input above the keyboard without running a switch', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ChatMessageExample()));
    await tester.pumpAndSettle();
    addTearDown(tester.view.resetViewInsets);
    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;

    var switcherBuilds = 0;
    debugOnRebuildDirtyWidget = (element, _) {
      if (element.widget is HeroHereSwitcher) switcherBuilds++;
    };
    try {
      // The keyboard slides up over a few frames.
      for (final keyboard in [100.0, 200.0, 300.0]) {
        _showKeyboard(tester, keyboard);
        await tester.pump();
        expect(
          tester.getRect(_input).bottom,
          lessThanOrEqualTo(screenHeight - keyboard),
        );
      }
    } finally {
      debugOnRebuildDirtyWidget = null;
    }

    expect(switcherBuilds, 0);
  });

  testWidgets('keeps the newest message in view as the keyboard opens', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ChatMessageExample()));
    await _sendMessages(tester, 15);
    addTearDown(tester.view.resetViewInsets);
    final newest = find.descendant(
      of: find.byType(ListView),
      matching: find.text('Message 14'),
    );

    for (final keyboard in [100.0, 200.0, 300.0]) {
      _showKeyboard(tester, keyboard);
      await tester.pump();
      expect(
        tester.getRect(newest).bottom,
        lessThanOrEqualTo(tester.getRect(_input).top),
      );
    }
  });

  testWidgets('scrolls to a sent message as it flies, rather than jumping', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ChatMessageExample()));
    await _sendMessages(tester, 15);
    final previous = find.descendant(
      of: find.byType(ListView),
      matching: find.text('Message 14'),
    );
    final before = tester.getRect(previous).top;

    await tester.enterText(_input, 'Message 15');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump();
    expect(tester.getRect(previous).top, before);

    // The scroll starts after the frame of the send, as the flight does.
    await tester.pump();
    await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 2);
    final halfway = tester.getRect(previous).top;
    expect(halfway, lessThan(before));

    await tester.pumpAndSettle();
    expect(tester.getRect(previous).top, lessThan(halfway));
  });

  testWidgets('ends the list at the input on a screen with a home indicator', (
    tester,
  ) async {
    // How far the newest message ends above the input.
    Future<double> gap() async {
      await tester.pumpWidget(
        MaterialApp(key: UniqueKey(), home: const ChatMessageExample()),
      );
      await _sendMessages(tester, 15);
      final newest = find.descendant(
        of: find.byType(ListView),
        matching: find.text('Message 14'),
      );
      return tester.getRect(_input).top - tester.getRect(newest).bottom;
    }

    final withoutIndicator = await gap();
    tester.view.padding = FakeViewPadding(
      bottom: 34 * tester.view.devicePixelRatio,
    );
    addTearDown(tester.view.resetPadding);

    expect(await gap(), withoutIndicator);
  });

  testWidgets('keeps the messages in place as the keyboard opens while the '
      'list shows older ones', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ChatMessageExample()));
    await _sendMessages(tester, 15);
    addTearDown(tester.view.resetViewInsets);
    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pumpAndSettle();
    final older = find.descendant(
      of: find.byType(ListView),
      matching: find.text('Message 5'),
    );
    final before = tester.getRect(older).top;

    _showKeyboard(tester, 200);
    await tester.pumpAndSettle();

    expect(tester.getRect(older).top, before);
  });
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

/// Shows a keyboard [height] logical pixels tall over the test's view.
void _showKeyboard(WidgetTester tester, double height) =>
    tester.view.viewInsets = FakeViewPadding(
      bottom: height * tester.view.devicePixelRatio,
    );

/// Sends [count] messages, "Message 0" first, and waits for them to land.
Future<void> _sendMessages(WidgetTester tester, int count) async {
  for (var i = 0; i < count; i++) {
    await tester.enterText(_input, 'Message $i');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }
}
