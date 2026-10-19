import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hero_here/hero_here.dart';

void main() {
  testWidgets('crossfades the hero a flight leaves out over the hero it flies '
      'to', (tester) async {
    final flipped = ValueNotifier(false);
    addTearDown(flipped.dispose);
    await tester.pumpWidget(
      _CardSwitcher(
        flipped: flipped,
        shuttleBuilder: HeroHereShuttles.crossfade(),
      ),
    );

    flipped.value = true;
    await _pumpSwitch(tester);
    await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 4);

    final value = HeroHere.defaultFlightAnimationCurve.transform(.25);
    expect(_opacityOf(tester, find.text('front')), closeTo(1 - value, 1e-9));
    expect(_opacityOf(tester, find.text('back')), 1);
    // The hero it leaves shows over the hero it flies to.
    expect(_texts(), ['back', 'front']);

    await tester.pumpAndSettle();
    expect(_texts(), ['back']);
    expect(_opacityOf(tester, find.text('back')), 1);
  });

  testWidgets("lays the child of the hero a flight flies to out at that hero's "
      'size, and stretches it to the shuttle', (tester) async {
    final grown = ValueNotifier(false);
    addTearDown(grown.dispose);
    final bigWidth = ValueNotifier(400.0);
    addTearDown(bigWidth.dispose);
    await tester.pumpWidget(
      _GrowSwitcher(
        grown: grown,
        bigWidth: bigWidth,
        shuttleBuilder: HeroHereShuttles.scale(),
      ),
    );
    final text = find.text(_longText);
    const big = Size(400, 200);

    grown.value = true;
    await _pumpSwitch(tester);
    // The frames of the flight, before it lands.
    for (var frame = 0; frame < 15; frame++) {
      await tester.pump(_frame);
      expect(tester.getSize(text), big);
      final shuttle = tester.getRect(find.byType(FittedBox));
      expect(shuttle.width, lessThan(big.width));
      expect(tester.getRect(text), rectMoreOrLessEquals(shuttle));
    }

    await tester.pumpAndSettle();
    expect(tester.getSize(text), big);
    expect(tester.getRect(text).size, big);
  });

  testWidgets('scales the child of the hero a flight flies to as its fit and '
      'alignment say', (tester) async {
    final grown = ValueNotifier(false);
    addTearDown(grown.dispose);
    final bigWidth = ValueNotifier(400.0);
    addTearDown(bigWidth.dispose);
    await tester.pumpWidget(
      _GrowSwitcher(
        grown: grown,
        bigWidth: bigWidth,
        shuttleBuilder: HeroHereShuttles.scale(
          fit: BoxFit.contain,
          alignment: Alignment.topLeft,
        ),
      ),
    );
    final text = find.text(_longText);

    grown.value = true;
    await _pumpSwitch(tester);
    await tester.pump(_frame * 3);

    // Taller than the text for its width, the shuttle shows it whole, as
    // wide as the shuttle, at its top.
    final shuttle = tester.getRect(find.byType(FittedBox));
    final shown = tester.getRect(text);
    expect(shuttle.width / shuttle.height, lessThan(1.5));
    expect(shown.width / shown.height, closeTo(2, 1e-9));
    expect(shown.topLeft, offsetMoreOrLessEquals(shuttle.topLeft));
    expect(shown.width, moreOrLessEquals(shuttle.width));
  });

  testWidgets('lays the child out anew at the size the hero a flight flies to '
      'takes mid-flight, and builds the shuttle once', (tester) async {
    final grown = ValueNotifier(false);
    addTearDown(grown.dispose);
    final bigWidth = ValueNotifier(400.0);
    addTearDown(bigWidth.dispose);
    final scale = HeroHereShuttles.scale();
    var builds = 0;
    await tester.pumpWidget(
      _GrowSwitcher(
        grown: grown,
        bigWidth: bigWidth,
        shuttleBuilder: (flightContext, animation, fromHero, toHero) {
          builds++;
          return scale(flightContext, animation, fromHero, toHero);
        },
      ),
    );
    final text = find.text(_longText);

    grown.value = true;
    await _pumpSwitch(tester);
    await tester.pump(_frame * 5);
    expect(tester.getSize(text), const Size(400, 200));

    // No switch: the hero it flies to narrows below the switcher.
    bigWidth.value = 300;
    await tester.pump(_frame);
    expect(tester.getSize(text), const Size(300, 200));

    await tester.pumpAndSettle();
    expect(tester.getSize(text), const Size(300, 200));
    expect(builds, 1);
  });

  for (final axis in Axis.values) {
    testWidgets('flips a shuttle over about the ${axis.name} axis, showing the '
        'hero it flies to the right way round once edge on', (tester) async {
      final flipped = ValueNotifier(false);
      addTearDown(flipped.dispose);
      await tester.pumpWidget(
        _CardSwitcher(
          flipped: flipped,
          shuttleBuilder: HeroHereShuttles.flip(axis: axis),
        ),
      );

      flipped.value = true;
      await _pumpSwitch(tester);
      const third = Duration(milliseconds: 100);
      expect(HeroHere.defaultFlightAnimationDuration, third * 3);

      // Before it's edge on, it shows the hero it leaves.
      await tester.pump(third);
      expect(_texts(), ['front']);
      expect(_readsRightWayRound(tester, find.text('front'), axis), isTrue);

      // Past edge on, it shows the hero it flies to, turned over, yet the
      // right way round.
      await tester.pump(third);
      expect(_texts(), ['back']);
      expect(_readsRightWayRound(tester, find.text('back'), axis), isTrue);

      await tester.pumpAndSettle();
      expect(_texts(), ['back']);
      expect(_readsRightWayRound(tester, find.text('back'), axis), isTrue);
    });
  }
}

const _longText =
    'A long text that wraps over several lines, so it would break its lines '
    'anew at each size a shuttle takes, if laid out at it.';

/// A card a switch moves from a 100 px square in the top left corner to a
/// box [bigWidth] wide and 200 px high in the bottom right one, once [grown].
/// Both show [_longText], whose box fills the card. Its flights show
/// [shuttleBuilder]'s shuttle.
class _GrowSwitcher extends StatelessWidget {
  const _GrowSwitcher({
    required this.grown,
    required this.bigWidth,
    required this.shuttleBuilder,
  });

  final ValueNotifier<bool> grown;
  final ValueNotifier<double> bigWidth;
  final HeroHereFlightShuttleBuilder shuttleBuilder;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: ValueListenableBuilder(
      valueListenable: grown,
      builder: (context, grown, _) => HeroHereSwitcher(
        child: Align(
          alignment: grown ? Alignment.bottomRight : Alignment.topLeft,
          child: grown
              // Its width is read below the switcher, so it changes with no
              // switch, and the hero stays the same widget.
              ? ValueListenableBuilder(
                  valueListenable: bigWidth,
                  builder: (context, width, hero) =>
                      SizedBox(width: width, height: 200, child: hero),
                  child: _card(grown),
                )
              : SizedBox.square(dimension: 100, child: _card(grown)),
        ),
      ),
    ),
  );

  Widget _card(bool grown) => HeroHere(
    key: ValueKey(grown),
    tag: 'card',
    flightShuttleBuilder: shuttleBuilder,
    child: const SizedBox.expand(child: Text(_longText)),
  );
}

/// A card a switch moves from the top left corner, with 'front' on it, to the
/// bottom right one, with 'back' on it, once [flipped], and whose flights
/// show [shuttleBuilder]'s shuttle.
class _CardSwitcher extends StatelessWidget {
  const _CardSwitcher({required this.flipped, required this.shuttleBuilder});

  final ValueNotifier<bool> flipped;
  final HeroHereFlightShuttleBuilder shuttleBuilder;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: ValueListenableBuilder(
      valueListenable: flipped,
      builder: (context, flipped, _) => HeroHereSwitcher(
        child: Align(
          alignment: flipped ? Alignment.bottomRight : Alignment.topLeft,
          child: SizedBox.square(
            dimension: 200,
            child: HeroHere(
              key: ValueKey(flipped),
              tag: 'card',
              flightShuttleBuilder: shuttleBuilder,
              child: Text(flipped ? 'back' : 'front'),
            ),
          ),
        ),
      ),
    ),
  );
}

const _frame = Duration(milliseconds: 16);

/// Pumps the frame of a switch, after which its flight starts, and the frame
/// its shuttle first shows on.
Future<void> _pumpSwitch(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

/// The texts that show, in the order they paint.
List<String?> _texts() => [
  for (final element in find.byType(Text).evaluate())
    (element.widget as Text).data,
];

/// Whether the text [finder] finds reads the right way round across [axis],
/// rather than mirrored: from left to right about the vertical axis, and from
/// top to bottom about the horizontal one.
bool _readsRightWayRound(WidgetTester tester, Finder finder, Axis axis) =>
    switch (axis) {
      Axis.vertical =>
        tester.getTopLeft(finder).dx < tester.getTopRight(finder).dx,
      Axis.horizontal =>
        tester.getTopLeft(finder).dy < tester.getBottomLeft(finder).dy,
    };

/// How opaque the widget [finder] finds is, by the fades above it.
double _opacityOf(WidgetTester tester, Finder finder) {
  var opacity = 1.0;
  tester.element(finder).visitAncestorElements((element) {
    final widget = element.widget;
    if (widget is FadeTransition) opacity *= widget.opacity.value;
    return true;
  });
  return opacity;
}
