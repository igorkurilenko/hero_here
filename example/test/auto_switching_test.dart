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

  testWidgets('places its heroes off one line', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AutoSwitchingExample()));
    await tester.pumpAndSettle();

    // Show each hero in turn with its button, which follows the play button.
    final buttons = find.descendant(
      of: find.byType(BottomAppBar),
      matching: find.byType(IconButton),
    );
    final centers = <Offset>[];
    for (final type in HeroType.values) {
      await tester.tap(buttons.at(1 + type.index));
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
      final buttons = find.descendant(
        of: find.byType(BottomAppBar),
        matching: find.byType(IconButton),
      );
      await tester.tap(buttons.at(1 + HeroType.green.index));
      await tester.pumpAndSettle();
    } finally {
      debugOnProfilePaint = null;
    }

    expect(appBarPaints, 0);
  });
}
