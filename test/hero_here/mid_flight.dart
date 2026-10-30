part of '../hero_here_test.dart';

/// Heroes that mount, move or go while their tag flies.
void _midFlightTests() {
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
      await tester.pump(_frame);
    }
    expect(shuttle, findsNothing);
    expect(
      (shuttleRect.topLeft - heroRect.topLeft).distance,
      lessThan(2),
      reason: 'The shuttle landed at $shuttleRect, the hero is at $heroRect.',
    );
  });

  testWidgets('flies to where the hero it flies to is on the frame a list '
      'lays it out anew, as an item comes above it', (tester) async {
    final inList = ValueNotifier(false);
    addTearDown(inList.dispose);
    final items = ValueNotifier(['x', 'y']);
    addTearDown(items.dispose);

    await tester.pumpWidget(_ListSwitcher(inList: inList, items: items));
    await tester.pumpAndSettle();
    final from = tester.getRect(find.byKey(const ValueKey('a')));

    inList.value = true;
    await _pumpSwitch(tester);
    await tester.pump(_ListSwitcher.duration * .25);

    // The list lays out on its own, after the flight's layout measured the
    // hero where it was.
    items.value = ['w', 'x', 'y'];
    await tester.pump(_frame);

    final to = tester.getRect(
      find.byKey(const ValueKey('b'), skipOffstage: false),
    );
    final t =
        (_ListSwitcher.duration * .25 + _frame).inMicroseconds /
        _ListSwitcher.duration.inMicroseconds;
    expect(
      tester.getRect(find.byKey(_shuttleKey)),
      _rectMoreOrLessEquals(Rect.lerp(from, to, t)!),
    );
  });
}

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
          child: ColoredBox(key: ValueKey(box), color: _heroColor),
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
                    flightShuttleBuilder: _shuttleBox,
                    child: ColoredBox(
                      key: ValueKey('box$slot'),
                      color: _heroColor,
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
          child: ColoredBox(key: ValueKey(box), color: _heroColor),
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
          flightShuttleBuilder: _shuttleBox,
          child: const ColoredBox(color: _heroColor),
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
          flightShuttleBuilder: _shuttleBox,
          child: ColoredBox(key: ValueKey('box-$key'), color: _heroColor),
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
          flightShuttleBuilder: _shuttleBox,
          child: ColoredBox(key: ValueKey('box-$key'), color: _heroColor),
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
    flightShuttleBuilder: _shuttleBox,
    child: const SizedBox(width: 40, height: 40),
  );
}

/// Hero 'a' above a list of [items], or, [inList], hero 'b' with its tag
/// after the items, in the list, so 'a' flies there. Its flight runs at an
/// even pace over [duration].
class _ListSwitcher extends StatelessWidget {
  const _ListSwitcher({required this.inList, required this.items});

  static const duration = Duration(seconds: 1);

  final ValueNotifier<bool> inList;
  final ValueNotifier<List<String>> items;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: ValueListenableBuilder(
      valueListenable: inList,
      builder: (context, inList, _) {
        Widget hero(String key) => HeroHere(
          key: ValueKey(key),
          tag: 'hero',
          flightShuttleBuilder: _shuttleBox,
          flightAnimationDuration: duration,
          flightAnimationFactory: (controller) => controller,
          child: const SizedBox.square(
            dimension: 40,
            child: ColoredBox(color: _heroColor),
          ),
        );
        return HeroHereSwitcher(
          child: Column(
            children: [
              SizedBox(height: 40, child: inList ? null : hero('a')),
              Expanded(
                child: ValueListenableBuilder(
                  valueListenable: items,
                  builder: (context, items, _) => ListView(
                    children: [
                      for (final item in items)
                        SizedBox(key: ValueKey(item), height: 50),
                      if (inList) Align(alignment: .topLeft, child: hero('b')),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
