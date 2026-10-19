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
