part of '../hero_here_test.dart';

/// What a switch flies and hides, on mount, on a rebuild and with a
/// switch key, and the shuttles it builds.
void _switchesTests() {
  testWidgets('flies from the hero of its tag that the last switch showed, '
      'though one that mounted since comes first', (tester) async {
    final stage = ValueNotifier(0);
    addTearDown(stage.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder(
          valueListenable: stage,
          builder: (context, stage, _) => HeroHereSwitcher(
            // The second stage shows in place, so its new hero mounts with no
            // switch, before the hero the last switch showed.
            switchKey: stage < 2 ? 'a' : 'b',
            child: Stack(
              children: [
                if (stage == 1) _heroAt(const ValueKey('b'), _slotRects[1]),
                if (stage < 2) _heroAt(const ValueKey('a'), _slotRects[0]),
                if (stage == 2) _heroAt(const ValueKey('c'), _slotRects[2]),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    stage.value = 1;
    await tester.pumpAndSettle();
    expect(_boxOf(const ValueKey('a')), findsOneWidget);
    expect(_boxOf(const ValueKey('b')), findsOneWidget);

    stage.value = 2;
    await _pumpSwitch(tester);

    expect(tester.getRect(find.byKey(_shuttleKey)), _slotRects[0]);
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
      await tester.pump(_frame);
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
      _RebuildSwitcher(rebuilds: rebuilds, switchKey: switchKey),
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
      // Each shows the new child on the frame of the rebuild.
      await tester.pump();

      expect(_inShuttle('box1b'), findsOneWidget);
      expect(_inShuttle('box1a'), findsNothing);
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

    expect(_inShuttle('boxb'), findsOneWidget);
    expect(_inShuttle('boxa'), findsNothing);
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
      await tester.pump(_frame);
    }

    expect(find.byKey(_shuttleKey), findsOneWidget);
    expect(builds, 1);
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
      await tester.pump(_frame);
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
}

/// The widget keyed [box] inside the shuttle with [_shuttleKey].
Finder _inShuttle(String box) => find.descendant(
  of: find.byKey(_shuttleKey),
  matching: find.byKey(ValueKey(box)),
);

/// Rebuilds a switcher on each change of [rebuilds] or [switchKey], with a new
/// child keyed by [rebuilds] each time. The switcher's switch key is
/// [switchKey]'s, if any.
class _RebuildSwitcher extends StatelessWidget {
  const _RebuildSwitcher({required this.rebuilds, this.switchKey});

  final ValueNotifier<int> rebuilds;
  final ValueNotifier<Object?>? switchKey;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: ListenableBuilder(
      listenable: Listenable.merge([rebuilds, switchKey]),
      builder: (context, _) => HeroHereSwitcher(
        switchKey: switchKey?.value,
        child: SizedBox.square(key: ValueKey(rebuilds.value), dimension: 40),
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
      color: _heroColor,
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
          child: ColoredBox(key: ValueKey('box$look'), color: _heroColor),
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
                    color: _heroColor,
                  ),
                ),
              ),
          ],
        ),
      ),
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
                    flightShuttleBuilder: _shuttleBox,
                    child: ColoredBox(
                      key: ValueKey('box$slot'),
                      color: _heroColor,
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
    flightShuttleBuilder: _shuttleBox,
    child: child,
  );
}
