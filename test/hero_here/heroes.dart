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

  for (final offAround in [false, true]) {
    testWidgets(
      'hides a hero that a global key moves into another switcher '
      'while a flight leaves it there, and shows it there once the flight '
      'lands${offAround ? ', under a disabled hero mode around the app' : ''}',
      (tester) async {
        final moving = GlobalKey();
        // 0: the hero in the left switcher; 1: moved into the right one, at the
        // same place in it, as the left one brings another hero of its tag.
        Widget app(int stage) {
          final app = MaterialApp(
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
                          if (!right && stage == 1)
                            _heroAt(const ValueKey('other'), _slotRects[1]),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
          return offAround ? HeroMode(enabled: false, child: app) : app;
        }

        await tester.pumpWidget(app(0));
        await tester.pumpAndSettle();
        await tester.pumpWidget(app(1));
        await _pumpSwitch(tester);
        await tester.pump(_frame * 3);

        expect(find.byKey(_shuttleKey), findsOneWidget);
        expect(_painted(tester, _boxOf(moving, skipOffstage: false)), isFalse);

        await tester.pumpAndSettle();
        expect(find.byKey(_shuttleKey), findsNothing);
        expect(_paintedInPlace(tester, _boxOf(moving)), isTrue);
        expect(tester.getRect(_boxOf(moving)), _slotRects[0].translate(400, 0));
      },
    );
  }

  testWidgets('keeps a hero that a global key moves into another switcher '
      'hidden behind a later hero of its tag there, once the flight that left '
      'it lands', (tester) async {
    final moving = GlobalKey();
    // 0: the hero in the left switcher, and a hero of its tag in the right
    // one; 1: moved into the right one, before that hero, as the left one
    // brings another hero of its tag.
    Widget app(int stage) => MaterialApp(
      home: Row(
        children: [
          SizedBox(
            width: 400,
            height: 600,
            child: HeroHereSwitcher(
              child: Stack(
                children: [
                  if (stage == 0)
                    _heroAt(moving, _slotRects[0])
                  else
                    _heroAt(const ValueKey('other'), _slotRects[1]),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 400,
            height: 600,
            child: HeroHereSwitcher(
              child: Stack(
                children: [
                  if (stage == 1) _heroAt(moving, _slotRects[0]),
                  KeyedSubtree(
                    key: const ValueKey('later slot'),
                    child: _heroAt(const ValueKey('later'), _slotRects[1]),
                  ),
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

    expect(_painted(tester, _boxOf(moving, skipOffstage: false)), isFalse);
    expect(_paintedInPlace(tester, _boxOf(const ValueKey('later'))), isTrue);
  });

  testWidgets('shows a hero that a global key moves under a disabled hero mode '
      'in another switcher, once a flight that lands on it there and flies on '
      'lands', (tester) async {
    final moving = GlobalKey();
    // 0: 'a' in the left switcher; 1: the moving hero comes there, so a
    // flight flies to it; 2: mid-flight, it moves under a disabled hero mode
    // in the right switcher, as 'next' comes in the left one, so the flight
    // lands on it there, then flies on, from it, to 'next'.
    Widget app(int stage) => MaterialApp(
      home: Row(
        children: [
          SizedBox(
            width: 400,
            height: 600,
            child: HeroHereSwitcher(
              child: Stack(
                children: [
                  if (stage == 0) _heroAt(const ValueKey('a'), _slotRects[0]),
                  if (stage == 1) _heroAt(moving, _slotRects[1]),
                  if (stage == 2)
                    _heroAt(const ValueKey('next'), _slotRects[0]),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 400,
            height: 600,
            child: HeroHereSwitcher(
              child: Stack(
                children: [
                  if (stage == 2)
                    HeroMode(
                      enabled: false,
                      child: Stack(children: [_heroAt(moving, _slotRects[0])]),
                    ),
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
    await _pumpSwitch(tester);
    await tester.pump(_frame * 5);
    expect(find.byKey(_shuttleKey), findsOneWidget);

    await tester.pumpWidget(app(2));
    await tester.pumpAndSettle();

    expect(find.byKey(_shuttleKey), findsNothing);
    expect(_paintedInPlace(tester, _boxOf(const ValueKey('next'))), isTrue);
    expect(_paintedInPlace(tester, _boxOf(moving)), isTrue);
    expect(tester.getRect(_boxOf(moving)), _slotRects[0].translate(400, 0));
  });

  testWidgets('leaves a hero that a global key moves into another switcher to '
      'the flight there that flies to it, once the flight that left it '
      'lands', (tester) async {
    final moving = GlobalKey();
    // 0: the hero in the left switcher, and a hero of its tag in the right
    // one; 1: moved into the right one, after that hero, so a flight there
    // flies to it, as the left one brings another hero of its tag, whose
    // quicker flight lands first.
    Widget app(int stage) => MaterialApp(
      home: Row(
        children: [
          SizedBox(
            width: 400,
            height: 600,
            child: HeroHereSwitcher(
              child: Stack(
                children: [
                  if (stage == 0)
                    _heroAt(moving, _slotRects[0])
                  else
                    Positioned.fromRect(
                      rect: _slotRects[1],
                      child: const HeroHere(
                        key: ValueKey('other'),
                        tag: 'hero',
                        flightAnimationDuration: Duration(milliseconds: 100),
                        flightShuttleBuilder: _shuttleBox,
                        child: ColoredBox(color: _heroColor),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 400,
            height: 600,
            child: HeroHereSwitcher(
              child: Stack(
                children: [
                  KeyedSubtree(
                    key: const ValueKey('earlier slot'),
                    child: _heroAt(const ValueKey('earlier'), _slotRects[1]),
                  ),
                  if (stage == 1) _heroAt(moving, _slotRects[0]),
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
    await _pumpSwitch(tester);

    // The left flight has landed, while the right one flies on to the hero.
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byKey(_shuttleKey), findsOneWidget);
    expect(_painted(tester, _boxOf(moving, skipOffstage: false)), isFalse);

    await tester.pumpAndSettle();
    expect(_paintedInPlace(tester, _boxOf(moving)), isTrue);
    expect(
      _painted(tester, _boxOf(const ValueKey('earlier'), skipOffstage: false)),
      isFalse,
    );
  });

  testWidgets('keeps the hero a flight leaves hidden once it lands, while that '
      'hero stays behind a later hero of its tag', (tester) async {
    final stage = ValueNotifier(0);
    addTearDown(stage.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder(
          valueListenable: stage,
          builder: (context, stage, _) => HeroHereSwitcher(
            child: Stack(
              children: [
                _heroAt(const ValueKey('a'), _slotRects[0]),
                if (stage == 1) _heroAt(const ValueKey('b'), _slotRects[1]),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    stage.value = 1;
    await _pumpSwitch(tester);
    expect(find.byKey(_shuttleKey), findsOneWidget);

    await tester.pumpAndSettle();
    expect(
      _painted(tester, _boxOf(const ValueKey('a'), skipOffstage: false)),
      isFalse,
    );
    expect(_paintedInPlace(tester, _boxOf(const ValueKey('b'))), isTrue);
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

  for (final comes in [false, true]) {
    testWidgets('shows a hero under a disabled hero mode that '
        '${comes ? 'comes with' : 'stays through'} a switch flying its tag, '
        'on every frame', (tester) async {
      final switched = ValueNotifier(false);
      addTearDown(switched.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder(
            valueListenable: switched,
            builder: (context, switched, _) => HeroHereSwitcher(
              child: Stack(
                children: [
                  if (switched || !comes)
                    HeroMode(
                      enabled: false,
                      child: Stack(
                        children: [
                          _heroAt(const ValueKey('off'), _slotRects[2]),
                        ],
                      ),
                    ),
                  _heroAt(ValueKey(switched), _slotRects[switched ? 1 : 0]),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final off = _boxOf(const ValueKey('off'));
      final shuttle = find.byKey(_shuttleKey);

      switched.value = true;
      // The frame of the switch.
      await tester.pump();
      expect(_paintedInPlace(tester, off), isTrue);
      // The frames of the flight from the hero in the first slot to the one
      // in the second.
      await tester.pump();
      expect(tester.any(shuttle), isTrue);
      for (var i = 0; i < 40 && tester.any(shuttle); i++) {
        expect(_paintedInPlace(tester, off), isTrue);
        await tester.pump(_frame);
      }
      expect(tester.any(shuttle), isFalse);
      expect(_paintedInPlace(tester, off), isTrue);
    });
  }

  testWidgets('shows a hero that hid behind a later hero of its tag once a '
      'disabled hero mode leaves it out', (tester) async {
    final enabled = ValueNotifier(true);
    addTearDown(enabled.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder(
          valueListenable: enabled,
          builder: (context, enabled, _) => HeroHereSwitcher(
            child: Stack(
              children: [
                HeroMode(
                  enabled: enabled,
                  child: Stack(
                    children: [_heroAt(const ValueKey('a'), _slotRects[0])],
                  ),
                ),
                _heroAt(const ValueKey('b'), _slotRects[1]),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final a = _boxOf(const ValueKey('a'), skipOffstage: false);
    expect(_painted(tester, a), isFalse);

    enabled.value = false;
    await tester.pumpAndSettle();
    expect(_boxOf(const ValueKey('a')), findsOneWidget);
    expect(_paintedInPlace(tester, a), isTrue);

    // Enabled again, it hides behind 'b' again.
    enabled.value = true;
    await tester.pumpAndSettle();
    expect(_painted(tester, a), isFalse);
  });

  for (final stays in [false, true]) {
    testWidgets('shows the hero a flight flies to once a disabled hero mode '
        'leaves it out mid-flight, with the hero the flight leaves '
        '${stays ? 'staying' : 'gone'}', (tester) async {
      // 0: 'a'; 1: 'b' comes in an enabled hero mode; 2: the hero mode is
      // disabled.
      final stage = ValueNotifier(0);
      addTearDown(stage.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder(
            valueListenable: stage,
            builder: (context, stage, _) => HeroHereSwitcher(
              child: Stack(
                children: [
                  if (stage == 0 || stays)
                    _heroAt(const ValueKey('a'), _slotRects[0]),
                  if (stage > 0)
                    HeroMode(
                      enabled: stage == 1,
                      child: Stack(
                        children: [_heroAt(const ValueKey('b'), _slotRects[1])],
                      ),
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
      await tester.pump(_frame * 5);
      expect(find.byKey(_shuttleKey), findsOneWidget);

      // The flight stops, or, if 'a' stays, turns back to it.
      stage.value = 2;
      await tester.pumpAndSettle();
      expect(find.byKey(_shuttleKey), findsNothing);
      expect(_boxOf(const ValueKey('b')), findsOneWidget);
      expect(
        _paintedInPlace(
          tester,
          _boxOf(const ValueKey('b'), skipOffstage: false),
        ),
        isTrue,
      );
      if (stays) {
        expect(_paintedInPlace(tester, _boxOf(const ValueKey('a'))), isTrue);
      }
    });
  }

  testWidgets(
    'flies nothing from a hero that the switch bringing a hero of its '
    'tag leaves out by a disabled hero mode, on every frame',
    (tester) async {
      final disabled = ValueNotifier(false);
      addTearDown(disabled.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder(
            valueListenable: disabled,
            builder: (context, disabled, _) => HeroHereSwitcher(
              child: Stack(
                children: [
                  HeroMode(
                    enabled: !disabled,
                    child: Stack(
                      children: [_heroAt(const ValueKey('a'), _slotRects[0])],
                    ),
                  ),
                  if (disabled) _heroAt(const ValueKey('b'), _slotRects[1]),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final a = _boxOf(const ValueKey('a'));
      final b = _boxOf(const ValueKey('b'), skipOffstage: false);

      disabled.value = true;
      // The frame of the switch, and the frames after it.
      for (var i = 0; i < 3; i++) {
        await tester.pump(_frame);
        expect(find.byKey(_shuttleKey), findsNothing);
        expect(_paintedInPlace(tester, a), isTrue);
        expect(_paintedInPlace(tester, b), isTrue);
      }
      await tester.pumpAndSettle();
      expect(_paintedInPlace(tester, a), isTrue);
      expect(_paintedInPlace(tester, b), isTrue);
    },
  );

  testWidgets('shows the hero a flight flies to once a disabled hero mode '
      'leaves it out mid-flight, as the flight lands on it and flies on to the '
      'next hero', (tester) async {
    // 0: 'a'; 1: 'b' comes in an enabled hero mode; 2: the hero mode is
    // disabled, and 'c' comes.
    final stage = ValueNotifier(0);
    addTearDown(stage.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder(
          valueListenable: stage,
          builder: (context, stage, _) => HeroHereSwitcher(
            child: Stack(
              children: [
                if (stage == 0) _heroAt(const ValueKey('a'), _slotRects[0]),
                if (stage > 0)
                  HeroMode(
                    enabled: stage == 1,
                    child: Stack(
                      children: [_heroAt(const ValueKey('b'), _slotRects[1])],
                    ),
                  ),
                if (stage == 2) _heroAt(const ValueKey('c'), _slotRects[2]),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    stage.value = 1;
    await _pumpSwitch(tester);
    await tester.pump(_frame * 5);
    expect(find.byKey(_shuttleKey), findsOneWidget);

    stage.value = 2;
    await tester.pumpAndSettle();
    expect(find.byKey(_shuttleKey), findsNothing);
    expect(_paintedInPlace(tester, _boxOf(const ValueKey('c'))), isTrue);
    expect(_boxOf(const ValueKey('b')), findsOneWidget);
    expect(
      _paintedInPlace(tester, _boxOf(const ValueKey('b'), skipOffstage: false)),
      isTrue,
    );
  });

  testWidgets('shows a hero under a disabled hero mode that mounts while its '
      'tag flies, on every frame', (tester) async {
    final moved = ValueNotifier(false);
    addTearDown(moved.dispose);
    final off = ValueNotifier(false);
    addTearDown(off.dispose);
    final rebuilds = ValueNotifier(0);
    addTearDown(rebuilds.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ListenableBuilder(
          listenable: Listenable.merge([moved, rebuilds]),
          builder: (context, _) => HeroHereSwitcher(
            child: Stack(
              children: [
                _heroAt(ValueKey(moved.value), _slotRects[moved.value ? 1 : 0]),
                // No switch: the hero mounts below the switcher.
                ValueListenableBuilder(
                  valueListenable: off,
                  builder: (context, off, _) => off
                      ? HeroMode(
                          enabled: false,
                          child: Stack(
                            children: [
                              _heroAt(const ValueKey('off'), _slotRects[2]),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final shuttle = find.byKey(_shuttleKey);
    final box = _boxOf(const ValueKey('off'), skipOffstage: false);

    moved.value = true;
    await _pumpSwitch(tester);
    await tester.pump(_frame * 3);
    expect(tester.any(shuttle), isTrue);

    off.value = true;
    await tester.pump();
    expect(_boxOf(const ValueKey('off')), findsOneWidget);
    expect(_paintedInPlace(tester, box), isTrue);
    // Through the rest of the flight, and a switch on its way.
    for (var i = 0; i < 40 && tester.any(shuttle); i++) {
      if (i == 3) rebuilds.value++;
      await tester.pump(_frame);
      expect(_paintedInPlace(tester, box), isTrue);
    }
    expect(tester.any(shuttle), isFalse);
    await tester.pumpAndSettle();
    expect(_paintedInPlace(tester, box), isTrue);
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

  testWidgets('flies to the first of heroes with the same tag and key', (
    tester,
  ) async {
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
  });

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
