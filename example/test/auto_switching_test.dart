import 'dart:ui' as ui;

import 'package:example/basic_with_auto_switching/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hero_here/hero_here.dart';

void main() {
  testWidgets('diverts redirected flights once divert is on', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HeroHereExample()));
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

  testWidgets('runs a switch only when its hero changes', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HeroHereExample()));
    await tester.pumpAndSettle();

    // Each switch takes a snapshot of the switcher's child.
    var snapshots = 0;
    final onCreate = ui.Image.onCreate;
    ui.Image.onCreate = (image) {
      snapshots++;
      onCreate?.call(image);
    };
    addTearDown(() => ui.Image.onCreate = onCreate);

    await tester.tap(find.text('Divert'));
    await tester.pumpAndSettle();
    expect(snapshots, 0);

    await tester.tap(find.byIcon(Icons.radio_button_off).first);
    await tester.pumpAndSettle();
    expect(snapshots, greaterThan(0));
  });

  testWidgets('places its heroes off one line', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HeroHereExample()));
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
}
