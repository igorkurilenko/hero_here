import 'package:example/show_details_hero/eight_thousander_details_hero.dart';
import 'package:example/show_details_hero/config.dart';
import 'package:example/show_details_hero/eight_thousander.dart';
import 'package:example/show_details_hero/eight_thousander_preview_hero.dart';
import 'package:example/show_details_hero/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hero_here/hero_here.dart';

void main() {
  for (final (where, window, cell, slide) in [
    // So far it would uncover the page's edge: its scale's margin across.
    ('far across', const Size(800, 600), 'K2', const Offset(-.1, .0747)),
    // Its scale's margin down, and across in proportion.
    ('far down', const Size(1600, 600), 'K2', const Offset(-.067, .1)),
  ]) {
    testWidgets('slides the grid toward a cell $where as its details open', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = window;
      addTearDown(tester.view.reset);
      await _pumpExample(tester);

      await tester.tap(find.text(cell));
      await tester.pump();

      expect(find.byType(EightThousanderDetailsHero), findsOneWidget);
      final offset = tester
          .widget<AnimatedSlide>(find.byType(AnimatedSlide))
          .offset;
      expect(offset.dx, closeTo(slide.dx, .001));
      expect(offset.dy, closeTo(slide.dy, .001));
    });
  }

  testWidgets('slides the grid all the way to the middle for a cell near it '
      'as its details open', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 1300);
    addTearDown(tester.view.reset);
    await _pumpExample(tester);
    final page = tester.getRect(find.byType(ShowDetailsExample));
    final cell = find.ancestor(
      of: find.text('Lhotse'),
      matching: find.byType(EightThousanderPreviewHero),
    );
    final toMiddle = page.center - tester.getCenter(cell);
    // Nearer the middle, across and down, than the grid's scale leaves a
    // margin to slide into.
    final margin = page.size * (kGridViewScaleWhenDetailsOpen - 1) / 2;
    expect(toMiddle.dx.abs(), lessThan(margin.width));
    expect(toMiddle.dy.abs(), lessThan(margin.height));
    expect(toMiddle.distance, greaterThan(10));

    await tester.tap(find.text('Lhotse'));
    await tester.pump();

    final offset = tester
        .widget<AnimatedSlide>(find.byType(AnimatedSlide))
        .offset;
    expect(offset.dx, closeTo(toMiddle.dx / page.width, .001));
    expect(offset.dy, closeTo(toMiddle.dy / page.height, .001));
  });

  testWidgets('slides the grid no farther than its scale leaves a margin, '
      'for a cell far across and down', (tester) async {
    await _pumpExample(tester);
    final page = tester.getRect(find.byType(ShowDetailsExample));
    // The first cell of the second row, which reaches below the page.
    final cell = tester.getRect(
      find.byType(EightThousanderPreviewHero, skipOffstage: false).at(2),
    );
    final toMiddle = page.center - cell.center;

    await tester.tapAt(Offset(cell.center.dx, page.bottom - 20));
    await tester.pump();

    final offset = tester
        .widget<AnimatedSlide>(find.byType(AnimatedSlide))
        .offset;
    final margin = (kGridViewScaleWhenDetailsOpen - 1) / 2;
    expect(offset.dx.abs(), lessThanOrEqualTo(margin + 1e-9));
    expect(offset.dy.abs(), lessThanOrEqualTo(margin + 1e-9));
    // Toward the middle, along the line from the cell.
    final slid = Offset(offset.dx * page.width, offset.dy * page.height);
    expect(slid.direction, closeTo(toMiddle.direction, 1e-6));
  });

  testWidgets('enables the back button once the details have flown open', (
    tester,
  ) async {
    await _pumpExample(tester);

    await tester.tap(find.text('K2'));
    await tester.pump();

    // The back button waits for the flight.
    final back = find.widgetWithIcon(IconButton, Icons.chevron_left);
    expect(tester.widget<IconButton>(back).onPressed, isNull);

    await tester.pumpAndSettle();

    expect(tester.widget<IconButton>(back).onPressed, isNotNull);
  });

  testWidgets('keeps the back button when the page rebuilds', (tester) async {
    await _openK2Details(tester);

    // Rebuild with the details still open, as on a window resize.
    tester.element(find.byType(ShowDetailsExample)).markNeedsBuild();
    await tester.pump();

    // A new back button would fade in over the old one fading out.
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
  });

  testWidgets('fades the back button out when the details close', (
    tester,
  ) async {
    await _openK2Details(tester);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pump();
    await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 2);

    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
  });

  testWidgets('clips the back button\'s fade to the button', (tester) async {
    await _openK2Details(tester);

    // On the web an opacity layer paints offscreen, even when opaque, as big
    // as the clip around it.
    final appBar = find.byType(AppBar);
    final fade =
        tester
                .renderObject(
                  find.descendant(
                    of: appBar,
                    matching: find.byType(FadeTransition),
                  ),
                )
                .debugLayer!
            as OpacityLayer;
    var clip = fade.parent;
    while (clip is! ClipRectLayer) {
      clip = clip!.parent;
    }

    expect(
      clip.clipRect!.size,
      tester.getSize(
        find.descendant(of: appBar, matching: find.byType(AnimatedSwitcher)),
      ),
    );
  });

  testWidgets('drags the details without rebuilding their image', (
    tester,
  ) async {
    _useTallView(tester);

    await _openK2Details(tester);

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
    _useTallView(tester);

    await _openK2Details(tester);

    final details = find.byType(EightThousanderDetailsHero);
    expect(
      find.descendant(of: details, matching: find.text('K2')),
      findsOneWidget,
    );
    // On the web each opacity layer paints offscreen, even when opaque.
    expect(_opacityLayersIn(tester, details), 0);
  });

  testWidgets('fades the flying title and description without opacity '
      'layers', (tester) async {
    // So the title and the description fly too.
    _useTallView(tester);

    await _pumpExample(tester);
    final switcher = find.byType(HeroHereSwitcher);
    // The alphas of the colors of the title and the description that are
    // partway faded.
    List<double> fading() => [
      for (final text in tester.renderObjectList<RenderParagraph>(
        find.descendant(of: switcher, matching: find.byType(RichText)),
      ))
        if ([_k2.name, _k2.description].contains(text.text.toPlainText()) &&
            text.text.style!.color!.a > 0 &&
            text.text.style!.color!.a < 1)
          text.text.style!.color!.a,
    ];

    await tester.tap(find.text('K2'));
    await tester.pump();
    // The flights start after the frame of the switch.
    await tester.pump();
    await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 4);

    // A quarter of the way, they've faded a little in.
    expect(fading(), [for (var i = 0; i < 2; i++) lessThan(0.5)]);
    expect(_opacityLayersIn(tester, switcher), 0);

    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pump();
    await tester.pump();
    await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 4);

    // And as they close, a little out.
    expect(fading(), [for (var i = 0; i < 2; i++) greaterThan(0.5)]);
    expect(_opacityLayersIn(tester, switcher), 0);
  });

  testWidgets('paints the grid without opacity layers of its own while the '
      'details are closed', (tester) async {
    await _pumpExample(tester);
    expect(_opacityLayersIn(tester, find.byType(ShowDetailsExample)), 0);

    await tester.tap(find.text('K2'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    expect(_opacityLayersIn(tester, find.byType(ShowDetailsExample)), 0);
  });

  testWidgets('dims the grid while the details are open', (tester) async {
    await _pumpExample(tester);
    final background = Theme.of(tester.element(find.byType(HeroHereSwitcher)))
        .canvasColor;
    // How opaque the color over the grid is.
    double dimming() => tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(HeroHereSwitcher),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .map((decoration) => decoration.color)
        .where((color) => color?.withValues(alpha: 1) == background)
        .fold(0.0, (dimming, color) => dimming + color!.a);

    expect(dimming(), 0);

    await tester.tap(find.text('K2'));
    await tester.pumpAndSettle();
    expect(dimming(), closeTo(1 - kGridViewOpacityOnOpen, 0.01));

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    expect(dimming(), 0);
  });

  for (final (where, window, display) in [
    ('', null, null),
    (' on a phone', const Size(402, 874), const Size(402, 874)),
    // Its display may still give its upright size.
    (' on a phone on its side', const Size(874, 402), const Size(402, 874)),
  ]) {
    testWidgets('decodes each grid thumbnail no taller than its cell$where', (
      tester,
    ) async {
      if (window != null && display != null) {
        tester.view.devicePixelRatio = 3;
        tester.view.physicalSize = window * 3;
        tester.view.display.devicePixelRatio = 3;
        tester.view.display.size = display * 3;
        addTearDown(tester.view.reset);
        addTearDown(tester.view.display.reset);
      }
      await _pumpExample(tester);
      final ratio = tester.view.devicePixelRatio;

      final cells = find.byType(EightThousanderPreviewHero);
      expect(cells, findsWidgets);
      for (final cell in tester.widgetList(cells)) {
        final image = find.descendant(
          of: find.byWidget(cell),
          matching: find.byType(Image),
        );
        // Tall enough to show sharp, and no taller than the cell.
        expect(
          _decodedHeightOf(tester, image),
          greaterThanOrEqualTo(tester.getSize(image).height * ratio),
        );
        expect(
          _decodedHeightOf(tester, image),
          lessThanOrEqualTo(
            tester.getSize(find.byWidget(cell)).height * ratio + 1,
          ),
        );
      }
    });
  }

  testWidgets('decodes the grid thumbnails at one size as the window '
      'resizes', (tester) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(1200, 800) * 2;
    tester.view.display.devicePixelRatio = 2;
    tester.view.display.size = const Size(1920, 1080) * 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.view.display.reset);
    await _pumpExample(tester);
    final image = find.byType(Image).first;
    final wide = _decodedHeightOf(tester, image);

    // Narrower than the grid at its widest, so its cells shrink.
    tester.view.physicalSize = const Size(400, 800) * 2;
    await tester.pumpAndSettle();

    // So the window's resize decodes no thumbnail anew.
    expect(_decodedHeightOf(tester, image), wide);
  });

  testWidgets('shows the cell\'s thumbnail in the details until their full '
      'image loads', (tester) async {
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    await _pumpExample(tester);
    final thumbnail = tester
        .widget<Image>(
          find.descendant(
            of: find.ancestor(
              of: find.text('K2'),
              matching: find.byType(EightThousanderPreviewHero),
            ),
            matching: find.byType(Image),
          ),
        )
        .image;

    await tester.tap(find.text('K2'));
    await tester.pumpAndSettle();
    final details = find.byType(EightThousanderDetailsHero);
    List<ImageProvider> shown() => [
      for (final image in tester.widgetList<Image>(
        find.descendant(of: details, matching: find.byType(Image)),
      ))
        image.image,
    ];
    expect(shown(), contains(thumbnail));

    // The full image loads, as it would in time.
    await tester.runAsync(
      () => precacheImage(AssetImage(_k2.image), tester.element(details)),
    );
    await tester.pump();
    expect(shown(), isNot(contains(thumbnail)));
  });

  testWidgets('closes the details when flung down', (tester) async {
    // So the title and the description fly too.
    _useTallView(tester);

    await _openK2Details(tester);

    await tester.fling(find.byType(AspectRatio), const Offset(0, 200), 1000);
    await tester.pumpAndSettle();

    expect(find.byType(EightThousanderDetailsHero), findsNothing);
  });

  testWidgets('closes the details onto where the cell is after a resize', (
    tester,
  ) async {
    await _openK2Details(tester);

    // A narrower window moves the cell.
    tester.view.physicalSize = const Size(1200, 1800);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.chevron_left));

    // While the cell is hidden, the image showing is the flight's shuttle.
    // It shows K2's image in full, or as the cell's thumbnail.
    final k2 = AssetImage(_k2.image);
    final image = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          (widget.image == k2 ||
              widget.image is ResizeImage &&
                  (widget.image as ResizeImage).imageProvider == k2),
    );
    final cellImage = find.descendant(
      of: find.byType(GridView),
      matching: image,
    );
    Rect? shuttleRect;
    for (var frame = 0; frame < 40; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (tester.any(image) && !tester.any(cellImage)) {
        shuttleRect = tester.getRect(image.first);
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
    await _pumpExample(tester);

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

final _k2 = kEightThousanders.firstWhere((x) => x.name == 'K2');

Future<void> _pumpExample(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: ShowDetailsExample()));
  await tester.pumpAndSettle();
}

/// Pumps the example and opens K2's details.
Future<void> _openK2Details(WidgetTester tester) async {
  await _pumpExample(tester);
  await tester.tap(find.text('K2'));
  await tester.pumpAndSettle();
}

/// Makes the view tall enough for the details to build their title and
/// description, below their image, for the rest of the test.
void _useTallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(2400, 4800);
  addTearDown(tester.view.resetPhysicalSize);
}

/// How many opacity layers the render objects below [finder] paint into.
int _opacityLayersIn(WidgetTester tester, Finder finder) {
  var count = 0;
  void visit(RenderObject object) {
    if (object.debugLayer is OpacityLayer) count++;
    object.visitChildren(visit);
  }

  visit(tester.renderObject(finder));
  return count;
}

/// The height the image of [image], an [Image], is decoded at.
int _decodedHeightOf(WidgetTester tester, Finder image) {
  final provider = tester.widget<Image>(image).image;
  expect(provider, isA<ResizeImage>());
  return (provider as ResizeImage).height!;
}
