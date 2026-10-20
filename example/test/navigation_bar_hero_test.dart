import 'dart:math' as math;

import 'package:example/navigation_bar_hero/main.dart';
import 'package:example/navigation_bar_hero/tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hero_here/hero_here.dart';

void main() {
  testWidgets('flies the indicator to the tapped tab', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: NavigationBarExample()));
    final home = tester.getCenter(_tab('Home')).dx;
    final saved = tester.getCenter(_tab('Saved')).dx;
    expect(tester.getCenter(_indicator).dx, home);

    await _startFlight(tester, 'Saved');
    await tester.pump(const Duration(milliseconds: 150));

    final halfway = tester.getCenter(_indicator).dx;
    expect(halfway, greaterThan(home + 50));
    expect(halfway, lessThan(saved - 50));

    await tester.pumpAndSettle();
    expect(tester.getCenter(_indicator).dx, saved);
    expect(
      find.descendant(of: find.byType(Scaffold), matching: find.text('Saved')),
      findsNWidgets(2),
    );
  });

  testWidgets('starts the indicator over to a tab tapped mid-flight, from '
      'where it is', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: NavigationBarExample()));
    final home = tester.getCenter(_tab('Home')).dx;
    await tester.tap(_tab('Search'));
    await tester.pumpAndSettle();

    await _startFlight(tester, 'Saved');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(_tab('Home'));
    await tester.pump(_frame);

    // Where it starts over from, on the frame of the tap.
    final from = tester.getCenter(_indicator).dx;
    var farthest = from;
    for (var frame = 0; frame < _frameLimit && _flying(tester); frame++) {
      await tester.pump(_frame);
      farthest = math.max(farthest, tester.getCenter(_indicator).dx);
    }

    // From rest, rather than running on toward Saved at the speed it had, or
    // first landing on Saved, then flying back.
    expect(farthest, from);
    expect(tester.getCenter(_indicator).dx, home);
  });
}

const _frame = Duration(milliseconds: 16);

/// The most frames a test pumps while the indicator flies, so that a flight
/// that never lands fails it rather than hangs it.
const _frameLimit = 100;

/// The label of the tab named [label] in the navigation bar.
Finder _tab(String label) => find.descendant(
  of: find.byType(HeroHereSwitcher),
  matching: find.text(label),
);

/// The indicator: under the selected tab's icon, or in flight.
final _indicator = find.byType(TabIndicator);

/// Taps the tab named [label] and pumps until the indicator's flight shows,
/// from the frame after the switch.
Future<void> _startFlight(WidgetTester tester, String label) async {
  await tester.tap(_tab(label));
  await tester.pump();
  await tester.pump();
}

/// Whether the indicator is in flight: away from under every tab's icon.
bool _flying(WidgetTester tester) {
  final at = tester.getCenter(_indicator).dx;
  return !kTabs.any((tab) => tester.getCenter(_tab(tab.label)).dx == at);
}
