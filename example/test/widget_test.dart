import 'dart:io';

import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('switches the hero from red to green', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HeroHereExample()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey(HeroType.red)), findsOneWidget);
    expect(find.byKey(const ValueKey(HeroType.green)), findsNothing);

    await tester.tap(find.byIcon(Icons.radio_button_off));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey(HeroType.red)), findsNothing);
    expect(find.byKey(const ValueKey(HeroType.green)), findsOneWidget);
  });

  test('shows the code of lib/main.dart on its pub.dev page', () {
    // pub.dev shows example.md on the package's Example tab.
    final page = File('example.md').readAsStringSync();
    final code = RegExp(
      r'```dart\n(.*?)```',
      dotAll: true,
    ).firstMatch(page)?.group(1);
    final main = File('lib/main.dart').readAsStringSync();

    expect(code, main.substring(main.indexOf('import ')));
  });
}
