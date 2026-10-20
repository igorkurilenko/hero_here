import 'dart:math' as math;

import 'package:example/splash_logo_hero/launches.dart';
import 'package:example/splash_logo_hero/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'flight_helpers.dart';

void main() {
  testWidgets('flies the logo and the name into the app bar once the app has '
      'loaded', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashLogoExample()));
    final splash = tester.getRect(_logo);
    final splashName = tester.getRect(_name);

    await tester.pump(kLoadingDuration);
    await tester.pump();
    await tester.pump(midFlight);

    final logo = tester.getRect(_logo);
    expect(logo.center.dy, lessThan(splash.center.dy - 50));
    expect(logo.width, lessThan(splash.width - 10));
    final name = tester.getRect(_name);
    final laidOut = tester.renderObject<RenderBox>(_name).size;

    await tester.pumpAndSettle();
    final landed = tester.getRect(_logo);
    expect(landed.size, const Size.square(kAppBarLogoExtent));
    final landedName = tester.getRect(_name);
    // Laid out once, at its size in the app bar, and scaled on its way there.
    expect(laidOut, landedName.size);
    expect(name.height, greaterThan(landedName.height + 2));
    expect(name.height, lessThan(splashName.height - 2));
    expect(
      find.descendant(of: find.byType(AppBar), matching: _logo),
      findsOneWidget,
    );
    expect(find.byType(Launches), findsOneWidget);
  });

  testWidgets('flies them back to the splash screen on a tap on them, and to '
      'the app bar again once loaded', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashLogoExample()));
    final splash = tester.getRect(_logo);
    await tester.pump(kLoadingDuration);
    await tester.pumpAndSettle();
    final inAppBar = tester.getRect(_logo);

    await startFlight(tester, _logo);
    await tester.pump(midFlight);

    final logo = tester.getRect(_logo);
    expect(logo.center.dy, greaterThan(inAppBar.center.dy + 50));
    expect(logo.center.dy, lessThan(splash.center.dy - 50));

    await tester.pumpAndSettle();
    expect(tester.getRect(_logo), splash);
    expect(find.byType(AppBar), findsNothing);

    await tester.pump(kLoadingDuration);
    await tester.pumpAndSettle();
    expect(tester.getRect(_logo), inAppBar);
  });

  testWidgets('lands the logo in the app bar on a soft spring, a little past '
      'its place and back', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashLogoExample()));
    await tester.pump(kLoadingDuration);
    await tester.pump();

    // How high the logo goes, on each frame.
    final highs = await pumpFrames(
      tester,
      60,
      () => tester.getCenter(_logo).dy,
    );

    final landed = tester.getCenter(_logo).dy;
    expect(highs.reduce(math.min), lessThan(landed - 1));
  });
}

/// The logo: on the splash screen, in the app bar, or in flight.
final _logo = find.byType(Logo);

/// The app's name: on the splash screen, in the app bar, or in flight.
final _name = find.text('Orbit');
