import 'dart:ui' as ui;

import 'package:example/show_details_hero/eight_thousander_details_hero.dart';
import 'package:example/show_details_hero/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hero_here/hero_here.dart';

void main() {
  testWidgets('switches once to open the details', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ShowDetailsExample()));
    await tester.pumpAndSettle();

    // Each switch takes one snapshot of the page.
    final snapshots = _countNewImages();
    await tester.tap(find.text('K2'));
    await tester.pump();

    // The back button waits for the flight.
    final back = find.widgetWithIcon(IconButton, Icons.chevron_left);
    expect(tester.widget<IconButton>(back).onPressed, isNull);

    await tester.pumpAndSettle();

    expect(snapshots(), 1);
    expect(tester.widget<IconButton>(back).onPressed, isNotNull);
  });

  testWidgets('keeps the back button when the page rebuilds', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ShowDetailsExample()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('K2'));
    await tester.pumpAndSettle();

    // Rebuild with the details still open, as on a window resize.
    tester.element(find.byType(ShowDetailsExample)).markNeedsBuild();
    await tester.pump();

    // A new back button would fade in over the old one fading out.
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
  });

  testWidgets('fades the back button out when the details close', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ShowDetailsExample()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('K2'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pump();
    await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 2);

    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
  });

  testWidgets('drags the details without rebuilding their text and image', (
    tester,
  ) async {
    // Tall enough to build the title and the description.
    tester.view.physicalSize = const Size(2400, 4800);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MaterialApp(home: ShowDetailsExample()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('K2'));
    await tester.pumpAndSettle();

    final imageWidth = tester.getSize(find.byType(AspectRatio)).width;
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(AspectRatio)),
    );
    await gesture.moveBy(const Offset(0, 20)); // Past the touch slop.
    await tester.pump();

    // Pull the details down past their top, slowly enough not to close.
    var rebuilds = 0;
    debugOnRebuildDirtyWidget = (element, _) {
      if (element.widget is Text || element.widget is Image) rebuilds++;
    };
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, 2));
      await tester.pump(const Duration(milliseconds: 16));
    }
    debugOnRebuildDirtyWidget = null;

    expect(rebuilds, 0);
    // The drag still shrinks the image and fades the text.
    expect(
      tester.getSize(find.byType(AspectRatio)).width,
      lessThan(imageWidth),
    );
    final opacities = find.descendant(
      of: find.byType(ListView),
      matching: find.byType(Opacity),
    );
    expect(opacities, findsNWidgets(2));
    for (final opacity in tester.widgetList<Opacity>(opacities)) {
      expect(opacity.opacity, lessThan(1));
    }

    await gesture.up();
    await tester.pumpAndSettle();
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('closes the details when flung down', (tester) async {
    // Tall enough to build the title and the description, so they fly too.
    tester.view.physicalSize = const Size(2400, 4800);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MaterialApp(home: ShowDetailsExample()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('K2'));
    await tester.pumpAndSettle();

    await tester.fling(find.byType(AspectRatio), const Offset(0, 200), 1000);
    await tester.pumpAndSettle();

    expect(find.byType(EightThousanderDetailsHero), findsNothing);
  });

  testWidgets('closes the details onto where the cell is after a resize', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ShowDetailsExample()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('K2'));
    await tester.pumpAndSettle();

    // A narrower window moves the cell.
    tester.view.physicalSize = const Size(1200, 1800);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.chevron_left));

    // While the cell is hidden, the image showing is the flight's shuttle.
    final image = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image == const AssetImage('assets/images/k2.jpeg'),
    );
    final cellImage = find.descendant(
      of: find.byType(GridView),
      matching: image,
    );
    Rect? shuttleRect;
    for (var frame = 0; frame < 40; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (tester.any(image) && !tester.any(cellImage)) {
        shuttleRect = tester.getRect(image);
      }
    }

    final cellRect = tester.getRect(cellImage);
    expect(
      (shuttleRect!.topLeft - cellRect.topLeft).distance,
      lessThan(10),
      reason: 'The shuttle landed at $shuttleRect, the cell is at $cellRect.',
    );
  });

  testWidgets('shows the scrollbars at the window edge', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ShowDetailsExample()));
    await tester.pumpAndSettle();

    Rect scrollbarOf(Type scrollView) => tester.getRect(
      find.descendant(
        of: find.byType(scrollView),
        matching: find.byType(Scrollbar),
      ),
    );
    expect(scrollbarOf(GridView).right, 800);
    // The grid stays in the middle column.
    expect(tester.getRect(find.text('Mount Everest')).left, 128);

    await tester.tap(find.text('K2'));
    await tester.pumpAndSettle();

    expect(scrollbarOf(ListView).right, 800);
    // So do the details.
    expect(tester.getRect(find.byType(AspectRatio)).left, 120);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}

/// Counts the `ui.Image`s created from now until the end of the test, leaving
/// out clones of them.
int Function() _countNewImages() {
  final images = <ui.Image>[];
  final onCreate = ui.Image.onCreate;
  ui.Image.onCreate = (image) {
    if (!images.any(image.isCloneOf)) images.add(image);
    onCreate?.call(image);
  };
  addTearDown(() => ui.Image.onCreate = onCreate);
  return () => images.length;
}
