part of '../hero_here_test.dart';

/// Which heroes a switch finds: in its child, in tree order, wherever
/// a global key moves them, and never a copy a shuttle shows.
void _heroesTests() {
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
        child: ColoredBox(key: ValueKey('box-$key'), color: _heroColor),
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
    // key hides both, which this test isn't about. A test before it in this
    // file that fails leaves semantics on, though: testWidgets disposes its
    // semantics handle only once the test passes. So this one fails too.
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
}

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
