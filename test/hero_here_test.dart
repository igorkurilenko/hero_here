import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

  testWidgets('flies a redirected hero on from where its shuttle is', (
    tester,
  ) async {
    final slot = ValueNotifier(0);
    addTearDown(slot.dispose);

    await tester.pumpWidget(_SlotSwitcher(slot: slot));
    await tester.pumpAndSettle();

    slot.value = 1;
    await _pumpSwitch(tester);
    await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 2);

    // Redirect the flight to the third slot while it is between the first
    // two.
    slot.value = 2;
    await _pumpSwitch(tester);

    // Record the shuttle's left edge on each frame of the rest of the flight.
    final shuttle = find.byKey(_shuttleKey);
    final lefts = <double>[];
    for (var frame = 0; frame < 40; frame++) {
      if (tester.any(shuttle)) lefts.add(tester.getRect(shuttle).left);
      await tester.pump(const Duration(milliseconds: 16));
    }

    // The slots run left to right, so the shuttle only ever moves right: it
    // lands on the second slot, then flies on from there to the third.
    for (var i = 1; i < lefts.length; i++) {
      expect(lefts[i], greaterThanOrEqualTo(lefts[i - 1]), reason: '$lefts');
    }
    expect(shuttle, findsNothing);
    expect(find.byKey(const ValueKey('box2')), findsOneWidget);
  });

  testWidgets('shows a hero whose child arrives during a switch', (
    tester,
  ) async {
    final slot = ValueNotifier(0);
    addTearDown(slot.dispose);

    await tester.pumpWidget(_SlotSwitcher(slot: slot));
    await tester.pumpAndSettle();

    slot.value = 1;
    await tester.pump(); // The switch to the second slot starts.
    slot.value = 2; // The third slot arrives before that switch ends.
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('box2')), findsOneWidget);
  });

  testWidgets('disposes the snapshot when a switch ends', (tester) async {
    final liveImages = _trackLiveImages();
    final slot = ValueNotifier(0);
    addTearDown(slot.dispose);

    await tester.pumpWidget(_SlotSwitcher(slot: slot));
    await tester.pumpAndSettle();

    slot.value = 1;
    await tester.pumpAndSettle();

    expect(liveImages(), 0);
  });

  testWidgets('disposes the snapshot when unmounted during a switch', (
    tester,
  ) async {
    final liveImages = _trackLiveImages();
    final slot = ValueNotifier(0);
    addTearDown(slot.dispose);

    await tester.pumpWidget(_SlotSwitcher(slot: slot));
    await tester.pumpAndSettle();

    slot.value = 1;
    await tester.pump(); // The snapshot is taken after this frame.
    await tester.pumpWidget(const SizedBox());

    expect(liveImages(), 0);
  });

  testWidgets('lays out nothing outside the shuttle while it changes size', (
    tester,
  ) async {
    var skyLayouts = 0;
    final slot = ValueNotifier(0);
    addTearDown(slot.dispose);

    await tester.pumpWidget(
      _SlotSwitcher(
        slot: slot,
        layoutBuilder: (child, sky) => Stack(
          children: [
            child,
            _LayoutCounter(onLayout: () => skyLayouts++, child: sky),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    slot.value = 1; // The shuttle grows from 40 to 80 pixels.
    await _pumpSwitch(tester);
    skyLayouts = 0;
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(skyLayouts, 0);
  });
}

/// Counts the `ui.Image` handles created and not yet disposed from now until
/// the end of the test.
int Function() _trackLiveImages() {
  var live = 0;
  final onCreate = ui.Image.onCreate, onDispose = ui.Image.onDispose;
  ui.Image.onCreate = (image) {
    live++;
    onCreate?.call(image);
  };
  ui.Image.onDispose = (image) {
    live--;
    onDispose?.call(image);
  };
  addTearDown(() {
    ui.Image.onCreate = onCreate;
    ui.Image.onDispose = onDispose;
  });
  return () => live;
}

/// Snapshots the old child, lays the new one out offstage, starts the flight.
Future<void> _pumpSwitch(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

const _slotRects = [
  Rect.fromLTWH(0, 100, 40, 40),
  Rect.fromLTWH(200, 100, 80, 80),
  Rect.fromLTWH(400, 100, 60, 60),
];

/// Shows one hero in the slot of [_slotRects] that [slot] picks.
class _SlotSwitcher extends StatelessWidget {
  const _SlotSwitcher({
    required this.slot,
    this.layoutBuilder = HeroHereSwitcher.defaultLayoutBuilder,
  });

  final ValueNotifier<int> slot;
  final HeroHereSwitcherLayoutBuilder layoutBuilder;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: ValueListenableBuilder(
      valueListenable: slot,
      builder: (context, slot, _) => HeroHereSwitcher(
        layoutBuilder: layoutBuilder,
        child: Stack(
          children: [
            Positioned.fromRect(
              rect: _slotRects[slot],
              child: HeroHere(
                key: ValueKey(slot),
                tag: 'hero',
                flightShuttleBuilder: (_, _, _, _) =>
                    const SizedBox.expand(key: _shuttleKey),
                child: ColoredBox(
                  key: ValueKey('box$slot'),
                  color: const Color(0xFF2196F3),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
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

/// Calls [onLayout] each time it lays out its child.
class _LayoutCounter extends SingleChildRenderObjectWidget {
  const _LayoutCounter({required this.onLayout, super.child});

  final VoidCallback onLayout;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderLayoutCounter(onLayout);
}

class _RenderLayoutCounter extends RenderProxyBox {
  _RenderLayoutCounter(this.onLayout);

  final VoidCallback onLayout;

  @override
  void performLayout() {
    onLayout();
    super.performLayout();
  }
}
