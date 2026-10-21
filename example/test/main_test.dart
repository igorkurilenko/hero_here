import 'dart:io';

import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'flight_helpers.dart';

void main() {
  testWidgets('flies the photo from the middle of the page to its corner, '
      'and back', (tester) async {
    await _pumpExample(tester);
    final middle = tester.getRect(_photo);
    expect(middle.width, 300);

    await startFlight(tester, _photo);
    await tester.pump(midFlight);
    final midway = tester.getRect(_photo);
    expect(midway.width, inExclusiveRange(100, 300));
    expect(midway.left, inExclusiveRange(0, middle.left));

    await tester.pumpAndSettle();
    final corner = tester.getRect(_photo);
    expect(corner.size, const Size.square(100));
    expect(corner.left, 0);

    await startFlight(tester, _photo);
    await tester.pump(midFlight);
    expect(tester.getRect(_photo).width, inExclusiveRange(100, 300));

    await tester.pumpAndSettle();
    expect(tester.getRect(_photo), middle);
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

/// The photo: in the middle of the page, in its corner, or in flight.
final _photo = find.byType(Image);

/// Pumps the example, with its photo decoded, so it takes its size.
Future<void> _pumpExample(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: FlippersExample()));
  await tester.runAsync(
    () => precacheImage(
      const AssetImage('images/flippers.png'),
      tester.element(_photo),
    ),
  );
  await tester.pump();
}
