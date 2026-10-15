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

  testWidgets('flies a hero back when its child changes back mid-flight', (
    tester,
  ) async {
    final slot = ValueNotifier(0);
    addTearDown(slot.dispose);

    await tester.pumpWidget(_SlotSwitcher(slot: slot));
    await tester.pumpAndSettle();

    slot.value = 1;
    await _pumpSwitch(tester);
    await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 2);

    slot.value = 0;
    await _pumpSwitch(tester);

    // The shuttle turns back from where it is, so it only ever moves left.
    final shuttle = find.byKey(_shuttleKey);
    final lefts = <double>[];
    for (var frame = 0; frame < 40; frame++) {
      if (tester.any(shuttle)) lefts.add(tester.getRect(shuttle).left);
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(lefts, isNotEmpty);
    for (var i = 1; i < lefts.length; i++) {
      expect(lefts[i], lessThanOrEqualTo(lefts[i - 1]), reason: '$lefts');
    }
    expect(shuttle, findsNothing);
    expect(find.byKey(const ValueKey('box0')), findsOneWidget);
  });

  testWidgets('shuttles the new child of a hero it leaves that mounts anew', (
    tester,
  ) async {
    final phase = ValueNotifier(0);
    addTearDown(phase.dispose);

    await tester.pumpWidget(_SourceSwitcher(phase: phase));
    await tester.pumpAndSettle();

    phase.value = 1;
    await _pumpSwitch(tester);
    await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 4);
    // The shuttle shows the child of the hero the flight leaves.
    expect(find.byKey(const ValueKey('a1')), findsOneWidget);

    // That hero mounts anew with a new child, while another flight starts,
    // which rebuilds the shuttle.
    phase.value = 2;
    await _pumpSwitch(tester);

    expect(find.byKey(const ValueKey('a2')), findsOneWidget);
    expect(find.byKey(const ValueKey('a1')), findsNothing);
  });

  testWidgets('lands on the hero it flies to when that one mounts anew', (
    tester,
  ) async {
    final moved = ValueNotifier(false), wrapped = ValueNotifier(false);
    addTearDown(moved.dispose);
    addTearDown(wrapped.dispose);

    await tester.pumpWidget(_RemountSwitcher(moved: moved, wrapped: wrapped));
    await tester.pumpAndSettle();

    moved.value = true;
    await _pumpSwitch(tester);
    await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 2);

    // Mount the hero the flight lands on anew, mid-flight. It hides until
    // the flight lands on it.
    wrapped.value = true;
    await _pumpSwitch(tester);
    expect(find.byKey(_shuttleKey), findsOneWidget);
    expect(find.byKey(const ValueKey('box1')), findsNothing);

    await tester.pumpAndSettle();
    expect(find.byKey(_shuttleKey), findsNothing);
    expect(find.byKey(const ValueKey('box1')), findsOneWidget);
  });

  testWidgets('stops a flight when its hero goes away mid-flight', (
    tester,
  ) async {
    final slot = ValueNotifier(0);
    addTearDown(slot.dispose);

    await tester.pumpWidget(_SlotSwitcher(slot: slot));
    await tester.pumpAndSettle();

    slot.value = 1;
    await _pumpSwitch(tester);
    await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 2);

    slot.value = _noSlot;
    await _pumpSwitch(tester);

    expect(find.byKey(_shuttleKey), findsNothing);
  });

  testWidgets('hides the earlier of new heroes that share a tag', (
    tester,
  ) async {
    final split = ValueNotifier(false);
    addTearDown(split.dispose);

    await tester.pumpWidget(_SplitSwitcher(split: split));
    await tester.pumpAndSettle();

    split.value = true;
    await tester.pumpAndSettle();

    // The hero in the first slot flies to the last one, the hero in the
    // middle one hides.
    expect(find.byKey(const ValueKey('box0')), findsNothing);
    expect(find.byKey(const ValueKey('box1')), findsNothing);
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

  for (final (child, sameChild) in [
    ('a new child', false),
    ('the same child', true),
  ]) {
    testWidgets('runs a switch on every rebuild, with $child', (tester) async {
      final rebuilds = ValueNotifier(0);
      addTearDown(rebuilds.dispose);

      await tester.pumpWidget(
        _RebuildSwitcher(rebuilds: rebuilds, sameChild: sameChild),
      );
      await tester.pumpAndSettle();

      // Each switch takes one snapshot of the child.
      final snapshots = _countNewImages();
      for (var rebuild = 0; rebuild < 3; rebuild++) {
        rebuilds.value++;
        await tester.pumpAndSettle();
      }

      expect(snapshots(), 3);
    });
  }

  testWidgets('stops its flights when unmounted mid-flight', (tester) async {
    final slot = ValueNotifier(0);
    addTearDown(slot.dispose);

    await tester.pumpWidget(_SlotSwitcher(slot: slot));
    await tester.pumpAndSettle();

    slot.value = 1;
    await _pumpSwitch(tester);
    await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 2);
    expect(find.byKey(_shuttleKey), findsOneWidget);

    // A flight left running would trip the ticker provider's dispose check.
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
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

  testWidgets('repaints nothing outside the sky during a flight', (
    tester,
  ) async {
    var siblingPaints = 0;
    final slot = ValueNotifier(0);
    addTearDown(slot.dispose);

    await tester.pumpWidget(
      _SlotSwitcher(
        slot: slot,
        layoutBuilder: (child, sky) => Stack(
          children: [
            child,
            Positioned.fill(
              child: CustomPaint(painter: _PaintCounter(() => siblingPaints++)),
            ),
            sky,
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    slot.value = 1;
    await _pumpSwitch(tester);
    siblingPaints = 0;
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(siblingPaints, 0);
  });

  testWidgets('shows the first child on the first frame', (tester) async {
    final slot = ValueNotifier(0);
    addTearDown(slot.dispose);

    await tester.pumpWidget(_SlotSwitcher(slot: slot));

    expect(find.byKey(const ValueKey('box0')), findsOneWidget);
  });

  testWidgets('flies nothing on mount between heroes that share a tag', (
    tester,
  ) async {
    final rebuilds = ValueNotifier(0);
    addTearDown(rebuilds.dispose);

    await tester.pumpWidget(_TwinSwitcher(rebuilds: rebuilds));
    for (var frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byKey(_shuttleKey), findsNothing);
    }

    expect(find.byKey(const ValueKey('earlierBox')), findsNothing);
    expect(find.byKey(const ValueKey('lastBox')), findsOneWidget);
    // The earlier hero keeps its space, also for intrinsic layouts.
    expect(tester.getTopLeft(find.byKey(_markerKey)).dx, 40);
    final earlierHero = tester.renderObject<RenderBox>(
      find.byKey(const ValueKey('earlier')),
    );
    expect(earlierHero.getMaxIntrinsicWidth(double.infinity), 40);
  });

  testWidgets('flies nothing on the first rebuild between heroes that share '
      'a tag', (tester) async {
    final rebuilds = ValueNotifier(0);
    addTearDown(rebuilds.dispose);

    await tester.pumpWidget(_TwinSwitcher(rebuilds: rebuilds));
    await tester.pumpAndSettle();

    rebuilds.value++;
    await _pumpSwitch(tester);
    expect(find.byKey(_shuttleKey), findsNothing);

    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('earlierBox')), findsNothing);
  });

  testWidgets('hides the earlier of heroes that share a tag from the first '
      'frame', (tester) async {
    var earlierPaints = 0;
    final rebuilds = ValueNotifier(0);
    addTearDown(rebuilds.dispose);

    await tester.pumpWidget(
      _TwinSwitcher(rebuilds: rebuilds, onEarlierPaint: () => earlierPaints++),
    );

    final earlierBox = find.byKey(const ValueKey('earlierBox'));
    final hit = tester.hitTestOnBinding(tester.getCenter(earlierBox));
    expect(earlierPaints, 0);
    expect(
      hit.path.map((entry) => entry.target),
      isNot(contains(tester.renderObject(earlierBox))),
    );
  });

  testWidgets('lands on a hidden hero that a resize changes the size of', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 600);
    addTearDown(tester.view.reset);
    final moved = ValueNotifier(false);
    addTearDown(moved.dispose);

    await tester.pumpWidget(_QuarterWidthSwitcher(moved: moved));
    await tester.pumpAndSettle();

    moved.value = true;
    await _pumpSwitch(tester);
    await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 2);

    // The hero the flight lands on is a quarter of the window wide.
    tester.view.physicalSize = const Size(400, 600);

    final shuttle = find.byKey(_shuttleKey);
    late Rect shuttleRect;
    for (var frame = 0; frame < 40 && tester.any(shuttle); frame++) {
      shuttleRect = tester.getRect(shuttle);
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(shuttle, findsNothing);

    final heroRect = tester.getRect(find.byKey(const ValueKey('box-true')));
    expect(heroRect.width, 100);
    expect(
      (shuttleRect.topLeft - heroRect.topLeft).distance,
      lessThan(2),
      reason: 'The shuttle landed at $shuttleRect, the hero is at $heroRect.',
    );
    expect(shuttleRect.width, closeTo(heroRect.width, 2));
  });

  const left = ValueKey('left'), right = ValueKey('right');
  for (final (leftShuttle, rightShuttle, shuttle, from) in [
    (left, right, right, 'the hero it lands on'),
    (left, null, left, 'the hero it leaves when the other has none'),
    (
      null,
      null,
      const ValueKey('box-true'),
      'the default when neither has one',
    ),
  ]) {
    testWidgets('takes a flight option from $from', (tester) async {
      final moved = ValueNotifier(false);
      addTearDown(moved.dispose);

      await tester.pumpWidget(
        _ShuttleSwitcher(
          moved: moved,
          leftShuttle: leftShuttle,
          rightShuttle: rightShuttle,
        ),
      );
      await tester.pumpAndSettle();

      moved.value = true;
      await _pumpSwitch(tester);

      // The default shuttle is the child of the hero the flight lands on.
      expect(find.byKey(shuttle), findsOneWidget);
    });
  }
}

/// Counts the `ui.Image`s created from now until the end of the test, leaving
/// out clones of them.
int Function() _countNewImages() {
  final images = <ui.Image>[];
  final onCreate = ui.Image.onCreate;
  ui.Image.onCreate = (image) {
    if (!images.any(image.isCloneOf)) images.add(image);
    onCreate?.call(image);
  };
  addTearDown(() => ui.Image.onCreate = onCreate);
  return () => images.length;
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

/// Phase 0 shows hero 'a' in the first slot of [_slotRects]. Phase 1 adds
/// hero 'b' with the same tag after it, in the second, so 'a' flies to 'b'
/// and stays, hidden. Phase 2 mounts 'a' anew with a new child, and moves a
/// hero with another tag, which starts a second flight. The heroes tagged
/// 'hero' shuttle the child of the hero their flight leaves.
class _SourceSwitcher extends StatelessWidget {
  const _SourceSwitcher({required this.phase});

  final ValueNotifier<int> phase;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: ValueListenableBuilder(
      valueListenable: phase,
      builder: (context, phase, _) {
        Widget hero(String key, String box) => HeroHere(
          key: ValueKey(key),
          tag: 'hero',
          flightShuttleBuilder: (_, _, fromHero, _) =>
              SizedBox.expand(child: fromHero.child),
          child: ColoredBox(key: ValueKey(box), color: const Color(0xFF2196F3)),
        );

        return HeroHereSwitcher(
          child: Stack(
            children: [
              Positioned.fromRect(
                rect: _slotRects[0],
                child: phase < 2
                    ? hero('a', 'a1')
                    : KeyedSubtree(child: hero('a', 'a2')),
              ),
              if (phase > 0)
                Positioned.fromRect(rect: _slotRects[1], child: hero('b', 'b')),
              Positioned.fromRect(
                rect: phase < 2
                    ? _slotRects[2]
                    : const Rect.fromLTWH(0, 300, 40, 40),
                child: HeroHere(
                  key: ValueKey(phase < 2 ? 'x' : 'y'),
                  tag: 'other',
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

/// Shows a hero in the first slot of [_slotRects], or, when [moved], in the
/// second. When [wrapped], the hero sits in one more widget, so changing
/// [wrapped] mounts it anew.
class _RemountSwitcher extends StatelessWidget {
  const _RemountSwitcher({required this.moved, required this.wrapped});

  final ValueNotifier<bool> moved;
  final ValueNotifier<bool> wrapped;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: ListenableBuilder(
      listenable: Listenable.merge([moved, wrapped]),
      builder: (context, _) {
        final slot = moved.value ? 1 : 0;
        Widget hero = HeroHere(
          key: ValueKey(slot),
          tag: 'hero',
          flightShuttleBuilder: (_, _, _, _) =>
              const SizedBox.expand(key: _shuttleKey),
          child: ColoredBox(
            key: ValueKey('box$slot'),
            color: const Color(0xFF2196F3),
          ),
        );
        if (wrapped.value) hero = KeyedSubtree(child: hero);

        return HeroHereSwitcher(
          child: Stack(
            children: [
              Positioned.fromRect(rect: _slotRects[slot], child: hero),
            ],
          ),
        );
      },
    ),
  );
}

/// Rebuilds a switcher on each change of [rebuilds], with a new child each
/// time, or with the same `const` child when [sameChild].
class _RebuildSwitcher extends StatelessWidget {
  const _RebuildSwitcher({required this.rebuilds, required this.sameChild});

  final ValueNotifier<int> rebuilds;
  final bool sameChild;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: ValueListenableBuilder(
      valueListenable: rebuilds,
      builder: (context, rebuild, _) => HeroHereSwitcher(
        child: sameChild
            ? const SizedBox.square(dimension: 40)
            : SizedBox.square(key: ValueKey(rebuild), dimension: 40),
      ),
    ),
  );
}

/// A [_SlotSwitcher] slot that shows no hero.
const _noSlot = -1;

/// Shows one hero in the slot of [_slotRects] that [slot] picks, or none for
/// [_noSlot].
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
            if (slot != _noSlot)
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

/// Shows a hero in the first slot of [_slotRects], or, when [split], heroes
/// with the same tag in the other two.
class _SplitSwitcher extends StatelessWidget {
  const _SplitSwitcher({required this.split});

  final ValueNotifier<bool> split;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: ValueListenableBuilder(
      valueListenable: split,
      builder: (context, split, _) => HeroHereSwitcher(
        child: Stack(
          children: [
            for (final slot in split ? [1, 2] : [0])
              Positioned.fromRect(
                rect: _slotRects[slot],
                child: HeroHere(
                  key: ValueKey(slot),
                  tag: 'hero',
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

const _markerKey = ValueKey('marker');

/// Shows two heroes that share a tag in a row, with a marker between them.
/// Each change of [rebuilds] rebuilds the switcher with the same child.
class _TwinSwitcher extends StatelessWidget {
  const _TwinSwitcher({required this.rebuilds, this.onEarlierPaint});

  final ValueNotifier<int> rebuilds;
  final VoidCallback? onEarlierPaint;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: ValueListenableBuilder(
      valueListenable: rebuilds,
      builder: (context, _, _) => HeroHereSwitcher(
        child: Row(
          children: [
            _buildHero(
              'earlier',
              CustomPaint(
                key: const ValueKey('earlierBox'),
                size: const Size.square(40),
                painter: _PaintCounter(() => onEarlierPaint?.call()),
              ),
            ),
            const SizedBox(key: _markerKey, width: 10, height: 10),
            _buildHero(
              'last',
              const SizedBox.square(key: ValueKey('lastBox'), dimension: 80),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildHero(String name, Widget child) => HeroHere(
    key: ValueKey(name),
    tag: 'hero',
    flightShuttleBuilder: (_, _, _, _) =>
        const SizedBox.expand(key: _shuttleKey),
    child: child,
  );
}

/// Shows a hero on the left, or, when [moved], on the right. Each hero builds
/// its flights' shuttle as an empty box with the given key, if one is given.
class _ShuttleSwitcher extends StatelessWidget {
  const _ShuttleSwitcher({
    required this.moved,
    this.leftShuttle,
    this.rightShuttle,
  });

  final ValueNotifier<bool> moved;
  final Key? leftShuttle;
  final Key? rightShuttle;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: ValueListenableBuilder(
      valueListenable: moved,
      builder: (context, moved, _) {
        final shuttle = moved ? rightShuttle : leftShuttle;
        return HeroHereSwitcher(
          child: Align(
            alignment: moved ? Alignment.centerRight : Alignment.centerLeft,
            child: HeroHere(
              key: ValueKey(moved),
              tag: 'hero',
              flightShuttleBuilder: shuttle == null
                  ? null
                  : (_, _, _, _) => SizedBox.expand(key: shuttle),
              child: SizedBox.square(
                key: ValueKey('box-$moved'),
                dimension: 40,
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// Shows a 40 px hero at the top left, or, when [moved], a hero a quarter of
/// the window wide at the top right.
class _QuarterWidthSwitcher extends StatelessWidget {
  const _QuarterWidthSwitcher({required this.moved});

  final ValueNotifier<bool> moved;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: ValueListenableBuilder(
      valueListenable: moved,
      builder: (context, moved, _) => HeroHereSwitcher(
        child: Align(
          alignment: moved ? Alignment.topRight : Alignment.topLeft,
          child: HeroHere(
            key: ValueKey(moved),
            tag: 'hero',
            flightShuttleBuilder: (_, _, _, _) =>
                const SizedBox.expand(key: _shuttleKey),
            child: FractionallySizedBox(
              key: ValueKey('box-$moved'),
              widthFactor: moved ? 0.25 : null,
              child: const SizedBox(width: 40, height: 40),
            ),
          ),
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

/// Calls [onPaint] each time it paints.
class _PaintCounter extends CustomPainter {
  _PaintCounter(this.onPaint);

  final VoidCallback onPaint;

  @override
  void paint(Canvas canvas, Size size) => onPaint();

  @override
  bool shouldRepaint(_PaintCounter oldDelegate) => false;
}
