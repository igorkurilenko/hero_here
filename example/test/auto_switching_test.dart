import 'package:example/basic_with_auto_switching/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hero_here/hero_here.dart';

void main() {
  testWidgets('diverts redirected flights once divert is on', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AutoSwitchingExample()));
    await tester.pumpAndSettle();

    HeroHereFlightRedirect? redirect() =>
        tester.widget<HeroHere>(find.byType(HeroHere)).flightRedirect;
    expect(redirect(), HeroHereFlightRedirect.chain);

    await tester.tap(find.text('Divert'));
    await tester.pumpAndSettle();
    expect(redirect(), HeroHereFlightRedirect.divert);

    await tester.tap(find.text('Chain'));
    await tester.pumpAndSettle();
    expect(redirect(), HeroHereFlightRedirect.chain);
  });

  testWidgets('switches its hero on and on while it plays, until paused', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AutoSwitchingExample()));
    await tester.pumpAndSettle();
    Key? hero() => tester.widget(find.byType(HeroHere)).key;

    await tester.tap(_playButton);
    final shown = <Key?>{};
    for (var i = 0; i < 20; i++) {
      await tester.pump(kAutoHeroSwitchingDuration);
      shown.add(hero());
    }
    expect(shown, hasLength(greaterThan(1)));

    // Paused, it switches no more, and leaves no timer running once the test
    // ends, which would fail it.
    await tester.tap(_playButton);
    await tester.pumpAndSettle();
    final last = hero();
    await tester.pump(kAutoHeroSwitchingDuration * 4);
    expect(hero(), last);
  });

  testWidgets('stops switching once the page goes away while it plays', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AutoSwitchingExample()));
    await tester.pumpAndSettle();
    await tester.tap(_playButton);
    await tester.pump();

    await tester.pumpWidget(const SizedBox());
    // A switch now would set the state of a page that's gone, and a timer
    // still running once the test ends fails it.
    await tester.pump(kAutoHeroSwitchingDuration * 2);
  });

  testWidgets('places its heroes off one line', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AutoSwitchingExample()));
    await tester.pumpAndSettle();

    // Show each hero in turn with its button.
    final centers = <Offset>[];
    for (final type in HeroType.values) {
      await tester.tap(_heroButton(type));
      await tester.pumpAndSettle();
      centers.add(tester.getCenter(find.byType(HeroHere)));
    }

    expect({
      for (final center in centers) center.dy,
    }, hasLength(greaterThan(1)));
  });

  testWidgets('repaints nothing in its app bar as its bottom bar changes', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AutoSwitchingExample()));
    await tester.pumpAndSettle();

    // Count the paints of what's in the app bar.
    final appBar = tester.renderObject(find.byType(AppBar));
    var appBarPaints = 0;
    debugOnProfilePaint = (object) {
      for (RenderObject? o = object; o != null; o = o.parent) {
        if (identical(o, appBar)) {
          appBarPaints++;
          return;
        }
      }
    };
    try {
      // Show the green hero with its button, so the buttons change.
      await tester.tap(_heroButton(HeroType.green));
      await tester.pumpAndSettle();
    } finally {
      debugOnProfilePaint = null;
    }

    expect(appBarPaints, 0);
  });
}

/// The bottom bar's buttons: the play button, then one for each hero.
final _buttons = find.descendant(
  of: find.byType(BottomAppBar),
  matching: find.byType(IconButton),
);

final _playButton = _buttons.first;

/// The button that shows the [type] hero.
Finder _heroButton(HeroType type) => _buttons.at(1 + type.index);
