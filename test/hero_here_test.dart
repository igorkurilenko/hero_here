import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hero_here/hero_here.dart';

const _shuttleKey = ValueKey('shuttle');

void main() {
  for (final textDirection in TextDirection.values) {
    testWidgets('flies between hero rects when the switcher is away from the origin '
        '($textDirection)', (tester) async {
      final moved = ValueNotifier(false);
      addTearDown(moved.dispose);

      await tester.pumpWidget(
        _OffsetSwitcher(moved: moved, textDirection: textDirection),
      );
      await tester.pumpAndSettle();

      final fromRect = tester.getRect(find.byKey(const ValueKey(false)));

      moved.value = true;
      // Snapshot the old child, lay the new one out offstage, start the flight.
      await tester.pump();
      await tester.pump();
      await tester.pump();

      final toRect = tester.getRect(find.byKey(const ValueKey(true)));
      expect(tester.getRect(find.byKey(_shuttleKey)), fromRect);

      await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 2);
      final t = HeroHere.defaultFlightAnimationCurve.transform(0.5);
      expect(
        tester.getRect(find.byKey(_shuttleKey)),
        _rectMoreOrLessEquals(Rect.lerp(fromRect, toRect, t)!),
      );

      await tester.pumpAndSettle();
      expect(find.byKey(_shuttleKey), findsNothing);
    });
  }
}

class _OffsetSwitcher extends StatelessWidget {
  const _OffsetSwitcher({required this.moved, required this.textDirection});

  final ValueNotifier<bool> moved;
  final TextDirection textDirection;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Directionality(
      textDirection: textDirection,
      child: Padding(
        padding: const EdgeInsets.only(left: 300, top: 100),
        child: ValueListenableBuilder(
          valueListenable: moved,
          builder: (context, moved, _) => HeroHereSwitcher(
            child: Stack(
              children: [
                Positioned(
                  left: moved ? 200 : 0,
                  top: moved ? 150 : 0,
                  width: moved ? 80 : 40,
                  height: moved ? 80 : 40,
                  child: HeroHere(
                    key: ValueKey(moved),
                    tag: 'hero',
                    flightShuttleBuilder: (_, _, _, _) =>
                        const SizedBox.expand(key: _shuttleKey),
                    child: const ColoredBox(color: Color(0xFF2196F3)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Matcher _rectMoreOrLessEquals(Rect expected) => predicate<Rect>(
  (rect) =>
      (rect.left - expected.left).abs() < 0.01 &&
      (rect.top - expected.top).abs() < 0.01 &&
      (rect.width - expected.width).abs() < 0.01 &&
      (rect.height - expected.height).abs() < 0.01,
  'a rect close to $expected',
);
