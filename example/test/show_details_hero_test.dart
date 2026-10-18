import 'package:example/show_details_hero/eight_thousander_details_hero.dart';
import 'package:example/show_details_hero/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hero_here/hero_here.dart';

void main() {
  testWidgets('enables the back button once the details have flown open', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ShowDetailsExample()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('K2'));
    await tester.pump();

    // The back button waits for the flight.
    final back = find.widgetWithIcon(IconButton, Icons.chevron_left);
    expect(tester.widget<IconButton>(back).onPressed, isNull);

    await tester.pumpAndSettle();

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

  testWidgets('drags the details without rebuilding their image', (
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
    // The alpha of the title's and the description's color.
    final texts = find.descendant(
      of: find.byType(ListView),
      matching: find.byType(RichText),
    );
    List<double> alphas() => [
      for (final text in tester.renderObjectList<RenderParagraph>(texts))
        text.text.style!.color!.a,
    ];
    final opaque = alphas();
    expect(opaque, hasLength(2));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(AspectRatio)),
    );
    await gesture.moveBy(const Offset(0, 20)); // Past the touch slop.
    await tester.pump();

    // Pull the details down past their top, slowly enough not to close.
    var rebuilds = 0;
    debugOnRebuildDirtyWidget = (element, _) {
      if (element.widget is Image) rebuilds++;
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
    final faded = alphas();
    for (var i = 0; i < opaque.length; i++) {
      expect(faded[i], lessThan(opaque[i]));
    }

    await gesture.up();
    await tester.pumpAndSettle();
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('paints the open details\' text without opacity layers', (
    tester,
  ) async {
    // Tall enough to build the title and the description.
    tester.view.physicalSize = const Size(2400, 4800);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MaterialApp(home: ShowDetailsExample()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('K2'));
    await tester.pumpAndSettle();

    // On the web each opacity layer paints offscreen, even when opaque.
    var opacityLayers = 0;
    void visit(RenderObject object) {
      if (object.debugLayer is OpacityLayer) opacityLayers++;
      object.visitChildren(visit);
    }

    final details = find.byType(EightThousanderDetailsHero);
    visit(tester.renderObject(details));
    expect(
      find.descendant(of: details, matching: find.text('K2')),
      findsOneWidget,
    );
    expect(opacityLayers, 0);
  });

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
