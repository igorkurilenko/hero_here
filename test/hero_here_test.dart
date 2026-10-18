import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
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

  testWidgets('flies from where the hero it leaves is when that one stays', (
    tester,
  ) async {
    final split = ValueNotifier(false);
    addTearDown(split.dispose);

    await tester.pumpWidget(_StaySwitcher(split: split));
    await tester.pumpAndSettle();

    split.value = true;
    await _pumpSwitch(tester);

    // Not from the first slot, where the hero was before the switch.
    expect(tester.getRect(find.byKey(_shuttleKey)), _stayRect);
  });

  testWidgets('measures the hero a flight leaves once a frame, and only '
      'while its path starts there', (tester) async {
    final split = ValueNotifier(false);
    addTearDown(split.dispose);
    var measures = 0;
    Future<List<int>> measuresPerFrame() async {
      final perFrame = <int>[];
      for (var i = 0; i < 3; i++) {
        measures = 0;
        await tester.pump(const Duration(milliseconds: 16));
        perFrame.add(measures);
      }
      return perFrame;
    }

    await tester.pumpWidget(
      _StaySwitcher(split: split, onMeasureA: () => measures++),
    );
    await tester.pumpAndSettle();

    split.value = true;
    await _pumpSwitch(tester);
    expect(await measuresPerFrame(), [1, 1, 1]);

    // Turned back, it heads for where 'a' is.
    split.value = false;
    await _pumpSwitch(tester);
    expect(await measuresPerFrame(), [1, 1, 1]);

    // Turned around again, it heads from where it turned to 'b'.
    split.value = true;
    await _pumpSwitch(tester);
    expect(await measuresPerFrame(), [0, 0, 0]);
  });

  for (final (name, box, mount) in [
    ('the hero it flies to', 'box1', (HeroHere from, HeroHere to) => to),
    ('the hero it leaves', 'box0', (HeroHere from, HeroHere to) => from),
  ]) {
    testWidgets('flies and lands a shuttle that shows $name itself', (
      tester,
    ) async {
      final slot = ValueNotifier(0);
      addTearDown(slot.dispose);

      await tester.pumpWidget(
        _SlotSwitcher(
          slot: slot,
          shuttleBuilder: (_, _, fromHero, toHero) => mount(fromHero, toHero),
        ),
      );
      await tester.pumpAndSettle();

      slot.value = 1;
      await _pumpSwitch(tester);
      await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 2);

      // The hero the shuttle shows is a copy, which takes no part in the
      // flight, and shows.
      expect(find.byKey(ValueKey(box)), findsOneWidget);

      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(const ValueKey('box1'))), _slotRects[1]);
    });
  }

  testWidgets('flies and lands shuttles that show their heroes themselves in '
      'a switcher inside another one', (tester) async {
    final slot = ValueNotifier(0);
    addTearDown(slot.dispose);
    Widget hero(String key, Rect rect) => Positioned.fromRect(
      rect: rect,
      child: HeroHere(
        key: ValueKey(key),
        tag: 'hero',
        flightShuttleBuilder: (_, _, _, toHero) => toHero,
        child: ColoredBox(
          key: ValueKey('box-$key'),
          color: const Color(0xFF2196F3),
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder(
          valueListenable: slot,
          builder: (context, slot, _) => HeroHereSwitcher(
            child: Stack(
              children: [
                hero('outer$slot', _slotRects[slot]),
                Positioned.fromRect(
                  rect: const Rect.fromLTWH(0, 300, 800, 300),
                  child: HeroHereSwitcher(
                    child: Stack(
                      children: [hero('inner$slot', _slotRects[slot])],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    slot.value = 1;
    await _pumpSwitch(tester);
    await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 2);

    // Each shuttle shows its copy, which belongs to neither switcher, though
    // the outer one flies the same tag.
    expect(find.byKey(const ValueKey('box-outer1')), findsOneWidget);
    expect(find.byKey(const ValueKey('box-inner1')), findsOneWidget);

    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const ValueKey('box-outer1'))),
      _slotRects[1],
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('box-inner1'))),
      _slotRects[1].translate(0, 300),
    );
  });

  testWidgets('flies from where a hero is once a global key moves it into '
      'another switcher', (tester) async {
    final moving = GlobalKey();
    // 0: the hero in the left switcher; 1: moved into the right one, at the
    // same place in it; 2: the right one swaps it for another hero.
    Widget app(int stage) => MaterialApp(
      home: Row(
        children: [
          for (final right in [false, true])
            SizedBox(
              width: 400,
              height: 600,
              child: HeroHereSwitcher(
                child: Stack(
                  children: [
                    if (stage == (right ? 1 : 0))
                      _heroAt(moving, _slotRects[0]),
                    if (right && stage == 2)
                      _heroAt(const ValueKey('other'), _slotRects[1]),
                  ],
                ),
              ),
            ),
        ],
      ),
    );

    await tester.pumpWidget(app(0));
    await tester.pumpAndSettle();
    await tester.pumpWidget(app(1));
    await tester.pumpAndSettle();

    await tester.pumpWidget(app(2));
    await _pumpSwitch(tester);

    expect(
      tester.getRect(find.byKey(_shuttleKey)),
      _slotRects[0].translate(400, 0),
    );
  });

  testWidgets('hides a hero that a global key moves into a switcher while its '
      'tag flies there, until the flight lands', (tester) async {
    final moving = GlobalKey();
    final slot = ValueNotifier(0);
    final movedRight = ValueNotifier(false);
    addTearDown(slot.dispose);
    addTearDown(movedRight.dispose);
    const movedRect = Rect.fromLTWH(100, 400, 60, 60);
    // Moves the hero below both switchers, so neither runs a switch.
    Widget moved({required bool right}) => ValueListenableBuilder(
      valueListenable: movedRight,
      builder: (context, movedRight, _) => Stack(
        children: [if (movedRight == right) _heroAt(moving, movedRect)],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Row(
          children: [
            SizedBox(
              width: 400,
              height: 600,
              child: HeroHereSwitcher(child: moved(right: false)),
            ),
            SizedBox(
              width: 400,
              height: 600,
              child: ValueListenableBuilder(
                valueListenable: slot,
                builder: (context, slot, _) => HeroHereSwitcher(
                  child: Stack(
                    children: [
                      _heroAt(ValueKey(slot), _slotRects[slot]),
                      Positioned.fill(child: moved(right: true)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final movedBox = _boxOf(moving);

    slot.value = 1;
    await _pumpSwitch(tester);
    await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 4);
    movedRight.value = true;
    await tester.pump();

    // As a hero that mounts there while its tag flies.
    expect(movedBox, findsNothing);
    expect(_painted(tester, _boxOf(moving, skipOffstage: false)), isFalse);

    await tester.pumpAndSettle();
    expect(tester.getRect(movedBox), movedRect.translate(400, 0));
  });

  testWidgets('flies on to the hero it flies to once a global key moves that '
      'one into another switcher', (tester) async {
    final moving = GlobalKey();
    final stage = ValueNotifier(0);
    final movedRight = ValueNotifier(false);
    addTearDown(stage.dispose);
    addTearDown(movedRight.dispose);
    const movedRect = Rect.fromLTWH(100, 400, 60, 60);

    await tester.pumpWidget(
      MaterialApp(
        home: Row(
          children: [
            SizedBox(
              width: 400,
              height: 600,
              child: ValueListenableBuilder(
                valueListenable: stage,
                builder: (context, stage, _) => HeroHereSwitcher(
                  child: Stack(
                    children: [
                      if (stage == 0)
                        _heroAt(const ValueKey('left'), _slotRects[0]),
                      // Moves the hero below both switchers, so neither
                      // runs a switch.
                      ValueListenableBuilder(
                        valueListenable: movedRight,
                        builder: (context, movedRight, _) => Stack(
                          children: [
                            if (stage == 1 && !movedRight)
                              _heroAt(moving, _slotRects[1]),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 400,
              height: 600,
              child: HeroHereSwitcher(
                child: ValueListenableBuilder(
                  valueListenable: movedRight,
                  builder: (context, movedRight, _) => Stack(
                    children: [if (movedRight) _heroAt(moving, movedRect)],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    stage.value = 1;
    await _pumpSwitch(tester);
    await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 4);
    movedRight.value = true;
    await tester.pump();
    await tester.pump(HeroHere.defaultFlightAnimationDuration * 0.6);

    // Nearly there: where the hero is now, in the right switcher, rather
    // than as far off as the switchers are apart.
    final target = movedRect.translate(400, 0);
    expect(
      (tester.getRect(find.byKey(_shuttleKey)).center - target.center).distance,
      lessThan(60),
    );

    await tester.pumpAndSettle();
    expect(tester.getRect(_boxOf(moving)), target);
  });

  testWidgets('shows the last of heroes that share a tag in the tree, though '
      'it mounted first', (tester) async {
    final stage = ValueNotifier(0);
    addTearDown(stage.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder(
          valueListenable: stage,
          builder: (context, stage, _) => HeroHereSwitcher(
            child: Stack(
              children: [
                if (stage == 1) _heroAt(const ValueKey('b'), _slotRects[0]),
                _heroAt(const ValueKey('a'), _slotRects[1]),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 'b' comes before 'a' in the tree, but mounts after it.
    stage.value = 1;
    await _pumpSwitch(tester);

    expect(find.byKey(_shuttleKey), findsNothing);
    expect(_boxOf(const ValueKey('b')), findsNothing);
    expect(tester.getRect(_boxOf(const ValueKey('a'))), _slotRects[1]);
  });

  testWidgets('leaves a hero under a disabled hero mode out of switches until '
      'the hero mode is enabled again', (tester) async {
    // 0: 'a' in an enabled hero mode; 1: the hero mode disabled; 2: 'b' comes;
    // 3: the hero mode enabled again, and 'b' goes.
    final stage = ValueNotifier(0);
    addTearDown(stage.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder(
          valueListenable: stage,
          builder: (context, stage, _) => HeroHereSwitcher(
            child: Stack(
              children: [
                HeroMode(
                  enabled: stage != 1 && stage != 2,
                  child: Stack(
                    children: [_heroAt(const ValueKey('a'), _slotRects[0])],
                  ),
                ),
                if (stage == 2) _heroAt(const ValueKey('b'), _slotRects[1]),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final a = find.byType(HeroHere).first;
    final aState = tester.state(a);

    stage.value = 1;
    await tester.pumpAndSettle();
    // Nothing flies from 'a', which the disabled hero mode keeps out.
    stage.value = 2;
    await _pumpSwitch(tester);
    expect(find.byKey(_shuttleKey), findsNothing);
    await tester.pumpAndSettle();

    // Enabled again, 'a' is in switches again, with no remount.
    stage.value = 3;
    await _pumpSwitch(tester);
    expect(find.byKey(_shuttleKey), findsOneWidget);
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(HeroHere).first), same(aState));
  });

  testWidgets('keeps a hero that a global key moves within its switcher, with '
      'no flight', (tester) async {
    final moving = GlobalKey();
    final stage = ValueNotifier(0);
    addTearDown(stage.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder(
          valueListenable: stage,
          builder: (context, stage, _) => HeroHereSwitcher(
            child: Stack(
              children: [
                // Under a padding, then not, so the hero moves to another
                // parent. Then another hero takes its place.
                if (stage == 0)
                  Padding(
                    padding: EdgeInsets.zero,
                    child: Stack(children: [_heroAt(moving, _slotRects[0])]),
                  )
                else if (stage == 1)
                  _heroAt(moving, _slotRects[1])
                else
                  _heroAt(const ValueKey('other'), _slotRects[2]),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    stage.value = 1;
    await _pumpSwitch(tester);

    expect(find.byKey(_shuttleKey), findsNothing);
    expect(tester.getRect(_boxOf(moving)), _slotRects[1]);

    // It's still one of the switcher's heroes, so the next switch flies it.
    await tester.pumpAndSettle();
    stage.value = 2;
    await _pumpSwitch(tester);
    expect(tester.getRect(find.byKey(_shuttleKey)), _slotRects[1]);
  });

  testWidgets('keeps a hero that mounts anew earlier in the tree, under '
      'another parent, with no flight', (tester) async {
    final stage = ValueNotifier(0);
    addTearDown(stage.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder(
          valueListenable: stage,
          builder: (context, stage, _) => HeroHereSwitcher(
            // The first stack builds the hero anew before the second one lets
            // the old one go.
            child: Stack(
              children: [
                Stack(
                  children: [
                    if (stage == 1) _heroAt(const ValueKey('a'), _slotRects[1]),
                  ],
                ),
                Stack(
                  children: [
                    if (stage == 0) _heroAt(const ValueKey('a'), _slotRects[0]),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    stage.value = 1;
    await _pumpSwitch(tester);

    expect(find.byKey(_shuttleKey), findsNothing);
    await tester.pumpAndSettle();
    expect(tester.getRect(_boxOf(const ValueKey('a'))), _slotRects[1]);
  });

  testWidgets('finds its heroes without visiting the rest of its child', (
    tester,
  ) async {
    final slot = ValueNotifier(0);
    addTearDown(slot.dispose);
    var visits = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder(
          valueListenable: slot,
          builder: (context, slot, _) => HeroHereSwitcher(
            child: Stack(
              children: [
                _heroAt(ValueKey(slot), _slotRects[slot]),
                Column(
                  children: [
                    for (var i = 0; i < 100; i++)
                      _VisitCounter(onVisit: () => visits++),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    visits = 0;
    slot.value = 1;
    await _pumpSwitch(tester);
    // Read before any finder, which visits the tree itself.
    final visitsBySwitch = visits;

    expect(find.byKey(_shuttleKey), findsOneWidget);
    expect(visitsBySwitch, 0);
  });

  testWidgets(
    'flies to the first of heroes with the same tag and key',
    (tester) async {
      final stage = ValueNotifier(0);
      addTearDown(stage.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder(
            valueListenable: stage,
            builder: (context, stage, _) => HeroHereSwitcher(
              child: Stack(
                children: [
                  if (stage == 0) _heroAt(const ValueKey('x'), _slotRects[0]),
                  // Under different parents, so their keys don't clash.
                  if (stage == 1) ...[
                    Stack(
                      children: [_heroAt(const ValueKey('a'), _slotRects[1])],
                    ),
                    Stack(
                      children: [_heroAt(const ValueKey('a'), _slotRects[2])],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      stage.value = 1;
      await _pumpSwitch(tester);
      await tester.pump(HeroHere.defaultFlightAnimationDuration * 0.99);

      // The second, equal to the first, takes no part.
      expect(
        (tester.getRect(find.byKey(_shuttleKey)).center - _slotRects[1].center)
            .distance,
        lessThan(2),
      );
    },
    // Equal heroes trip a semantics assertion, as the hero hiding by tag and
    // key hides both, which this test isn't about.
    semanticsEnabled: false,
  );

  testWidgets('starts the flights of a switch in tree order, so a hero flies '
      'under the heroes inside it', (tester) async {
    final slot = ValueNotifier(0);
    addTearDown(slot.dispose);
    HeroHere hero(String tag, int slot, Widget child) => HeroHere(
      key: ValueKey('$tag$slot'),
      tag: tag,
      flightShuttleBuilder: (_, _, _, _) =>
          SizedBox.expand(key: ValueKey('shuttle-$tag')),
      child: child,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder(
          valueListenable: slot,
          builder: (context, slot, _) => HeroHereSwitcher(
            child: Stack(
              children: [
                Positioned.fromRect(
                  rect: _slotRects[slot],
                  child: hero(
                    'outer',
                    slot,
                    hero('inner', slot, const SizedBox()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    slot.value = 1;
    await _pumpSwitch(tester);

    // The sky paints its shuttles in the order their flights started.
    final shuttles = find.byWidgetPredicate(
      (widget) => '${widget.key}'.contains('shuttle-'),
    );
    expect(
      [for (final element in shuttles.evaluate()) '${element.widget.key}'],
      ["[<'shuttle-outer'>]", "[<'shuttle-inner'>]"],
    );
  });

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

  testWidgets('flies on when its sky mounts anew mid-flight', (tester) async {
    final slot = ValueNotifier(0);
    addTearDown(slot.dispose);
    final wrapped = ValueNotifier(false);
    addTearDown(wrapped.dispose);

    await tester.pumpWidget(
      _SlotSwitcher(
        slot: slot,
        // Wrapping the sky in one more widget mounts it anew.
        layoutBuilder: (child, sky) => Stack(
          children: [
            child,
            ValueListenableBuilder(
              valueListenable: wrapped,
              builder: (context, wrapped, _) =>
                  wrapped ? KeyedSubtree(child: sky) : sky,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    slot.value = 1;
    await _pumpSwitch(tester);
    await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 4);

    wrapped.value = true;
    await tester.pump();

    // The flight lands on the second slot, then flies on to the third.
    slot.value = 2;
    await _pumpSwitch(tester);
    final shuttle = find.byKey(_shuttleKey);
    for (var frame = 0; frame < 40 && tester.any(shuttle); frame++) {
      await tester.pump(const Duration(milliseconds: 16));
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

    // A switch while it turns back, with the same child, changes nothing.
    tester.element(find.byType(HeroHereSwitcher)).markNeedsBuild();
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
    // It takes as long as it flew, not a whole flight.
    expect(
      lefts.length * 16,
      lessThan(HeroHere.defaultFlightAnimationDuration.inMilliseconds * 3 / 4),
    );
    expect(shuttle, findsNothing);
    expect(find.byKey(const ValueKey('box0')), findsOneWidget);
  });

  testWidgets('swings a diverted hero around to the hero it left', (
    tester,
  ) async {
    final slot = ValueNotifier(0);
    addTearDown(slot.dispose);

    await tester.pumpWidget(
      _SlotSwitcher(slot: slot, redirect: HeroHereFlightRedirect.divert),
    );
    await tester.pumpAndSettle();

    slot.value = 2;
    await _pumpSwitch(tester);
    await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 2);

    const frame = Duration(milliseconds: 16);
    final shuttle = find.byKey(_shuttleKey);
    final leftBefore = tester.getRect(shuttle).left;
    await tester.pump(frame);
    final rectAtTurn = tester.getRect(shuttle);
    final stepBefore = rectAtTurn.left - leftBefore;

    // Back to the first slot, straight behind the shuttle.
    slot.value = 0;
    await _pumpSwitch(tester);

    final rects = <Rect>[];
    for (var i = 0; i < 40 && tester.any(shuttle); i++) {
      await tester.pump(frame);
      if (tester.any(shuttle)) rects.add(tester.getRect(shuttle));
    }

    // It carries on at the speed it had, swings out to the side and comes
    // around to the first slot, rather than doubling back on its path.
    expect(
      rects.first.left - rectAtTurn.left,
      closeTo(stepBefore, stepBefore / 4),
    );
    final swing = rects
        .map((rect) => (rect.center.dy - rectAtTurn.center.dy).abs())
        .reduce((a, b) => a > b ? a : b);
    expect(swing, greaterThan(20));
    expect(rects.last.left, closeTo(_slotRects[0].left, 1));
    expect(shuttle, findsNothing);
    expect(find.byKey(const ValueKey('box0')), findsOneWidget);
  });

  testWidgets('turns a hero back to where the hero it left is now', (
    tester,
  ) async {
    final slot = ValueNotifier(0);
    final shift = ValueNotifier(0.0);
    addTearDown(slot.dispose);
    addTearDown(shift.dispose);

    await tester.pumpWidget(
      _SlotSwitcher(slot: slot, layoutBuilder: _shiftedLayoutBuilder(shift)),
    );
    await tester.pumpAndSettle();

    slot.value = 2;
    await _pumpSwitch(tester);
    await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 2);

    // The heroes move, as on a window resize, then the flight turns back.
    const frame = Duration(milliseconds: 16);
    shift.value = 100;
    await tester.pump(frame);
    await tester.pump(frame);
    final shuttle = find.byKey(_shuttleKey);
    final leftAtTurn = tester.getRect(shuttle).left;
    slot.value = 0;
    await _pumpSwitch(tester);

    final lefts = <double>[];
    for (var i = 0; i < 40 && tester.any(shuttle); i++) {
      lefts.add(tester.getRect(shuttle).left);
      await tester.pump(frame);
    }

    // It turns where it is and lands where the first hero is now.
    final box0 = find.byKey(const ValueKey('box0'));
    expect(lefts.first, leftAtTurn);
    expect(lefts.last, closeTo(tester.getRect(box0).left, 1));
    expect(tester.getRect(box0).left, _slotRects[0].left + 100);
  });

  testWidgets('turns a hero around again where its shuttle is', (tester) async {
    final slot = ValueNotifier(0);
    final shift = ValueNotifier(0.0);
    addTearDown(slot.dispose);
    addTearDown(shift.dispose);

    await tester.pumpWidget(
      _SlotSwitcher(slot: slot, layoutBuilder: _shiftedLayoutBuilder(shift)),
    );
    await tester.pumpAndSettle();

    slot.value = 2;
    await _pumpSwitch(tester);
    await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 2);

    // The heroes move, the flight turns back, then on again.
    const frame = Duration(milliseconds: 16);
    shift.value = 100;
    await tester.pump(frame);
    await tester.pump(frame);
    slot.value = 0;
    await _pumpSwitch(tester);
    await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 4);

    final shuttle = find.byKey(_shuttleKey);
    final leftAtTurn = tester.getRect(shuttle).left;
    slot.value = 2;
    await _pumpSwitch(tester);

    final lefts = <double>[];
    for (var i = 0; i < 40 && tester.any(shuttle); i++) {
      lefts.add(tester.getRect(shuttle).left);
      await tester.pump(frame);
    }

    // It turns where it is and lands where the third hero is now.
    final box2 = find.byKey(const ValueKey('box2'));
    expect(lefts.first, leftAtTurn);
    expect(lefts.last, closeTo(tester.getRect(box2).left, 1));
    expect(tester.getRect(box2).left, _slotRects[2].left + 100);
  });

  for (final again in [false, true]) {
    testWidgets('turns a hero ${again ? 'around again' : 'back'} to where the '
        'hero it heads for moves once it turned', (tester) async {
      final slot = ValueNotifier(0);
      final nudge = ValueNotifier(0.0);
      addTearDown(slot.dispose);
      addTearDown(nudge.dispose);

      await tester.pumpWidget(_SlotSwitcher(slot: slot, nudge: nudge));
      await tester.pumpAndSettle();

      slot.value = 2;
      await _pumpSwitch(tester);
      await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 2);
      slot.value = 0;
      await _pumpSwitch(tester);
      if (again) {
        await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 4);
        slot.value = 2;
        await _pumpSwitch(tester);
      }

      // The hero it heads for moves within the switcher, after it turned.
      const frame = Duration(milliseconds: 16);
      nudge.value = 100;
      final shuttle = find.byKey(_shuttleKey);
      final lefts = <double>[];
      for (var i = 0; i < 40 && tester.any(shuttle); i++) {
        await tester.pump(frame);
        if (tester.any(shuttle)) lefts.add(tester.getRect(shuttle).left);
      }

      // It lands where that hero is now.
      final box = find.byKey(ValueKey('box${again ? 2 : 0}'));
      expect(tester.getRect(box).left, _slotRects[again ? 2 : 0].left + 100);
      expect(lefts, isNotEmpty);
      expect(lefts.last, closeTo(tester.getRect(box).left, 1));
    });
  }

  testWidgets('diverts a redirected hero straight from where its shuttle is', (
    tester,
  ) async {
    final slot = ValueNotifier(0);
    addTearDown(slot.dispose);

    await tester.pumpWidget(
      _SlotSwitcher(slot: slot, redirect: HeroHereFlightRedirect.divert),
    );
    await tester.pumpAndSettle();

    slot.value = 2;
    await _pumpSwitch(tester);
    await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 4);

    // Redirect the flight to the middle slot while it is near the first.
    final shuttle = find.byKey(_shuttleKey);
    final leftAtDivert = tester.getRect(shuttle).left;
    slot.value = 1;
    await _pumpSwitch(tester);

    final lefts = <double>[];
    final tops = <double>[];
    for (var frame = 0; frame < 40 && tester.any(shuttle); frame++) {
      lefts.add(tester.getRect(shuttle).left);
      tops.add(tester.getRect(shuttle).top);
      await tester.pump(const Duration(milliseconds: 16));
    }

    // It goes on from where it was, never toward the third slot, and takes
    // the full duration to get to the middle one. The middle slot is ahead
    // of it, so it doesn't swing out to the side.
    expect(lefts.first, closeTo(leftAtDivert, 1));
    for (var i = 1; i < lefts.length; i++) {
      expect(lefts[i], greaterThanOrEqualTo(lefts[i - 1]), reason: '$lefts');
    }
    expect(lefts.last, closeTo(_slotRects[1].left, 1));
    expect(tops, everyElement(closeTo(_slotRects[1].top, 1)));
    expect(
      lefts.length * 16,
      greaterThanOrEqualTo(
        HeroHere.defaultFlightAnimationDuration.inMilliseconds,
      ),
    );
    expect(shuttle, findsNothing);
    expect(find.byKey(const ValueKey('box1')), findsOneWidget);
  });

  testWidgets('diverts a flight on the frame it lands, as on the web', (
    tester,
  ) async {
    final slot = ValueNotifier(0);
    addTearDown(slot.dispose);

    await tester.pumpWidget(
      _SlotSwitcher(slot: slot, redirect: HeroHereFlightRedirect.divert),
    );
    await tester.pumpAndSettle();

    slot.value = 2;
    await _pumpSwitch(tester);
    const frame = Duration(milliseconds: 16);
    await tester.pump(HeroHere.defaultFlightAnimationDuration - frame);

    // Redirect the flight to the middle slot on the frame it lands.
    slot.value = 1;
    await tester.pump();
    await _pumpWebFrame(tester, frame * 2);

    // It flies on to the middle slot rather than landing on it at once.
    final shuttle = find.byKey(_shuttleKey);
    expect(shuttle, findsOneWidget);
    expect(find.byKey(const ValueKey('box1')), findsNothing);
    await tester.pumpAndSettle();
    expect(shuttle, findsNothing);
    expect(find.byKey(const ValueKey('box1')), findsOneWidget);
  });

  testWidgets('stops a flight on the frame it lands, as on the web', (
    tester,
  ) async {
    final slot = ValueNotifier(0);
    addTearDown(slot.dispose);

    await tester.pumpWidget(_SlotSwitcher(slot: slot));
    await tester.pumpAndSettle();

    // A flight to the middle slot, then on to the third.
    slot.value = 1;
    await _pumpSwitch(tester);
    slot.value = 2;
    await _pumpSwitch(tester);
    const frame = Duration(milliseconds: 16);
    await tester.pump(HeroHere.defaultFlightAnimationDuration - frame);

    // Take the hero away on the frame it lands on the middle slot.
    slot.value = _noSlot;
    await tester.pump();
    await _pumpWebFrame(tester, frame * 2);

    expect(find.byKey(_shuttleKey), findsNothing);
    await tester.pumpAndSettle();
    expect(find.byKey(_shuttleKey), findsNothing);
  });

  testWidgets('shows a shuttle that lands while a switch shows its snapshot', (
    tester,
  ) async {
    final slot = ValueNotifier(0);
    addTearDown(slot.dispose);

    await tester.pumpWidget(_SlotSwitcher(slot: slot));
    await tester.pumpAndSettle();

    slot.value = 2;
    await _pumpSwitch(tester);
    const frame = Duration(milliseconds: 16);
    await tester.pump(HeroHere.defaultFlightAnimationDuration - frame);

    // The switch snapshots the child with the hero the flight lands on
    // hidden, and the flight lands on the next frame, which shows that
    // snapshot.
    slot.value = 1;
    await tester.pump();
    await tester.pump(frame * 2);

    final shuttle = find.byKey(_shuttleKey);
    expect(shuttle, findsOneWidget);
    expect(tester.getRect(shuttle), _slotRects[2]);
    await tester.pumpAndSettle();
    expect(shuttle, findsNothing);
    expect(find.byKey(const ValueKey('box1')), findsOneWidget);
  });

  testWidgets('shows a shuttle that lands back while a switch shows its '
      'snapshot', (tester) async {
    final slot = ValueNotifier(0);
    addTearDown(slot.dispose);

    await tester.pumpWidget(_SlotSwitcher(slot: slot));
    await tester.pumpAndSettle();

    slot.value = 1;
    await _pumpSwitch(tester);
    await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 2);

    // Back to the first slot, which takes as long as it flew.
    slot.value = 0;
    await _pumpSwitch(tester);
    const frame = Duration(milliseconds: 16);
    await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 2 - frame);

    // The flight lands back on the frame that shows the next switch's
    // snapshot, in which the hero it lands on is hidden.
    slot.value = 2;
    await tester.pump();
    await tester.pump(frame * 2);

    final shuttle = find.byKey(_shuttleKey);
    expect(shuttle, findsOneWidget);
    expect(tester.getRect(shuttle), _slotRects[0]);
    await tester.pumpAndSettle();
    expect(shuttle, findsNothing);
    expect(find.byKey(const ValueKey('box2')), findsOneWidget);
  });

  testWidgets('shows a shuttle that lands after a switch snapshots its frame, '
      'as on the web', (tester) async {
    final slot = ValueNotifier(0);
    addTearDown(slot.dispose);

    await tester.pumpWidget(_SlotSwitcher(slot: slot));
    await tester.pumpAndSettle();

    slot.value = 2;
    await _pumpSwitch(tester);
    const frame = Duration(milliseconds: 16);
    await tester.pump(HeroHere.defaultFlightAnimationDuration - frame);

    // The flight lands after the switch on its frame snapshots the child with
    // the hero it lands on hidden.
    slot.value = 1;
    await _pumpWebFrame(tester, frame * 2);

    final shuttle = find.byKey(_shuttleKey);
    expect(shuttle, findsOneWidget);
    expect(tester.getRect(shuttle), _slotRects[2]);
    await tester.pumpAndSettle();
    expect(shuttle, findsNothing);
    expect(find.byKey(const ValueKey('box1')), findsOneWidget);
  });

  testWidgets('turns a flight around on the frame it lands back, as on the '
      'web', (tester) async {
    final slot = ValueNotifier(0);
    addTearDown(slot.dispose);

    await tester.pumpWidget(_SlotSwitcher(slot: slot));
    await tester.pumpAndSettle();

    slot.value = 1;
    await _pumpSwitch(tester);
    await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 2);

    // Back to the first slot, which takes as long as it flew.
    slot.value = 0;
    await _pumpSwitch(tester);
    const frame = Duration(milliseconds: 16);
    await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 2 - frame);

    // On to the middle slot again on the frame it lands back.
    slot.value = 1;
    await tester.pump();
    await _pumpWebFrame(tester, frame * 2);

    final shuttle = find.byKey(_shuttleKey);
    expect(shuttle, findsOneWidget);
    expect(find.byKey(const ValueKey('box1')), findsNothing);
    await tester.pumpAndSettle();
    expect(shuttle, findsNothing);
    expect(find.byKey(const ValueKey('box1')), findsOneWidget);
  });

  testWidgets('carries a diverted hero on at the speed its shuttle had', (
    tester,
  ) async {
    final slot = ValueNotifier(0);
    addTearDown(slot.dispose);

    await tester.pumpWidget(
      _SlotSwitcher(slot: slot, redirect: HeroHereFlightRedirect.divert),
    );
    await tester.pumpAndSettle();

    slot.value = 2;
    await _pumpSwitch(tester);
    await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 2);

    // At full speed past the middle slot, redirect the flight to it.
    final shuttle = find.byKey(_shuttleKey);
    const frame = Duration(milliseconds: 16);
    final leftBefore = tester.getRect(shuttle).left;
    await tester.pump(frame);
    final left = tester.getRect(shuttle).left;
    final stepBefore = left - leftBefore;
    expect(stepBefore, greaterThan(10));

    slot.value = 1;
    await _pumpSwitch(tester);
    expect(tester.getRect(shuttle).left, left);
    await tester.pump(frame);

    // It goes on at about the speed it had rather than stopping, then turns
    // back and lands on the middle slot.
    final stepAfter = tester.getRect(shuttle).left - left;
    expect(stepAfter, closeTo(stepBefore, stepBefore / 4));
    await tester.pumpAndSettle();
    expect(shuttle, findsNothing);
    expect(find.byKey(const ValueKey('box1')), findsOneWidget);
  });

  testWidgets('carries a diverted hero on at its own speed as heroes move', (
    tester,
  ) async {
    final slot = ValueNotifier(0);
    final shift = ValueNotifier(0.0);
    addTearDown(slot.dispose);
    addTearDown(shift.dispose);

    await tester.pumpWidget(
      _SlotSwitcher(
        slot: slot,
        redirect: HeroHereFlightRedirect.divert,
        layoutBuilder: _shiftedLayoutBuilder(shift),
      ),
    );
    await tester.pumpAndSettle();

    slot.value = 2;
    await _pumpSwitch(tester);
    await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 2);

    final shuttle = find.byKey(_shuttleKey);
    const frame = Duration(milliseconds: 16);
    final leftBefore = tester.getRect(shuttle).left;
    await tester.pump(frame);
    final stepBefore = tester.getRect(shuttle).left - leftBefore;

    // The hero it flies to jumps right, and the shuttle with it, just before
    // the flight diverts.
    shift.value = 200;
    await tester.pump(frame);
    await tester.pump(frame);
    final left = tester.getRect(shuttle).left;

    slot.value = 1;
    await _pumpSwitch(tester);
    await tester.pump(frame);

    // It goes on at about the speed it flew at, not at the jump's.
    final stepAfter = tester.getRect(shuttle).left - left;
    expect(stepAfter, inExclusiveRange(stepBefore / 2, stepBefore * 2));
  });

  for (final (edge, flipped) in [('bottom', false), ('right', true)]) {
    testWidgets('keeps a diverted shuttle inside the switcher as it swings '
        'toward its $edge edge', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 600);
      addTearDown(tester.view.reset);
      final slot = ValueNotifier(0);
      addTearDown(slot.dispose);
      const size = Size(60, 60);

      // Heroes near the edge. The flight along it diverts to a hero behind it
      // and a bit nearer the edge, so it swings toward the edge.
      Alignment along(double x, double y) =>
          flipped ? Alignment(y, x) : Alignment(x, y);
      await tester.pumpWidget(
        _AlignSwitcher(
          slot: slot,
          redirect: HeroHereFlightRedirect.divert,
          spots: [
            (alignment: along(-0.7, 0.93), size: size),
            (alignment: along(0.7, 0.93), size: size),
            (alignment: along(-0.9, 1), size: size),
          ],
        ),
      );
      await tester.pumpAndSettle();

      slot.value = 1;
      await _pumpSwitch(tester);
      await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 2);
      slot.value = 2;
      await _pumpSwitch(tester);

      final shuttle = find.byKey(_shuttleKey);
      var farthest = 0.0;
      while (tester.any(shuttle)) {
        final rect = tester.getRect(shuttle);
        farthest = max(farthest, flipped ? rect.right : rect.bottom);
        await tester.pump(const Duration(milliseconds: 8));
      }
      expect(farthest, lessThanOrEqualTo(flipped ? 800 : 600));
    });
  }

  testWidgets('flies a diverted hero back straight from where its shuttle is', (
    tester,
  ) async {
    final slot = ValueNotifier(0);
    addTearDown(slot.dispose);

    await tester.pumpWidget(
      _SlotSwitcher(slot: slot, redirect: HeroHereFlightRedirect.divert),
    );
    await tester.pumpAndSettle();

    slot.value = 2;
    await _pumpSwitch(tester);
    await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 4);
    slot.value = 1;
    await _pumpSwitch(tester);
    await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 2);

    // Back to the first slot: the diverted leg didn't start there, so the
    // shuttle can't get there by turning back.
    slot.value = 0;
    await _pumpSwitch(tester);

    // A switch on the way, with the same child, changes nothing.
    final shuttle = find.byKey(_shuttleKey);
    final leftBeforeSwitch = tester.getRect(shuttle).left;
    tester.element(find.byType(HeroHereSwitcher)).markNeedsBuild();
    await _pumpSwitch(tester);

    expect(tester.getRect(shuttle).left, leftBeforeSwitch);
    final lefts = <double>[];
    for (var frame = 0; frame < 40 && tester.any(shuttle); frame++) {
      lefts.add(tester.getRect(shuttle).left);
      await tester.pump(const Duration(milliseconds: 16));
    }

    // It carries on toward the middle slot a little at the speed it had,
    // short of it, then turns once and flies to the first slot.
    final farthest = lefts.reduce((a, b) => a > b ? a : b);
    final turn = lefts.indexOf(farthest);
    expect(farthest, lessThan(_slotRects[1].left));
    for (var i = 1; i < lefts.length; i++) {
      expect(
        lefts[i],
        i <= turn
            ? greaterThanOrEqualTo(lefts[i - 1])
            : lessThanOrEqualTo(lefts[i - 1]),
        reason: '$lefts',
      );
    }
    expect(lefts.last, closeTo(_slotRects[0].left, 1));
    expect(shuttle, findsNothing);
    expect(find.byKey(const ValueKey('box0')), findsOneWidget);
  });

  testWidgets('shuttles what its shuttle showed when it diverts', (
    tester,
  ) async {
    final slot = ValueNotifier(0);
    addTearDown(slot.dispose);
    final fromHeroes = <HeroHere>[];

    await tester.pumpWidget(
      _SlotSwitcher(
        slot: slot,
        redirect: HeroHereFlightRedirect.divert,
        // Fades the hero the flight leaves out into the one it lands on.
        shuttleBuilder: (_, animation, fromHero, toHero) {
          fromHeroes.add(fromHero);
          return Stack(
            fit: StackFit.expand,
            children: [
              toHero.child,
              FadeTransition(
                opacity: ReverseAnimation(animation),
                child: fromHero.child,
              ),
            ],
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    slot.value = 2;
    await _pumpSwitch(tester);
    await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 4);

    final box0 = find.byKey(const ValueKey('box0'));
    final box2 = find.byKey(const ValueKey('box2'));
    final box0Opacity = _opacityOf(tester, box0);
    expect(box0Opacity, inExclusiveRange(0, 1));

    slot.value = 1;
    await _pumpSwitch(tester);

    // The new leg starts from the shuttle as it was: the hero it left half
    // faded out over the one it flew to, then fades that out.
    expect(_opacityOf(tester, box0), closeTo(box0Opacity, 0.001));
    expect(_opacityOf(tester, box2), 1);
    expect(fromHeroes.last.tag, 'hero');
    expect(fromHeroes.last.key, const ValueKey(0));

    // Back to the first slot, so the hero it leaves is the one it lands on.
    // The new leg starts from the shuttle as it was again.
    await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 4);
    final box1 = find.byKey(const ValueKey('box1'));
    final box2Opacity = _opacityOf(tester, box2);
    expect(box2Opacity, inExclusiveRange(0, 1));
    expect(_opacityOf(tester, box1), 1);

    slot.value = 0;
    await _pumpSwitch(tester);

    expect(_opacityOf(tester, box2), closeTo(box2Opacity, 0.001));
    expect(_opacityOf(tester, box1), 1);
    expect(fromHeroes.last.key, const ValueKey(0));

    await tester.pumpAndSettle();
    expect(box1, findsNothing);
    expect(box2, findsNothing);
    expect(box0, findsOneWidget);
  });

  testWidgets('flies back, then on to where its child changes next', (
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

    // Send the hero to the third slot while it flies back to the first.
    slot.value = 2;
    await _pumpSwitch(tester);

    final shuttle = find.byKey(_shuttleKey);
    final lefts = <double>[];
    for (var frame = 0; frame < 60 && tester.any(shuttle); frame++) {
      lefts.add(tester.getRect(shuttle).left);
      await tester.pump(const Duration(milliseconds: 16));
    }

    // It lands back on the first slot before it flies on.
    expect(lefts.reduce((a, b) => a < b ? a : b), _slotRects[0].left);
    expect(lefts.last, greaterThan(_slotRects[1].left));
    expect(shuttle, findsNothing);
    expect(find.byKey(const ValueKey('box2')), findsOneWidget);
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

  testWidgets('flies on to where the hero it flies to was when that one '
      'mounts anew, then goes away', (tester) async {
    final moved = ValueNotifier(false), b = ValueNotifier(0);
    addTearDown(moved.dispose);
    addTearDown(b.dispose);
    const duration = HeroHere.defaultFlightAnimationDuration;

    await tester.pumpWidget(_GoneSwitcher(moved: moved, b: b));
    await tester.pumpAndSettle();

    moved.value = true;
    await _pumpSwitch(tester);
    await tester.pump(duration ~/ 4);

    // No switch: the hero the flight lands on mounts anew, then goes away.
    b.value = 1;
    await tester.pump();
    b.value = 2;
    await tester.pump();
    final shuttle = find.byKey(_shuttleKey);
    final gone = tester.getRect(shuttle);

    await tester.pump(duration ~/ 2);

    final to = _slotRects[1].center;
    final now = tester.getRect(shuttle);
    expect(
      (now.center - to).distance,
      lessThan((gone.center - to).distance / 2),
    );
  });

  testWidgets('lands on a next hero that mounts anew without a switch', (
    tester,
  ) async {
    final slot = ValueNotifier(0), wrapped = ValueNotifier(false);
    addTearDown(slot.dispose);
    addTearDown(wrapped.dispose);

    await tester.pumpWidget(_ChainSwitcher(slot: slot, wrapped: wrapped));
    await tester.pumpAndSettle();

    slot.value = 1;
    await _pumpSwitch(tester);
    await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 4);

    // The flight goes on to the third slot once it lands on the second.
    slot.value = 2;
    await _pumpSwitch(tester);

    // The hero in the third slot mounts anew, without rebuilding the switcher.
    wrapped.value = true;
    await tester.pumpAndSettle();

    expect(find.byKey(_shuttleKey), findsNothing);
    expect(find.byKey(const ValueKey('box2')), findsOneWidget);
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

  for (final (extra, how) in [(1, ''), (2, ', then mounts anew')]) {
    testWidgets('shows a hero that mounts mid-flight$how once it lands', (
      tester,
    ) async {
      final slot = ValueNotifier(0);
      addTearDown(slot.dispose);
      final extraHero = ValueNotifier(0);
      addTearDown(extraHero.dispose);
      final rebuilds = ValueNotifier(0);
      addTearDown(rebuilds.dispose);

      await tester.pumpWidget(
        _ExtraSwitcher(slot: slot, extra: extraHero, rebuilds: rebuilds),
      );
      await tester.pumpAndSettle();

      slot.value = 1;
      await _pumpSwitch(tester);
      await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 4);

      // No switch: the hero mounts below the switcher.
      for (var value = 1; value <= extra; value++) {
        extraHero.value = value;
        await tester.pump();
      }
      final extraBox = find.byKey(
        const ValueKey('box-extra'),
        skipOffstage: false,
      );
      expect(find.byKey(const ValueKey('box-extra')), findsNothing);
      expect(_painted(tester, extraBox), isFalse);

      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('box1')), findsOneWidget);
      expect(find.byKey(const ValueKey('box-extra')), findsOneWidget);
      expect(_painted(tester, extraBox), isTrue);
    });
  }

  testWidgets('keeps a hero that mounts mid-flight hidden when a switch hides '
      'it', (tester) async {
    final slot = ValueNotifier(0);
    addTearDown(slot.dispose);
    final extraHero = ValueNotifier(0);
    addTearDown(extraHero.dispose);
    final rebuilds = ValueNotifier(0);
    addTearDown(rebuilds.dispose);

    await tester.pumpWidget(
      _ExtraSwitcher(slot: slot, extra: extraHero, rebuilds: rebuilds),
    );
    await tester.pumpAndSettle();

    slot.value = 1;
    await _pumpSwitch(tester);
    await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 4);

    extraHero.value = 1;
    await tester.pump();

    // The switch hides the extra hero, since a later one with its tag shows.
    rebuilds.value++;
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('box1')), findsOneWidget);
    expect(find.byKey(const ValueKey('box-extra')), findsNothing);
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

  testWidgets('flies nothing between new heroes that bring a new tag', (
    tester,
  ) async {
    final twice = ValueNotifier(false);
    addTearDown(twice.dispose);

    await tester.pumpWidget(_NewTagSwitcher(twice: twice));
    await tester.pumpAndSettle();

    twice.value = true;
    await _pumpSwitch(tester);

    // As on mount, the last of them shows at once and the earlier one hides.
    final shuttle = find.byKey(_shuttleKey);
    for (var frame = 0; frame < 30; frame++) {
      expect(shuttle, findsNothing);
      expect(find.byKey(const ValueKey('box0')), findsNothing);
      expect(find.byKey(const ValueKey('box2')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 16));
    }
  });

  testWidgets('shows a hero whose child arrives as its switch flies', (
    tester,
  ) async {
    final slot = ValueNotifier(0);
    addTearDown(slot.dispose);

    await tester.pumpWidget(_SlotSwitcher(slot: slot));
    await tester.pumpAndSettle();

    slot.value = 1;
    await tester.pump(); // The switch to the second slot flies after this.
    slot.value = 2; // The third slot arrives as that flight starts.
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('box2')), findsOneWidget);
  });

  testWidgets('shows the new child on the frame it rebuilds, with a stand-in '
      'where the hero it leaves was', (tester) async {
    final slot = ValueNotifier(0);
    addTearDown(slot.dispose);

    await tester.pumpWidget(_LabelSwitcher(slot: slot));
    await tester.pumpAndSettle();
    final leftLayer = _layerOf(tester, find.byKey(const ValueKey('box0')))!;

    slot.value = 1;
    await tester.pump();

    // The new child shows, but not the hero the flight lands on, while the
    // hero the flight leaves stands in where it was, as it last painted.
    expect(find.text('label 1'), findsOneWidget);
    expect(_painted(tester, find.byKey(const ValueKey('box1'))), isFalse);
    expect(leftLayer.attached, isTrue);
    expect(_paintedAt(leftLayer), _slotRects[0].topLeft);

    // The flight starts where the stand-in was, and the stand-in goes.
    await tester.pump();
    expect(leftLayer.attached, isFalse);
    expect(tester.getRect(find.byKey(_shuttleKey)), _slotRects[0]);

    await tester.pumpAndSettle();
    expect(_painted(tester, find.byKey(const ValueKey('box1'))), isTrue);
  });

  testWidgets('shows a stand-in where the hero it leaves was, in a child laid '
      'out away from the sky', (tester) async {
    final slot = ValueNotifier(0), shift = ValueNotifier(100.0);
    addTearDown(slot.dispose);
    addTearDown(shift.dispose);

    await tester.pumpWidget(
      _SlotSwitcher(slot: slot, layoutBuilder: _shiftedLayoutBuilder(shift)),
    );
    await tester.pumpAndSettle();
    final box0 = find.byKey(const ValueKey('box0'));
    final leftRect = tester.getRect(box0);
    final leftLayer = _layerOf(tester, box0)!;

    slot.value = 1;
    await tester.pump();

    // The sky is at the screen's origin, so the stand-in is where the hero
    // was on the screen.
    expect(leftLayer.attached, isTrue);
    expect(_paintedAt(leftLayer), leftRect.topLeft);
  });

  testWidgets('stands in for a hero that a switch takes away as a flight '
      'lands on it', (tester) async {
    final slot = ValueNotifier(0);
    addTearDown(slot.dispose);
    const duration = HeroHere.defaultFlightAnimationDuration;

    await tester.pumpWidget(_SlotSwitcher(slot: slot));
    await tester.pumpAndSettle();

    slot.value = 1;
    await _pumpSwitch(tester);
    await tester.pump(duration);
    final shuttleLayer = _layerOf(tester, find.byKey(_shuttleKey))!;

    // The flight lands at the start of the frame of the switch that takes the
    // hero it lands on away, so that hero never painted, but stands in for
    // itself all the same, as the flight's shuttle last showed it.
    slot.value = 2;
    await tester.pump(const Duration(milliseconds: 1));

    expect(shuttleLayer.attached, isTrue);
    expect(_paintedAt(shuttleLayer), _slotRects[1].topLeft);
  });

  testWidgets('hides the hero that a switch redirects a flight to from the '
      'frame it rebuilds', (tester) async {
    final slot = ValueNotifier(0);
    addTearDown(slot.dispose);

    await tester.pumpWidget(_SlotSwitcher(slot: slot));
    await tester.pumpAndSettle();

    slot.value = 1;
    await _pumpSwitch(tester);
    await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 2);

    slot.value = 2;
    await tester.pump();

    expect(
      _painted(tester, find.byKey(const ValueKey('box2'), skipOffstage: false)),
      isFalse,
    );
  });

  testWidgets('stands in for a hero with its own layer once it paints after '
      'a flight lands on it', (tester) async {
    final slot = ValueNotifier(0);
    addTearDown(slot.dispose);

    await tester.pumpWidget(_SlotSwitcher(slot: slot));
    await tester.pumpAndSettle();

    slot.value = 1;
    await _pumpSwitch(tester);
    await tester.pump(HeroHere.defaultFlightAnimationDuration);
    final shuttleLayer = _layerOf(tester, find.byKey(_shuttleKey))!;
    await tester.pumpAndSettle();
    final box1 = find.byKey(const ValueKey('box1'));
    final heroLayer = _layerOf(tester, box1)!;

    slot.value = 2;
    await tester.pump();

    expect(heroLayer.attached, isTrue);
    expect(_paintedAt(heroLayer), _slotRects[1].topLeft);
    expect(shuttleLayer.debugDisposed, isTrue);
  });

  for (final (how, inBoundary) in [('', false), (', in a layer', true)]) {
    testWidgets('stands in for a hero with the clip around it$how', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 600);
      addTearDown(tester.view.reset);
      final slot = ValueNotifier(0);
      addTearDown(slot.dispose);

      await tester.pumpWidget(
        _ClippedSwitcher(slot: slot, inBoundary: inBoundary),
      );
      await tester.pumpAndSettle();
      const red = Color(0xFFFF0000);
      expect(
        await _pixelAt(tester, _clippedRect.topLeft + const Offset(4, 4)),
        isNot(red),
      );

      slot.value = 1;
      await tester.pump();

      // The stand-in keeps the rounded corners the clip gave the hero.
      expect(await _pixelAt(tester, _clippedRect.center), red);
      expect(
        await _pixelAt(tester, _clippedRect.topLeft + const Offset(4, 4)),
        isNot(red),
      );
    });
  }

  testWidgets('disposes the layer a stand-in shows once it goes', (
    tester,
  ) async {
    final slot = ValueNotifier(0);
    addTearDown(slot.dispose);

    await tester.pumpWidget(_SlotSwitcher(slot: slot));
    await tester.pumpAndSettle();
    final leftLayer = _layerOf(tester, find.byKey(const ValueKey('box0')))!;

    slot.value = 1;
    await tester.pumpAndSettle();

    expect(leftLayer.debugDisposed, isTrue);
  });

  testWidgets('shows a hero that stays as it is, with no stand-in', (
    tester,
  ) async {
    final slot = ValueNotifier(0), label = ValueNotifier(0);
    addTearDown(slot.dispose);
    addTearDown(label.dispose);

    await tester.pumpWidget(_LabelSwitcher(slot: slot, label: label));
    await tester.pumpAndSettle();

    label.value = 1;
    await tester.pump();

    final box = find.byKey(const ValueKey('box0'));
    expect(find.text('label 1'), findsOneWidget);
    expect(_paintedInPlace(tester, box), isTrue);

    await tester.pumpAndSettle();
    expect(_paintedInPlace(tester, box), isTrue);
    expect(find.byKey(_shuttleKey), findsNothing);
  });

  testWidgets('shows a hero that mounts anew with nowhere to fly once its '
      'switch flies', (tester) async {
    final moved = ValueNotifier(false), wrapped = ValueNotifier(false);
    addTearDown(moved.dispose);
    addTearDown(wrapped.dispose);

    await tester.pumpWidget(_RemountSwitcher(moved: moved, wrapped: wrapped));
    await tester.pumpAndSettle();
    final box = find.byKey(const ValueKey('box0'));
    final oldLayer = _layerOf(tester, box)!;

    // The switch mounts the hero anew, in one more widget, in the same place,
    // so the old one stands in for it.
    wrapped.value = true;
    await tester.pump();

    expect(_painted(tester, box), isFalse);
    expect(oldLayer.attached, isTrue);

    // Nothing flies: the hero shows, and the stand-in goes.
    await tester.pump();
    expect(_painted(tester, box), isTrue);
    expect(oldLayer.attached, isFalse);
    expect(find.byKey(_shuttleKey), findsNothing);
  });

  testWidgets('flies a hero that a layout builder in its child builds', (
    tester,
  ) async {
    final slot = ValueNotifier(0);
    addTearDown(slot.dispose);

    await tester.pumpWidget(_LabelSwitcher(slot: slot, inLayoutBuilder: true));
    await tester.pumpAndSettle();
    final leftLayer = _layerOf(tester, find.byKey(const ValueKey('box0')))!;

    slot.value = 1;
    await tester.pump();

    // Built as the frame lays out, the hero hides on that frame all the same,
    // and the hero it replaces, which went away as the frame laid out, stands
    // in for it.
    final box1 = find.byKey(const ValueKey('box1'));
    expect(_painted(tester, box1), isFalse);
    expect(leftLayer.attached, isTrue);

    await tester.pump();
    await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 2);
    final shuttle = tester.getRect(find.byKey(_shuttleKey));
    expect(shuttle, isNot(_slotRects[0]));
    expect(shuttle, isNot(_slotRects[1]));

    await tester.pumpAndSettle();
    expect(_painted(tester, box1), isTrue);
  });

  testWidgets('moves a hero in place while its switch key stays, and flies '
      'it when the key changes', (tester) async {
    final slot = ValueNotifier(0);
    final switchKey = ValueNotifier<Object?>('a');
    addTearDown(slot.dispose);
    addTearDown(switchKey.dispose);

    await tester.pumpWidget(_LabelSwitcher(slot: slot, switchKey: switchKey));
    await tester.pumpAndSettle();

    slot.value = 1;
    await tester.pump();

    // It shows in its new place at once, and nothing flies.
    final shuttle = find.byKey(_shuttleKey);
    expect(_painted(tester, find.byKey(const ValueKey('box1'))), isTrue);
    expect(shuttle, findsNothing);
    await tester.pump();
    expect(shuttle, findsNothing);

    switchKey.value = 'b';
    slot.value = 2;
    await _pumpSwitch(tester);

    expect(shuttle, findsOneWidget);
  });

  testWidgets('shows a child with the same switch key on the frame it '
      'rebuilds', (tester) async {
    final rebuilds = ValueNotifier(0);
    final switchKey = ValueNotifier<Object?>('a');
    addTearDown(rebuilds.dispose);
    addTearDown(switchKey.dispose);

    await tester.pumpWidget(
      _RebuildSwitcher(
        rebuilds: rebuilds,
        sameChild: false,
        switchKey: switchKey,
      ),
    );
    await tester.pumpAndSettle();

    rebuilds.value++;
    await tester.pump();

    expect(find.byKey(const ValueKey(1)), findsOneWidget);
  });

  for (final (how, keyed, looksBelow) in [
    ('a switch', false, false),
    ('an update in place', true, false),
    ('a rebuild below the switcher', false, true),
  ]) {
    testWidgets('shuttles the new child that $how gives a hero mid-flight', (
      tester,
    ) async {
      final slot = ValueNotifier(0), look = ValueNotifier('a');
      addTearDown(slot.dispose);
      addTearDown(look.dispose);

      await tester.pumpWidget(
        _LookSwitcher(
          slot: slot,
          look: look,
          keyed: keyed,
          looksBelow: looksBelow,
        ),
      );
      await tester.pumpAndSettle();

      slot.value = 1;
      await _pumpSwitch(tester);
      await tester.pump(const Duration(milliseconds: 100));
      look.value = 'b';
      // A switch shows the new child on its third frame, the others at once.
      keyed || looksBelow ? await tester.pump() : await _pumpSwitch(tester);

      Finder shuttled(String box) => find.descendant(
        of: find.byKey(_shuttleKey),
        matching: find.byKey(ValueKey(box)),
      );
      expect(shuttled('box1b'), findsOneWidget);
      expect(shuttled('box1a'), findsNothing);
    });
  }

  testWidgets('shuttles the new child that a rebuild below the switcher gives '
      'the hero a flight leaves', (tester) async {
    final split = ValueNotifier(false), look = ValueNotifier('a');
    addTearDown(split.dispose);
    addTearDown(look.dispose);

    await tester.pumpWidget(_LeftLookSwitcher(split: split, look: look));
    await tester.pumpAndSettle();

    split.value = true;
    await _pumpSwitch(tester);
    await tester.pump(const Duration(milliseconds: 100));
    look.value = 'b';
    await tester.pump();

    Finder shuttled(String box) => find.descendant(
      of: find.byKey(_shuttleKey),
      matching: find.byKey(ValueKey(box)),
    );
    expect(shuttled('boxb'), findsOneWidget);
    expect(shuttled('boxa'), findsNothing);
  });

  testWidgets('builds the shuttle of a leg once, not on each frame', (
    tester,
  ) async {
    final slot = ValueNotifier(0);
    addTearDown(slot.dispose);
    var builds = 0;

    await tester.pumpWidget(
      _SlotSwitcher(
        slot: slot,
        shuttleBuilder: (_, _, _, _) {
          builds++;
          return const SizedBox.expand(key: _shuttleKey);
        },
      ),
    );
    await tester.pumpAndSettle();

    slot.value = 1;
    await _pumpSwitch(tester);
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(find.byKey(_shuttleKey), findsOneWidget);
    expect(builds, 1);
  });

  testWidgets('shows its heroes on each frame of a window resize, even when '
      'sizes are read above it', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 600);
    addTearDown(tester.view.reset);

    // Each frame of the resize rebuilds the switcher, so runs a switch.
    await tester.pumpWidget(
      MaterialApp(
        home: LayoutBuilder(
          builder: (context, constraints) => HeroHereSwitcher(
            child: Align(
              alignment: Alignment.topLeft,
              child: HeroHere(
                key: const ValueKey('hero'),
                tag: 'hero',
                child: SizedBox(
                  key: const ValueKey('box'),
                  width: constraints.maxWidth / 2,
                  height: 40,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final box = find.byKey(const ValueKey('box'));
    for (final width in [700.0, 600.0, 500.0]) {
      tester.view.physicalSize = Size(width, 600);
      await tester.pump();

      expect(_paintedInPlace(tester, box), isTrue);
      expect(tester.getRect(box), Rect.fromLTWH(0, 0, width / 2, 40));
    }
  });

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

  testWidgets('repaints nothing inside a shuttle that only moves', (
    tester,
  ) async {
    var shuttlePaints = 0;
    final right = ValueNotifier(false);
    addTearDown(right.dispose);

    await tester.pumpWidget(
      _MoveSwitcher(right: right, onPaint: () => shuttlePaints++),
    );
    await tester.pumpAndSettle();

    right.value = true;
    await _pumpSwitch(tester);
    shuttlePaints = 0;
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(find.byKey(_moverKey), findsOneWidget);
    expect(shuttlePaints, 0);
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

  testWidgets('shows the hero a flight leaves when the hero it flies to goes '
      'away mid-flight', (tester) async {
    final split = ValueNotifier(false), bGone = ValueNotifier(false);
    addTearDown(split.dispose);
    addTearDown(bGone.dispose);

    await tester.pumpWidget(_LeftSwitcher(split: split, bGone: bGone));
    await tester.pumpAndSettle();

    split.value = true;
    await _pumpSwitch(tester);
    await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 2);
    expect(find.byKey(_shuttleKey), findsOneWidget);

    // 'b' goes away below the switcher, so no switch says which hero shows.
    bGone.value = true;
    await tester.pumpAndSettle();

    expect(find.byKey(_shuttleKey), findsNothing);
    final a = find.byKey(const ValueKey('box-a'), skipOffstage: false);
    expect(_paintedInPlace(tester, a), isTrue);
  });

  testWidgets('shows the hero a flight left when the hero it turns back to '
      'goes away mid-flight', (tester) async {
    final order = ValueNotifier(0), aGone = ValueNotifier(false);
    addTearDown(order.dispose);
    addTearDown(aGone.dispose);

    await tester.pumpWidget(_TurnSwitcher(order: order, aGone: aGone));
    await tester.pumpAndSettle();

    order.value = 1;
    await _pumpSwitch(tester);
    await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 2);

    // 'a' is the last hero of the tag again, so the flight turns back to it.
    order.value = 2;
    await _pumpSwitch(tester);
    expect(find.byKey(_shuttleKey), findsOneWidget);

    // 'a' goes away below the switcher, so no switch says which hero shows.
    aGone.value = true;
    await tester.pumpAndSettle();

    expect(find.byKey(_shuttleKey), findsNothing);
    final b = find.byKey(const ValueKey('box-b'), skipOffstage: false);
    expect(_paintedInPlace(tester, b), isTrue);
  });

  testWidgets('flies on when a page view moves the page of the hero it '
      'flies to', (tester) async {
    final inPage = ValueNotifier(false);
    addTearDown(inPage.dispose);
    final pages = ValueNotifier(['a', 'b', 'c']);
    addTearDown(pages.dispose);
    final controller = PageController(initialPage: 2);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _PageSwitcher(inPage: inPage, pages: pages, controller: controller),
    );
    await tester.pumpAndSettle();

    inPage.value = true;
    await _pumpSwitch(tester);
    await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 4);
    expect(find.byKey(_shuttleKey), findsOneWidget);

    // Page 'c' moves to an index no page was laid out at, so it has no
    // offset in its sliver until the sliver lays it out, after the flight's
    // next frame measures the hero.
    pages.value = ['b', 'c'];

    final shuttle = find.byKey(_shuttleKey);
    final hero = find.byKey(const ValueKey('page'), skipOffstage: false);
    late Rect shuttleRect, heroRect;
    for (var frame = 0; frame < 40 && tester.any(shuttle); frame++) {
      shuttleRect = tester.getRect(shuttle);
      heroRect = tester.getRect(hero);
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(shuttle, findsNothing);
    expect(
      (shuttleRect.topLeft - heroRect.topLeft).distance,
      lessThan(2),
      reason: 'The shuttle landed at $shuttleRect, the hero is at $heroRect.',
    );
  });

  testWidgets('flies to where its hero is on the frame of a window resize', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 600);
    addTearDown(tester.view.reset);
    final moved = ValueNotifier(false);
    addTearDown(moved.dispose);
    late Animation<double> animation;

    await tester.pumpWidget(
      _QuarterWidthSwitcher(
        moved: moved,
        shuttleBuilder: (_, flight, _, _) {
          animation = flight;
          return const SizedBox.expand(key: _shuttleKey);
        },
      ),
    );
    await tester.pumpAndSettle();
    final fromRect = tester.getRect(find.byKey(const ValueKey('box-false')));

    moved.value = true;
    await _pumpSwitch(tester);
    await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 2);

    // The hero the flight lands on is a quarter of the window wide.
    tester.view.physicalSize = const Size(400, 600);
    await tester.pump(const Duration(milliseconds: 16));

    final toRect = tester.getRect(
      find.byKey(const ValueKey('box-true'), skipOffstage: false),
    );
    expect(toRect, const Rect.fromLTWH(300, 0, 100, 40));
    expect(
      tester.getRect(find.byKey(_shuttleKey)),
      _rectMoreOrLessEquals(Rect.lerp(fromRect, toRect, animation.value)!),
    );
  });

  for (final (where, spot, start) in [
    (
      'at the right edge',
      (alignment: Alignment.topRight, size: const Size(40, 40)),
      const Rect.fromLTWH(360, 0, 40, 40),
    ),
    (
      'off the screen',
      (alignment: const Alignment(2, -1), size: const Size(40, 40)),
      // As far past the right edge as it was: 380 px.
      const Rect.fromLTWH(740, 0, 40, 40),
    ),
    (
      'as wide as the switcher',
      (alignment: Alignment.topCenter, size: const Size(double.infinity, 40)),
      const Rect.fromLTWH(0, 0, 800, 40),
    ),
  ]) {
    testWidgets('starts where the hero it leaves would be after the window '
        'shrinks, when that hero was $where', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 600);
      addTearDown(tester.view.reset);
      final slot = ValueNotifier(0);
      addTearDown(slot.dispose);

      await tester.pumpWidget(
        _AlignSwitcher(
          slot: slot,
          spots: [
            spot,
            (alignment: Alignment.bottomLeft, size: const Size(40, 40)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      slot.value = 1;
      await tester.pump(); // The switch keeps where the hero it leaves is.
      tester.view.physicalSize = const Size(400, 600);
      await tester.pump(); // The flight starts after this frame.
      await tester.pump();

      expect(
        tester.getRect(find.byKey(_shuttleKey)),
        _rectMoreOrLessEquals(start),
      );
    });
  }

  for (final (redirect, how, course) in [
    (HeroHereFlightRedirect.divert, 'diverts', [2]),
    (HeroHereFlightRedirect.chain, 'turns back', [0]),
    (HeroHereFlightRedirect.chain, 'turns around again', [0, 1]),
  ]) {
    testWidgets('$how from where its shuttle would be after the window '
        'shrinks', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 600);
      addTearDown(tester.view.reset);
      final slot = ValueNotifier(0);
      addTearDown(slot.dispose);
      const size = Size(40, 40);

      await tester.pumpWidget(
        _AlignSwitcher(
          slot: slot,
          redirect: redirect,
          spots: const [
            (alignment: Alignment.topLeft, size: size),
            (alignment: Alignment.topRight, size: size),
            (alignment: Alignment.bottomLeft, size: size),
          ],
        ),
      );
      await tester.pumpAndSettle();

      slot.value = 1;
      await _pumpSwitch(tester);
      await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 2);
      for (final next in course) {
        if (next != course.first) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        slot.value = next;
        await tester.pump();
        await tester.pump(); // The flight changes course after this frame.
      }
      final shuttle = find.byKey(_shuttleKey);
      final rect = tester.getRect(shuttle);
      tester.view.physicalSize = const Size(400, 600);
      await tester.pump();

      // Where it was in the free space across the window, which shrank.
      final left = rect.left / (800 - rect.width) * (400 - rect.width);
      expect(
        tester.getRect(shuttle),
        _rectMoreOrLessEquals(rect.translate(left - rect.left, 0)),
      );
    });
  }

  for (final (leg, leaves) in [('first', 0), ('next', 1)]) {
    testWidgets('flies its $leg leg from where the hero it leaves is as that '
        'one moves', (tester) async {
      final count = ValueNotifier(1), shift = ValueNotifier(0.0);
      addTearDown(count.dispose);
      addTearDown(shift.dispose);
      late Animation<double> animation;

      await tester.pumpWidget(
        _ShiftSwitcher(
          count: count,
          shifted: leaves,
          shift: shift,
          shuttleBuilder: (_, flight, _, _) {
            animation = flight;
            return const SizedBox.expand(key: _shuttleKey);
          },
        ),
      );
      await tester.pumpAndSettle();

      const duration = HeroHere.defaultFlightAnimationDuration;
      count.value = 2;
      await _pumpSwitch(tester);
      if (leaves == 1) {
        // The flight lands on the second hero, then flies on to the third.
        await tester.pump(duration ~/ 4);
        count.value = 3;
        await _pumpSwitch(tester);
        await tester.pump(duration);
      }
      await tester.pump(duration ~/ 4);
      shift.value = 200; // The hero it leaves moves down, without a switch.
      await tester.pump(const Duration(milliseconds: 16));

      expect(
        tester.getRect(find.byKey(_shuttleKey)),
        _rectMoreOrLessEquals(
          Rect.lerp(
            _slotRects[leaves].translate(0, 200),
            _slotRects[leaves + 1],
            animation.value,
          )!,
        ),
      );
    });
  }

  testWidgets('flies to where its heroes are on the frame a window resize '
      'moves the switcher', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 600);
    addTearDown(tester.view.reset);
    final moved = ValueNotifier(false);
    addTearDown(moved.dispose);
    late Animation<double> animation;

    await tester.pumpWidget(
      _HeaderSwitcher(
        moved: moved,
        shuttleBuilder: (_, flight, _, _) {
          animation = flight;
          return const SizedBox.expand(key: _shuttleKey);
        },
      ),
    );
    await tester.pumpAndSettle();
    final fromRect = tester.getRect(find.byKey(const ValueKey('box-false')));

    moved.value = true;
    await _pumpSwitch(tester);
    await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 2);

    // The header is as high as a quarter of the window's width, so the
    // switcher moves up.
    tester.view.physicalSize = const Size(600, 600);
    await tester.pump(const Duration(milliseconds: 16));

    final toRect = tester.getRect(
      find.byKey(const ValueKey('box-true'), skipOffstage: false),
    );
    expect(toRect, const Rect.fromLTWH(560, 560, 40, 40));
    // The hero the flight left was at the switcher's top left.
    expect(
      tester.getRect(find.byKey(_shuttleKey)),
      _rectMoreOrLessEquals(
        Rect.lerp(fromRect.translate(0, -50), toRect, animation.value)!,
      ),
    );
  });

  testWidgets('keeps the size of its child in a center, in flight or not', (
    tester,
  ) async {
    final moved = ValueNotifier(false);
    addTearDown(moved.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: ValueListenableBuilder(
            valueListenable: moved,
            builder: (context, moved, _) => HeroHereSwitcher(
              child: SizedBox(
                width: 100,
                height: 100,
                child: Align(
                  alignment: moved ? Alignment.topRight : Alignment.topLeft,
                  child: HeroHere(
                    key: ValueKey(moved),
                    tag: 'hero',
                    flightShuttleBuilder: (_, _, _, _) =>
                        const SizedBox.expand(key: _shuttleKey),
                    child: const SizedBox(width: 20, height: 20),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final switcher = find.byType(HeroHereSwitcher);
    const centered = Rect.fromLTWH(350, 250, 100, 100);
    expect(tester.getRect(switcher), centered);

    moved.value = true;
    await _pumpSwitch(tester);
    expect(find.byKey(_shuttleKey), findsOneWidget);
    expect(tester.getRect(switcher), centered);

    await tester.pumpAndSettle();
    expect(find.byKey(_shuttleKey), findsNothing);
    expect(tester.getRect(switcher), centered);
  });

  testWidgets('clips its flights to it when its layout builder sizes the sky', (
    tester,
  ) async {
    final moved = ValueNotifier(false);
    addTearDown(moved.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: ValueListenableBuilder(
            valueListenable: moved,
            builder: (context, moved, _) => HeroHereSwitcher(
              layoutBuilder: (child, sky) => Stack(
                children: [
                  child,
                  Positioned.fill(child: ClipRect(child: sky)),
                ],
              ),
              child: SizedBox(
                width: 100,
                height: 100,
                child: Align(
                  alignment: moved ? Alignment.topRight : Alignment.topLeft,
                  child: HeroHere(
                    key: ValueKey(moved),
                    tag: 'hero',
                    flightShuttleBuilder: (_, _, _, _) =>
                        const SizedBox.expand(key: _shuttleKey),
                    child: const SizedBox(width: 20, height: 20),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    moved.value = true;
    await _pumpSwitch(tester);

    final switcher = find.byType(HeroHereSwitcher);
    final clip = find.descendant(of: switcher, matching: find.byType(ClipRect));
    expect(tester.getRect(clip), tester.getRect(switcher));
    expect(
      tester.getRect(find.byKey(_shuttleKey)),
      const Rect.fromLTWH(350, 250, 20, 20),
    );
  });

  testWidgets('flies in a switcher of unbounded height', (tester) async {
    final moved = ValueNotifier(false);
    addTearDown(moved.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: ValueListenableBuilder(
            valueListenable: moved,
            builder: (context, moved, _) => HeroHereSwitcher(
              child: Align(
                alignment: moved ? Alignment.topRight : Alignment.topLeft,
                child: HeroHere(
                  key: ValueKey(moved),
                  tag: 'hero',
                  flightShuttleBuilder: (_, _, _, _) =>
                      const SizedBox.expand(key: _shuttleKey),
                  child: const SizedBox(width: 40, height: 40),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    moved.value = true;
    await _pumpSwitch(tester);
    await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 2);

    expect(tester.getSize(find.byKey(_shuttleKey)), const Size(40, 40));
    await tester.pumpAndSettle();
    expect(find.byKey(_shuttleKey), findsNothing);
  });

  for (final (intrinsic, wrap, size) in [
    (
      'height',
      (Widget switcher) =>
          SizedBox(width: 400, child: IntrinsicHeight(child: switcher)),
      const Size(400, 40),
    ),
    (
      'width',
      (Widget switcher) =>
          SizedBox(height: 40, child: IntrinsicWidth(child: switcher)),
      const Size(40, 40),
    ),
  ]) {
    testWidgets('flies in a switcher sized to its intrinsic $intrinsic', (
      tester,
    ) async {
      final moved = ValueNotifier(false);
      addTearDown(moved.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: wrap(
              ValueListenableBuilder(
                valueListenable: moved,
                builder: (context, moved, _) => HeroHereSwitcher(
                  child: Align(
                    alignment: moved ? Alignment.topRight : Alignment.topLeft,
                    child: HeroHere(
                      key: ValueKey(moved),
                      tag: 'hero',
                      flightShuttleBuilder: (_, _, _, _) =>
                          const SizedBox.expand(key: _shuttleKey),
                      child: const SizedBox(width: 40, height: 40),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      moved.value = true;
      await _pumpSwitch(tester);
      await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 2);

      expect(tester.getSize(find.byKey(_shuttleKey)), const Size(40, 40));
      expect(tester.getSize(find.byType(HeroHereSwitcher)), size);
      await tester.pumpAndSettle();
      expect(find.byKey(_shuttleKey), findsNothing);
    });
  }

  test('takes flight options typed with the old or the new names', () {
    // ignore: deprecated_member_use_from_same_package
    const AnimationControllerFactory oldControllerFactory =
        HeroHere.defaultFlightAnimationControllerFactory;
    // ignore: deprecated_member_use_from_same_package
    const AnimationFactory<double> oldAnimationFactory =
        HeroHere.defaultFlightAnimationFactory;
    // ignore: deprecated_member_use_from_same_package
    const StartAnimationCaller oldStarter =
        HeroHere.defaultForwardFlightAnimation;
    // ignore: deprecated_member_use_from_same_package
    const RectTweenFactory oldRectTweenFactory =
        HeroHere.defaultFlightRectTweenFactory;

    const HeroHereFlightAnimationControllerFactory controllerFactory =
        oldControllerFactory;
    const HeroHereFlightAnimationFactory animationFactory = oldAnimationFactory;
    const HeroHereFlightAnimationStarter starter = oldStarter;
    const HeroHereFlightRectTweenFactory rectTweenFactory = oldRectTweenFactory;

    const hero = HeroHere(
      key: ValueKey('hero'),
      tag: 'hero',
      flightAnimationControllerFactory: oldControllerFactory,
      flightAnimationFactory: oldAnimationFactory,
      forwardFlightAnimation: oldStarter,
      reverseFlightAnimation: starter,
      rectTweenFactory: oldRectTweenFactory,
      child: SizedBox(),
    );

    expect(hero.flightAnimationControllerFactory, same(controllerFactory));
    expect(hero.flightAnimationFactory, same(animationFactory));
    expect(hero.forwardFlightAnimation, same(starter));
    expect(hero.rectTweenFactory, same(rectTweenFactory));
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

/// The color of the pixel at [position] on the last frame, with a device
/// pixel ratio of 1.
Future<Color> _pixelAt(WidgetTester tester, Offset position) async {
  final scene = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
  final size = tester.view.physicalSize;
  late ByteData bytes;
  await tester.runAsync(() async {
    final image = await scene.toImage(Offset.zero & size);
    bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    image.dispose();
  });
  final i =
      (position.dy.round() * size.width.round() + position.dx.round()) * 4;
  return Color.fromARGB(
    bytes.getUint8(i + 3),
    bytes.getUint8(i),
    bytes.getUint8(i + 1),
    bytes.getUint8(i + 2),
  );
}

/// The layer that the hero painting the widget [finder] finds paints into,
/// if it painted: each hero paints into a layer of its own.
OffsetLayer? _layerOf(WidgetTester tester, Finder finder) =>
    _heroBoundaryOf(tester, finder)?.debugLayer as OffsetLayer?;

/// Where [layer] was on the screen on the last frame, if it was in it.
Offset? _paintedAt(Layer layer) {
  if (!layer.attached) return null;
  var offset = Offset.zero;
  for (Layer? x = layer; x != null && x is! TransformLayer; x = x.parent) {
    if (x is OffsetLayer) offset += x.offset;
  }
  return offset;
}

/// Whether the hero painting the widget [finder] finds was in the last frame:
/// a hidden hero's layer isn't, and a hero that never painted has none.
bool _painted(WidgetTester tester, Finder finder) =>
    _layerOf(tester, finder)?.attached ?? false;

/// Whether the hero painting the widget [finder] finds was in the last frame
/// where it is, rather than in a stand-in.
bool _paintedInPlace(WidgetTester tester, Finder finder) {
  final boundary = _heroBoundaryOf(tester, finder);
  RenderObject? parent = boundary?.parent;
  while (parent != null && parent is! RenderRepaintBoundary) {
    parent = parent.parent;
  }
  final layer = boundary?.debugLayer;
  return layer != null &&
      layer.attached &&
      layer.parent == (parent as RenderRepaintBoundary?)?.debugLayer;
}

RenderRepaintBoundary? _heroBoundaryOf(WidgetTester tester, Finder finder) {
  RenderObject? object = tester.renderObject(finder);
  while (object != null && object is! RenderRepaintBoundary) {
    object = object.parent;
  }
  return object as RenderRepaintBoundary?;
}

/// Lays the switcher's child out [shift] to the right, so changing [shift]
/// moves the heroes without a switch, as a window resize may.
HeroHereSwitcherLayoutBuilder _shiftedLayoutBuilder(
  ValueNotifier<double> shift,
) =>
    (child, sky) => Material(
      child: Stack(
        children: [
          ValueListenableBuilder(
            valueListenable: shift,
            builder: (context, shift, child) => Padding(
              padding: EdgeInsets.only(left: shift),
              child: child,
            ),
            child: child,
          ),
          sky,
        ],
      ),
    );

/// How opaque the widget [finder] finds shows, through the fades above it.
double _opacityOf(WidgetTester tester, Finder finder) {
  var opacity = 1.0;
  tester.element(finder).visitAncestorElements((element) {
    final widget = element.widget;
    if (widget is FadeTransition) opacity *= widget.opacity.value;
    return true;
  });
  return opacity;
}

/// Runs a frame [after] the last one as the web does: the microtasks that its
/// start schedules, such as a flight's landing, run after the whole frame,
/// so after a switch in it, rather than before its build.
Future<void> _pumpWebFrame(WidgetTester tester, Duration after) async {
  final binding = tester.binding;
  await binding.delayed(after);
  binding.handleBeginFrame(
    Duration(microseconds: binding.clock.now().microsecondsSinceEpoch),
  );
  binding.handleDrawFrame();
  await tester.pump();
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

/// Shows one hero in the slot of [_slotRects] that [slot] picks. When
/// [wrapped], the hero sits in one more widget, which a builder inside the
/// switcher's child adds, so changing [wrapped] mounts the hero anew without
/// rebuilding the switcher.
class _ChainSwitcher extends StatelessWidget {
  const _ChainSwitcher({required this.slot, required this.wrapped});

  final ValueNotifier<int> slot;
  final ValueNotifier<bool> wrapped;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: ValueListenableBuilder(
      valueListenable: slot,
      builder: (context, slot, _) => HeroHereSwitcher(
        child: Stack(
          children: [
            Positioned.fromRect(
              rect: _slotRects[slot],
              child: ValueListenableBuilder(
                valueListenable: wrapped,
                builder: (context, wrapped, _) {
                  final hero = HeroHere(
                    key: ValueKey(slot),
                    tag: 'hero',
                    flightShuttleBuilder: (_, _, _, _) =>
                        const SizedBox.expand(key: _shuttleKey),
                    child: ColoredBox(
                      key: ValueKey('box$slot'),
                      color: const Color(0xFF2196F3),
                    ),
                  );
                  return wrapped ? KeyedSubtree(child: hero) : hero;
                },
              ),
            ),
          ],
        ),
      ),
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

/// Shows a hero in the slot of [_slotRects] that [slot] picks, after an
/// extra hero with the same tag in the third slot. A builder inside the
/// switcher's child adds the extra hero when [extra] is 1, and mounts it anew
/// in one more widget when it's 2, so neither runs a switch. Each change of
/// [rebuilds] rebuilds the switcher with a new child.
class _ExtraSwitcher extends StatelessWidget {
  const _ExtraSwitcher({
    required this.slot,
    required this.extra,
    required this.rebuilds,
  });

  final ValueNotifier<int> slot;
  final ValueNotifier<int> extra;
  final ValueNotifier<int> rebuilds;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: ListenableBuilder(
      listenable: Listenable.merge([slot, rebuilds]),
      builder: (context, _) {
        Widget hero(Object key, String box) => HeroHere(
          key: ValueKey(key),
          tag: 'hero',
          child: ColoredBox(key: ValueKey(box), color: const Color(0xFF2196F3)),
        );

        return HeroHereSwitcher(
          child: Stack(
            children: [
              ValueListenableBuilder(
                valueListenable: extra,
                builder: (context, extra, _) => extra == 0
                    ? const SizedBox.shrink()
                    : Positioned.fromRect(
                        rect: _slotRects[2],
                        child: extra == 1
                            ? hero('extra', 'box-extra')
                            : KeyedSubtree(child: hero('extra', 'box-extra')),
                      ),
              ),
              Positioned.fromRect(
                rect: _slotRects[slot.value],
                child: hero(slot.value, 'box${slot.value}'),
              ),
            ],
          ),
        );
      },
    ),
  );
}

/// Rebuilds a switcher on each change of [rebuilds] or [switchKey], with a new
/// child keyed by [rebuilds] each time, or with the same `const` child when
/// [sameChild]. The switcher's switch key is [switchKey]'s, if any.
class _RebuildSwitcher extends StatelessWidget {
  const _RebuildSwitcher({
    required this.rebuilds,
    required this.sameChild,
    this.switchKey,
  });

  final ValueNotifier<int> rebuilds;
  final bool sameChild;
  final ValueNotifier<Object?>? switchKey;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: ListenableBuilder(
      listenable: Listenable.merge([rebuilds, switchKey]),
      builder: (context, _) => HeroHereSwitcher(
        switchKey: switchKey?.value,
        child: sameChild
            ? const SizedBox.square(dimension: 40)
            : SizedBox.square(key: ValueKey(rebuilds.value), dimension: 40),
      ),
    ),
  );
}

/// Shows one hero in the slot of [_slotRects] that [slot] picks, with a box
/// keyed by the slot and [look] as its child. The switcher rebuilds on each
/// change of [look], unless [looksBelow], when only a builder below it does.
/// When [keyed], its switch key is the slot, so a new look alone shows in
/// place. Its shuttle shows its `toHero`'s child, in a box with
/// [_shuttleKey].
class _LookSwitcher extends StatelessWidget {
  const _LookSwitcher({
    required this.slot,
    required this.look,
    required this.keyed,
    required this.looksBelow,
  });

  final ValueNotifier<int> slot;
  final ValueNotifier<String> look;
  final bool keyed;
  final bool looksBelow;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: ListenableBuilder(
      listenable: looksBelow ? slot : Listenable.merge([slot, look]),
      builder: (context, _) => HeroHereSwitcher(
        switchKey: keyed ? slot.value : null,
        child: Stack(
          children: [
            Positioned.fromRect(
              rect: _slotRects[slot.value],
              child: looksBelow
                  ? ValueListenableBuilder(
                      valueListenable: look,
                      builder: (context, look, _) => _hero(look),
                    )
                  : _hero(look.value),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _hero(String look) => HeroHere(
    key: ValueKey(slot.value),
    tag: 'hero',
    flightShuttleBuilder: (_, _, _, toHero) =>
        KeyedSubtree(key: _shuttleKey, child: toHero.child),
    child: ColoredBox(
      key: ValueKey('box${slot.value}$look'),
      color: const Color(0xFF2196F3),
    ),
  );
}

/// Shows hero 'a' in the first slot of [_slotRects], with a box keyed by
/// [look] as its child, which a builder below the switcher reads. When
/// [split], it adds hero 'b' with the same tag in the second, so 'a' flies to
/// 'b' and stays, hidden. Its shuttle shows its `fromHero`'s child, in a box
/// with [_shuttleKey].
class _LeftLookSwitcher extends StatelessWidget {
  const _LeftLookSwitcher({required this.split, required this.look});

  final ValueNotifier<bool> split;
  final ValueNotifier<String> look;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: ValueListenableBuilder(
      valueListenable: split,
      builder: (context, split, _) {
        Widget hero(String key, String look) => HeroHere(
          key: ValueKey(key),
          tag: 'hero',
          flightShuttleBuilder: (_, _, fromHero, _) =>
              KeyedSubtree(key: _shuttleKey, child: fromHero.child),
          child: ColoredBox(
            key: ValueKey('box$look'),
            color: const Color(0xFF2196F3),
          ),
        );

        return HeroHereSwitcher(
          child: Stack(
            children: [
              Positioned.fromRect(
                rect: _slotRects[0],
                child: ValueListenableBuilder(
                  valueListenable: look,
                  builder: (context, look, _) => hero('a', look),
                ),
              ),
              if (split)
                Positioned.fromRect(
                  rect: _slotRects[1],
                  child: hero('b', 'other'),
                ),
            ],
          ),
        );
      },
    ),
  );
}

/// Shows one hero, at the alignment and of the size of the spot of [spots]
/// that [slot] picks. A size of infinite width is as wide as the switcher.
/// Its shuttle is a box with [_shuttleKey].
class _AlignSwitcher extends StatelessWidget {
  const _AlignSwitcher({
    required this.slot,
    required this.spots,
    this.redirect,
  });

  final ValueNotifier<int> slot;
  final List<({Alignment alignment, Size size})> spots;
  final HeroHereFlightRedirect? redirect;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: ValueListenableBuilder(
      valueListenable: slot,
      builder: (context, slot, _) => HeroHereSwitcher(
        child: Align(
          alignment: spots[slot].alignment,
          child: HeroHere(
            key: ValueKey(slot),
            tag: 'hero',
            flightRedirect: redirect,
            flightShuttleBuilder: (_, _, _, _) =>
                const SizedBox.expand(key: _shuttleKey),
            child: SizedBox.fromSize(size: spots[slot].size),
          ),
        ),
      ),
    ),
  );
}

const _moverKey = ValueKey('mover');

/// Shows one hero of a fixed size at the left, or when [right], at the right,
/// so it flies without changing size. Its child, which its shuttle shows,
/// calls [onPaint] each time it paints.
class _MoveSwitcher extends StatelessWidget {
  const _MoveSwitcher({required this.right, required this.onPaint});

  final ValueNotifier<bool> right;
  final VoidCallback onPaint;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: ValueListenableBuilder(
      valueListenable: right,
      builder: (context, right, _) => HeroHereSwitcher(
        child: Align(
          alignment: right ? Alignment.centerRight : Alignment.centerLeft,
          child: HeroHere(
            key: ValueKey(right),
            tag: 'hero',
            child: SizedBox(
              key: _moverKey,
              width: 100,
              height: 100,
              child: CustomPaint(painter: _PaintCounter(onPaint)),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Shows [count] heroes with the same tag in the first slots of
/// [_slotRects], so a new one flies from the last one, which stays, hidden.
/// Hero [shifted] is [shift] down, which a builder below the switcher reads.
class _ShiftSwitcher extends StatelessWidget {
  const _ShiftSwitcher({
    required this.count,
    required this.shifted,
    required this.shift,
    required this.shuttleBuilder,
  });

  final ValueNotifier<int> count;
  final int shifted;
  final ValueNotifier<double> shift;
  final HeroHereFlightShuttleBuilder shuttleBuilder;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: ValueListenableBuilder(
      valueListenable: count,
      builder: (context, count, _) {
        Widget hero(int i, double shift) => Positioned.fromRect(
          rect: _slotRects[i].translate(0, shift),
          child: HeroHere(
            key: ValueKey(i),
            tag: 'hero',
            flightShuttleBuilder: shuttleBuilder,
            child: const ColoredBox(color: Color(0xFF2196F3)),
          ),
        );

        return HeroHereSwitcher(
          child: ValueListenableBuilder(
            valueListenable: shift,
            builder: (context, shift, _) => Stack(
              children: [
                for (var i = 0; i < count; i++)
                  hero(i, i == shifted ? shift : 0),
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// Shows one hero in the slot of [_slotRects] that [slot] picks, a box keyed
/// by its slot, and a text of [label], or of the slot if no [label]. When
/// [inLayoutBuilder], a layout builder in the switcher's child builds them.
/// Its switch key is [switchKey]'s, if any. Its shuttle is a box with
/// [_shuttleKey].
class _LabelSwitcher extends StatelessWidget {
  const _LabelSwitcher({
    required this.slot,
    this.label,
    this.switchKey,
    this.inLayoutBuilder = false,
  });

  final ValueNotifier<int> slot;
  final ValueNotifier<int>? label;
  final ValueNotifier<Object?>? switchKey;
  final bool inLayoutBuilder;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: ListenableBuilder(
      listenable: Listenable.merge([slot, label, switchKey]),
      builder: (context, _) {
        final slot = this.slot.value;
        final child = Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              child: Text('label ${label?.value ?? slot}'),
            ),
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
        );
        return HeroHereSwitcher(
          switchKey: switchKey?.value,
          child: inLayoutBuilder
              ? LayoutBuilder(builder: (context, _) => child)
              : child,
        );
      },
    ),
  );
}

const _clippedRect = Rect.fromLTWH(100, 100, 200, 200);

/// Shows a red hero at [_clippedRect], in a clip that rounds its corners from
/// outside it, or, when [slot] is 1, a hero with its tag in the third slot of
/// [_slotRects], with no clip. When [inBoundary], the clip is in a layer of
/// its own, away from the switcher's origin.
class _ClippedSwitcher extends StatelessWidget {
  const _ClippedSwitcher({required this.slot, this.inBoundary = false});

  final ValueNotifier<int> slot;
  final bool inBoundary;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: ValueListenableBuilder(
      valueListenable: slot,
      builder: (context, slot, _) => HeroHereSwitcher(
        child: Stack(
          children: [
            if (slot == 0)
              Positioned.fromRect(
                rect: _clippedRect,
                child: _maybeInBoundary(
                  ClipRRect(
                    borderRadius: BorderRadius.circular(50),
                    child: const HeroHere(
                      key: ValueKey(0),
                      tag: 'hero',
                      child: ColoredBox(color: Color(0xFFFF0000)),
                    ),
                  ),
                ),
              )
            else
              Positioned.fromRect(
                rect: _slotRects[2],
                child: const HeroHere(
                  key: ValueKey(1),
                  tag: 'hero',
                  child: ColoredBox(color: Color(0xFFFF0000)),
                ),
              ),
          ],
        ),
      ),
    ),
  );

  Widget _maybeInBoundary(Widget child) =>
      inBoundary ? RepaintBoundary(child: child) : child;
}

/// Shows hero 'a' in the first slot of [_slotRects], or, when [moved], hero
/// 'b' in the second. A builder below the switcher reads [b]: 0 shows 'b',
/// 1 mounts it anew in one more widget, and 2 takes it away, none of which
/// runs a switch. Its shuttle is a box with [_shuttleKey].
class _GoneSwitcher extends StatelessWidget {
  const _GoneSwitcher({required this.moved, required this.b});

  final ValueNotifier<bool> moved;
  final ValueNotifier<int> b;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: ValueListenableBuilder(
      valueListenable: moved,
      builder: (context, moved, _) {
        Widget hero(String key) => HeroHere(
          key: ValueKey(key),
          tag: 'hero',
          flightShuttleBuilder: (_, _, _, _) =>
              const SizedBox.expand(key: _shuttleKey),
          child: const ColoredBox(color: Color(0xFF2196F3)),
        );

        return HeroHereSwitcher(
          child: Stack(
            children: [
              if (!moved)
                Positioned.fromRect(rect: _slotRects[0], child: hero('a'))
              else
                ValueListenableBuilder(
                  valueListenable: b,
                  builder: (context, b, _) => Positioned.fromRect(
                    rect: _slotRects[1],
                    child: switch (b) {
                      0 => hero('b'),
                      1 => KeyedSubtree(child: hero('b')),
                      _ => const SizedBox(),
                    },
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}

/// A [_SlotSwitcher] slot that shows no hero.
const _noSlot = -1;

/// Shows one hero in the slot of [_slotRects] that [slot] picks, or none for
/// [_noSlot], [nudge] right of it, which a builder below the switcher reads.
/// Its shuttle is a box with [_shuttleKey], unless [shuttleBuilder] builds
/// one.
class _SlotSwitcher extends StatelessWidget {
  const _SlotSwitcher({
    required this.slot,
    this.nudge = const AlwaysStoppedAnimation(0.0),
    this.layoutBuilder = HeroHereSwitcher.defaultLayoutBuilder,
    this.redirect,
    this.shuttleBuilder,
  });

  final ValueNotifier<int> slot;
  final ValueListenable<double> nudge;
  final HeroHereSwitcherLayoutBuilder layoutBuilder;
  final HeroHereFlightRedirect? redirect;
  final HeroHereFlightShuttleBuilder? shuttleBuilder;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: ValueListenableBuilder(
      valueListenable: slot,
      builder: (context, slot, _) => HeroHereSwitcher(
        layoutBuilder: layoutBuilder,
        child: ValueListenableBuilder(
          valueListenable: nudge,
          builder: (context, nudge, _) => Stack(
            children: [
              if (slot != _noSlot)
                Positioned.fromRect(
                  rect: _slotRects[slot].translate(nudge, 0),
                  child: HeroHere(
                    key: ValueKey(slot),
                    tag: 'hero',
                    flightRedirect: redirect,
                    flightShuttleBuilder:
                        shuttleBuilder ??
                        (_, _, _, _) => const SizedBox.expand(key: _shuttleKey),
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

const _stayRect = Rect.fromLTWH(0, 300, 40, 40);

/// Shows hero 'a' in the first slot of [_slotRects], or, when [split], moves
/// it to [_stayRect] and adds hero 'b' with the same tag in the second slot,
/// so 'a' flies to 'b' and stays, hidden.
class _StaySwitcher extends StatelessWidget {
  const _StaySwitcher({required this.split, this.onMeasureA});

  final ValueNotifier<bool> split;

  /// Called each time something measures where 'a' is on the screen.
  final VoidCallback? onMeasureA;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: ValueListenableBuilder(
      valueListenable: split,
      builder: (context, split, _) {
        Widget hero(String key) => HeroHere(
          key: ValueKey(key),
          tag: 'hero',
          flightShuttleBuilder: (_, _, _, _) =>
              const SizedBox.expand(key: _shuttleKey),
          child: const ColoredBox(color: Color(0xFF2196F3)),
        );

        return HeroHereSwitcher(
          child: Stack(
            children: [
              Positioned.fromRect(
                rect: split ? _stayRect : _slotRects[0],
                child: _MeasureCounter(
                  onMeasure: onMeasureA ?? () {},
                  child: hero('a'),
                ),
              ),
              if (split)
                Positioned.fromRect(rect: _slotRects[1], child: hero('b')),
            ],
          ),
        );
      },
    ),
  );
}

/// Shows hero 'a' in the first slot of [_slotRects], and, when [split], hero
/// 'b' with the same tag in the second, so 'a' flies to 'b' and stays,
/// hidden. A builder below the switcher reads [bGone], which takes 'b' away
/// without a switch. Its shuttle is a box with [_shuttleKey].
class _LeftSwitcher extends StatelessWidget {
  const _LeftSwitcher({required this.split, required this.bGone});

  final ValueNotifier<bool> split;
  final ValueNotifier<bool> bGone;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: ValueListenableBuilder(
      valueListenable: split,
      builder: (context, split, _) {
        Widget hero(String key) => HeroHere(
          key: ValueKey(key),
          tag: 'hero',
          flightShuttleBuilder: (_, _, _, _) =>
              const SizedBox.expand(key: _shuttleKey),
          child: ColoredBox(
            key: ValueKey('box-$key'),
            color: const Color(0xFF2196F3),
          ),
        );

        return HeroHereSwitcher(
          child: Stack(
            children: [
              Positioned.fromRect(rect: _slotRects[0], child: hero('a')),
              if (split)
                ValueListenableBuilder(
                  valueListenable: bGone,
                  builder: (context, bGone, _) => Positioned.fromRect(
                    rect: _slotRects[1],
                    child: bGone ? const SizedBox() : hero('b'),
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}

/// Shows hero 'a' in the first slot of [_slotRects], and, from [order] 1,
/// hero 'b' with the same tag in the second, after 'a', so 'a' flies to 'b'
/// and stays, hidden. [order] 2 puts 'b' before 'a', so 'a' is the last hero
/// of the tag again. A builder below the switcher reads [aGone], which takes
/// 'a' away without a switch. Its shuttle is a box with [_shuttleKey].
class _TurnSwitcher extends StatelessWidget {
  const _TurnSwitcher({required this.order, required this.aGone});

  final ValueNotifier<int> order;
  final ValueNotifier<bool> aGone;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: ValueListenableBuilder(
      valueListenable: order,
      builder: (context, order, _) {
        Widget hero(String key) => HeroHere(
          key: ValueKey(key),
          tag: 'hero',
          flightShuttleBuilder: (_, _, _, _) =>
              const SizedBox.expand(key: _shuttleKey),
          child: ColoredBox(
            key: ValueKey('box-$key'),
            color: const Color(0xFF2196F3),
          ),
        );
        final a = Positioned.fromRect(
          key: const ValueKey('slot-a'),
          rect: _slotRects[0],
          child: ValueListenableBuilder(
            valueListenable: aGone,
            builder: (context, aGone, _) =>
                aGone ? const SizedBox() : hero('a'),
          ),
        );
        final b = Positioned.fromRect(
          key: const ValueKey('slot-b'),
          rect: _slotRects[1],
          child: hero('b'),
        );

        return HeroHereSwitcher(
          child: Stack(children: [if (order == 2) b, a, if (order == 1) b]),
        );
      },
    ),
  );
}

/// Shows no hero, or, when [twice], heroes with the same tag in the first and
/// the third slot of [_slotRects].
class _NewTagSwitcher extends StatelessWidget {
  const _NewTagSwitcher({required this.twice});

  final ValueNotifier<bool> twice;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: ValueListenableBuilder(
      valueListenable: twice,
      builder: (context, twice, _) => HeroHereSwitcher(
        child: Stack(
          children: [
            const SizedBox.expand(),
            if (twice)
              for (final slot in [0, 2])
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

/// Shows a 40 px hero at the top left of a switcher, or, when [moved], at its
/// bottom right. The switcher is below a header as high as a quarter of the
/// window's width, so a window resize moves it.
class _HeaderSwitcher extends StatelessWidget {
  const _HeaderSwitcher({required this.moved, required this.shuttleBuilder});

  final ValueNotifier<bool> moved;
  final HeroHereFlightShuttleBuilder shuttleBuilder;

  @override
  Widget build(BuildContext context) {
    // Built once, so the header's rebuilds on a resize don't rebuild it.
    final switcher = ValueListenableBuilder(
      valueListenable: moved,
      builder: (context, moved, _) => HeroHereSwitcher(
        child: Align(
          alignment: moved ? Alignment.bottomRight : Alignment.topLeft,
          child: HeroHere(
            key: ValueKey(moved),
            tag: 'hero',
            flightShuttleBuilder: shuttleBuilder,
            child: SizedBox(key: ValueKey('box-$moved'), width: 40, height: 40),
          ),
        ),
      ),
    );

    return MaterialApp(
      home: LayoutBuilder(
        builder: (context, constraints) => Column(
          children: [
            SizedBox(height: constraints.maxWidth / 4),
            Expanded(child: switcher),
          ],
        ),
      ),
    );
  }
}

/// Shows a 40 px hero at the top left, or, when [moved], a hero a quarter of
/// the window wide at the top right.
class _QuarterWidthSwitcher extends StatelessWidget {
  const _QuarterWidthSwitcher({required this.moved, this.shuttleBuilder});

  final ValueNotifier<bool> moved;
  final HeroHereFlightShuttleBuilder? shuttleBuilder;

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
            flightShuttleBuilder:
                shuttleBuilder ??
                (_, _, _, _) => const SizedBox.expand(key: _shuttleKey),
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

/// Shows hero 'hero' above a page view of [pages] until [inPage], which
/// moves it into page 'c'. The page view finds a page's new index by its key,
/// so a page keeps its element when pages before it go. [pages] is read below
/// the switcher, so changing it runs no switch.
class _PageSwitcher extends StatelessWidget {
  const _PageSwitcher({
    required this.inPage,
    required this.pages,
    required this.controller,
  });

  final ValueNotifier<bool> inPage;
  final ValueNotifier<List<String>> pages;
  final PageController controller;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: ValueListenableBuilder(
      valueListenable: inPage,
      builder: (context, inPage, _) => HeroHereSwitcher(
        child: Column(
          children: [
            SizedBox(
              height: 100,
              child: inPage ? null : _hero(const ValueKey('top')),
            ),
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: pages,
                builder: (context, pages, _) => PageView.custom(
                  controller: controller,
                  childrenDelegate: SliverChildBuilderDelegate(
                    (context, index) => Center(
                      key: ValueKey(pages[index]),
                      child: inPage && pages[index] == 'c'
                          ? _hero(const ValueKey('page'))
                          : null,
                    ),
                    childCount: pages.length,
                    findChildIndexCallback: (key) =>
                        pages.indexOf((key as ValueKey<String>).value),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  static Widget _hero(Key key) => HeroHere(
    key: key,
    tag: 'hero',
    flightShuttleBuilder: (_, _, _, _) =>
        const SizedBox.expand(key: _shuttleKey),
    child: const SizedBox(width: 40, height: 40),
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

/// Calls [onMeasure] each time something maps a point of its child to the
/// screen, or to another ancestor, through it, as a flight does to measure
/// a hero.
class _MeasureCounter extends SingleChildRenderObjectWidget {
  const _MeasureCounter({required this.onMeasure, super.child});

  final VoidCallback onMeasure;

  @override
  _RenderMeasureCounter createRenderObject(BuildContext context) =>
      _RenderMeasureCounter(onMeasure);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMeasureCounter renderObject,
  ) => renderObject.onMeasure = onMeasure;
}

class _RenderMeasureCounter extends RenderProxyBox {
  _RenderMeasureCounter(this.onMeasure);

  VoidCallback onMeasure;

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    onMeasure();
    super.applyPaintTransform(child, transform);
  }
}

/// A hero with [key] at [rect] in a stack, whose shuttle is a box with
/// [_shuttleKey]. [_boxOf] finds its child.
Widget _heroAt(Key key, Rect rect) => Positioned.fromRect(
  rect: rect,
  child: HeroHere(
    key: key,
    tag: 'hero',
    flightShuttleBuilder: (_, _, _, _) =>
        const SizedBox.expand(key: _shuttleKey),
    child: const ColoredBox(color: Color(0xFF2196F3)),
  ),
);

/// The child of the hero with [key] from [_heroAt], while it shows, or also
/// while it hides unless [skipOffstage].
Finder _boxOf(Key key, {bool skipOffstage = true}) => find.descendant(
  of: find.byKey(key, skipOffstage: skipOffstage),
  matching: find.byType(ColoredBox, skipOffstage: skipOffstage),
  skipOffstage: skipOffstage,
);

/// A widget whose element calls [onVisit] each time something visits its
/// children, as a walk of the tree does.
class _VisitCounter extends StatelessWidget {
  const _VisitCounter({required this.onVisit});

  final VoidCallback onVisit;

  @override
  StatelessElement createElement() => _VisitCountingElement(this);

  @override
  Widget build(BuildContext context) => const SizedBox(width: 1, height: 1);
}

class _VisitCountingElement extends StatelessElement {
  _VisitCountingElement(_VisitCounter super.widget);

  @override
  void visitChildren(ElementVisitor visitor) {
    (widget as _VisitCounter).onVisit();
    super.visitChildren(visitor);
  }
}
