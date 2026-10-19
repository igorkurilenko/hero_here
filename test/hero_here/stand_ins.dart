part of '../hero_here_test.dart';

/// The stand-ins a switch shows for the heroes that went away.
void _standInsTests() {
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
      _setUpView(tester);
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

  testWidgets('stands in for a hero where a composited transform target puts '
      'it', (tester) async {
    _setUpView(tester);
    final slot = ValueNotifier(0);
    addTearDown(slot.dispose);
    final link = LayerLink();

    await tester.pumpWidget(
      _PlacedSwitcher(
        slot: slot,
        place: (hero) => Positioned.fromRect(
          rect: _clippedRect,
          child: CompositedTransformTarget(link: link, child: hero),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _expectRedIn(tester, _clippedRect);

    slot.value = 1;
    await tester.pump();

    await _expectRedIn(tester, _clippedRect);
  });

  testWidgets('stands in for a hero where a composited transform follower '
      'puts it', (tester) async {
    _setUpView(tester);
    final slot = ValueNotifier(0);
    addTearDown(slot.dispose);
    final link = LayerLink();

    await tester.pumpWidget(
      _PlacedSwitcher(
        slot: slot,
        others: [
          Positioned(
            left: 300,
            top: 50,
            child: CompositedTransformTarget(
              link: link,
              child: const SizedBox.square(dimension: 10),
            ),
          ),
        ],
        // Laid out away from the clipped rect, but drawn where the target
        // is, moved to the clipped rect.
        place: (hero) => Positioned.fromRect(
          rect: const Offset(20, 30) & _clippedRect.size,
          child: CompositedTransformFollower(
            link: link,
            offset: _clippedRect.topLeft - const Offset(300, 50),
            child: hero,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _expectRedIn(tester, _clippedRect);

    slot.value = 1;
    await tester.pump();

    await _expectRedIn(tester, _clippedRect);
  });

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
}

/// Where [layer] was on the screen on the last frame, if it was in it.
Offset? _paintedAt(Layer layer) {
  if (!layer.attached) return null;
  var offset = Offset.zero;
  for (Layer? x = layer; x != null && x is! TransformLayer; x = x.parent) {
    if (x is OffsetLayer) offset += x.offset;
  }
  return offset;
}

const _clippedRect = Rect.fromLTWH(100, 100, 200, 200);

/// Expects red at the corners of [rect], just inside it, and in its middle,
/// and not just outside its top left corner.
Future<void> _expectRedIn(WidgetTester tester, Rect rect) async {
  const red = Color(0xFFFF0000);
  expect(await _pixelAt(tester, rect.center), red);
  expect(await _pixelAt(tester, rect.topLeft + const Offset(4, 4)), red);
  expect(await _pixelAt(tester, rect.bottomRight - const Offset(4, 4)), red);
  expect(await _pixelAt(tester, rect.topLeft - const Offset(4, 4)), isNot(red));
}

/// Shows a red hero that [place] puts in the switcher's child, or, when
/// [slot] is 1, a hero with its tag in the third slot of [_slotRects]. The
/// [others] show either way.
class _PlacedSwitcher extends StatelessWidget {
  const _PlacedSwitcher({
    required this.slot,
    required this.place,
    this.others = const [],
  });

  final ValueNotifier<int> slot;
  final Widget Function(Widget hero) place;
  final List<Widget> others;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: ValueListenableBuilder(
      valueListenable: slot,
      builder: (context, slot, _) => HeroHereSwitcher(
        child: Stack(
          children: [
            ...others,
            if (slot == 0)
              place(
                const HeroHere(
                  key: ValueKey(0),
                  tag: 'hero',
                  child: ColoredBox(color: Color(0xFFFF0000)),
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
}

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
