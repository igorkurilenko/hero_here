part of '../hero_here_test.dart';

/// Flights through window resizes, and the switcher in layouts.
void _layoutTests() {
  testWidgets('shows its heroes on each frame of a window resize, even when '
      'sizes are read above it', (tester) async {
    _setUpView(tester);

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

  testWidgets('lands on a hidden hero that a resize changes the size of', (
    tester,
  ) async {
    _setUpView(tester);
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
      await tester.pump(_frame);
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

  testWidgets('flies to where its hero is on the frame of a window resize', (
    tester,
  ) async {
    _setUpView(tester);
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
    await tester.pump(_frame);

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
      _setUpView(tester);
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
      // The switch keeps where the hero it leaves is, and starts the flight
      // after this frame.
      await tester.pump();
      tester.view.physicalSize = const Size(400, 600);
      await tester.pump(); // The shuttle shows from this frame.
      await tester.pump();

      expect(
        tester.getRect(find.byKey(_shuttleKey)),
        _rectMoreOrLessEquals(start),
      );
    });
  }

  for (final (redirect, how, course) in [
    (HeroHereFlightRedirect.divert, 'diverts', [2]),
    (HeroHereFlightRedirect.restart, 'restarts', [2]),
    (HeroHereFlightRedirect.chain, 'turns back', [0]),
    (HeroHereFlightRedirect.chain, 'turns around again', [0, 1]),
  ]) {
    testWidgets('$how from where its shuttle would be after the window '
        'shrinks', (tester) async {
      _setUpView(tester);
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
        await tester.pump(); // The flight changes course after this frame.
        await tester.pump();
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
      await tester.pump(_frame);

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
    _setUpView(tester);
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
    await tester.pump(_frame);

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
                    flightShuttleBuilder: _shuttleBox,
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

  testWidgets('lets what is behind it show through by default', (tester) async {
    _setUpView(tester);
    const green = Color(0xFF00FF00);

    await tester.pumpWidget(
      const MaterialApp(
        home: ColoredBox(
          color: green,
          child: HeroHereSwitcher(child: SizedBox.expand()),
        ),
      ),
    );

    expect(await _pixelAt(tester, const Offset(400, 300)), green);
  });

  testWidgets('gives its child a material for ink by default', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: HeroHereSwitcher(
          child: Center(
            // An ink well needs a material above it.
            child: InkWell(onTap: () => taps++, child: const Text('ink')),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ink'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(taps, 1);
  });

  testWidgets('keeps taps on its empty space from what is behind it by '
      'default', (tester) async {
    var behind = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => behind++,
              ),
            ),
            const HeroHereSwitcher(child: SizedBox.expand()),
          ],
        ),
      ),
    );
    await tester.tapAt(const Offset(400, 300));

    expect(behind, 0);
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
                    flightShuttleBuilder: _shuttleBox,
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
                  flightShuttleBuilder: _shuttleBox,
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
                      flightShuttleBuilder: _shuttleBox,
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
            child: const ColoredBox(color: _heroColor),
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
            flightShuttleBuilder: shuttleBuilder ?? _shuttleBox,
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
