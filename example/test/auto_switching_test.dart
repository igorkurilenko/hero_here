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

    await tester.tap(find.byTooltip('Redirects: chain'));
    await tester.pumpAndSettle();

    expect(redirect(), HeroHereFlightRedirect.divert);
    expect(find.byTooltip('Redirects: divert'), findsOneWidget);
  });
}
