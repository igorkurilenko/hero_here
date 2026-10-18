import 'dart:math' as math;

import 'package:example/flip_card_hero/main.dart';
import 'package:example/show_details_hero/config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final everest = kEightThousanders.first;
  const cell = ValueKey('cell-0');
  const card = ValueKey('card-0');

  testWidgets('flips a card over as it flies open', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: FlipCardExample()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(cell));
    await tester.pump();
    // The flight shows from the frame after the switch.
    await tester.pump();

    var frontFrames = 0;
    var backFrames = 0;
    for (var frame = 0; frame < 100 && _flying(); frame++) {
      final name = find.descendant(
        of: _flip,
        matching: find.text(everest.name),
      );
      final showsBack = name.evaluate().isNotEmpty;
      // The back shows once the card turns past edge on.
      expect(showsBack, _turn(tester) > 0.5);
      if (showsBack) {
        backFrames++;
        // The right way round, though the card turned over.
        expect(
          tester.getTopLeft(name).dx,
          lessThan(tester.getTopRight(name).dx),
        );
      } else {
        frontFrames++;
      }
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(frontFrames, greaterThan(0));
    expect(backFrames, greaterThan(0));
    expect(_flying(), isFalse);
    expect(
      find.descendant(of: find.byKey(card), matching: find.text(everest.name)),
      findsOneWidget,
    );
  });

  testWidgets('carries a card past its place on a spring, and lands as it '
      'comes to rest', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: FlipCardExample()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(cell));
    await tester.pump();
    // The flight shows from the frame after the switch.
    await tester.pump();

    var widest = 0.0;
    var turnedFarthest = 0.0;
    var flown = Duration.zero;
    const frame = Duration(milliseconds: 16);
    for (var i = 0; i < 100 && _flying(); i++) {
      widest = math.max(widest, tester.getSize(_flip).width);
      turnedFarthest = math.max(turnedFarthest, _turn(tester));
      await tester.pump(frame);
      flown += frame;
    }

    final landed = tester.getSize(find.byKey(card));
    expect(widest, greaterThan(landed.width + 1));
    expect(turnedFarthest, greaterThan(1.01));
    // Rather than a while later, when the spring comes fully to rest: the
    // card takes no taps until its flight lands.
    expect(flown, lessThan(const Duration(milliseconds: 800)));
  });

  testWidgets('keeps the words of a card on their lines as it grows in '
      'flight', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: FlipCardExample()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(cell));
    await tester.pump();
    await tester.pump();

    final description = find.descendant(
      of: _flip,
      matching: find.text(everest.description),
    );
    final sizes = <Size>[];
    for (var frame = 0; frame < 100 && _flying(); frame++) {
      // Its size as laid out, before the flight scales it.
      if (description.evaluate().isNotEmpty) {
        sizes.add(tester.getSize(description));
      }
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(sizes, isNotEmpty);
    final landed = tester.getSize(
      find.descendant(
        of: find.byKey(card),
        matching: find.text(everest.description),
      ),
    );
    expect(sizes, everyElement(landed));
  });

  testWidgets('flies a card back onto its cell when tapped', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: FlipCardExample()));
    await tester.pumpAndSettle();
    final cellRect = tester.getRect(find.byKey(cell));
    await tester.tap(find.byKey(cell));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(card));
    await tester.pump();
    await tester.pump();
    expect(_flying(), isTrue);
    await tester.pumpAndSettle();

    expect(find.byKey(card), findsNothing);
    expect(tester.getRect(find.byKey(cell)), cellRect);
  });

  testWidgets('closes the card on a tap beside it', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: FlipCardExample()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(cell));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    expect(find.byKey(card), findsNothing);
    expect(find.byKey(cell), findsOneWidget);
  });

  testWidgets('turns a card back to its cell when closed mid-flight, after '
      'it carries on a little', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: FlipCardExample()));
    await tester.pumpAndSettle();
    final cellRect = tester.getRect(find.byKey(cell));
    await tester.tap(find.byKey(cell));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final turnedOnClose = _turn(tester);

    await tester.tapAt(const Offset(8, 8));
    await tester.pump();
    var turnedFarthest = turnedOnClose;
    for (var frame = 0; frame < 100 && _flying(); frame++) {
      turnedFarthest = math.max(turnedFarthest, _turn(tester));
      await tester.pump(const Duration(milliseconds: 16));
    }

    // It swings round at the speed it had, rather than stopping, and never
    // turns over.
    expect(turnedFarthest, greaterThan(turnedOnClose));
    expect(turnedFarthest, lessThan(1));
    expect(_flying(), isFalse);
    expect(find.byKey(card), findsNothing);
    expect(tester.getRect(find.byKey(cell)), cellRect);
  });

  for (final (where, window) in [
    ('', null),
    (' on a phone', const Size(402, 874)),
  ]) {
    testWidgets('decodes each photo sharp for its cell, and no taller than '
        'the largest cell$where', (tester) async {
      if (window != null) {
        tester.view.devicePixelRatio = 3;
        tester.view.physicalSize = window * 3;
        addTearDown(tester.view.reset);
      }
      await tester.pumpWidget(const MaterialApp(home: FlipCardExample()));
      await tester.pumpAndSettle();
      final ratio = tester.view.devicePixelRatio;

      final photos = find.descendant(
        of: find.byType(GridView),
        matching: find.byType(DecoratedBox),
      );
      expect(photos, findsWidgets);
      for (final photo in tester.widgetList<DecoratedBox>(photos)) {
        final image = (photo.decoration as BoxDecoration).image!.image;
        expect(image, isA<ResizeImage>());
        final height = (image as ResizeImage).height!;
        expect(
          height,
          greaterThanOrEqualTo(
            tester.getSize(find.byWidget(photo)).height * ratio,
          ),
        );
        expect(height, lessThanOrEqualTo((kMaxCellExtent * ratio).ceil()));
      }
    });
  }
}

/// The flight's card as it flips over, while one flies: the only transform
/// with perspective.
final _flip = find.byWidgetPredicate(
  (widget) =>
      widget is Transform &&
      (widget.transform.entry(3, 0) != 0 || widget.transform.entry(3, 2) != 0),
);

bool _flying() => _flip.evaluate().isNotEmpty;

/// How far over the flying card is turned, in half turns: 0 face up, 1
/// turned over.
double _turn(WidgetTester tester) {
  final transform = tester.widget<Transform>(_flip).transform;
  final angle = math.atan2(transform.entry(0, 2), transform.entry(0, 0));
  // Past a half turn, atan2 gives the angle less a whole turn.
  return (angle < -math.pi / 2 ? angle + 2 * math.pi : angle) / math.pi;
}
