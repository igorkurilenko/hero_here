part of '../hero_here_test.dart';

/// Flights between heroes, and the options they take.
void _flightsTests() {
  for (final textDirection in TextDirection.values) {
    testWidgets(
      'flies between hero rects when the switcher is away from the origin '
      '($textDirection)',
      (tester) async {
        final moved = ValueNotifier(false);
        addTearDown(moved.dispose);

        await tester.pumpWidget(
          _OffsetSwitcher(moved: moved, textDirection: textDirection),
        );
        await tester.pumpAndSettle();

        final fromRect = tester.getRect(find.byKey(const ValueKey(false)));

        moved.value = true;
        await _pumpSwitch(tester);

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
      },
    );
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
        await tester.pump(_frame);
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
          flightShuttleBuilder: _shuttleBox,
          child: const ColoredBox(color: _heroColor),
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
                    flightShuttleBuilder: _shuttleBox,
                    child: const ColoredBox(color: _heroColor),
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
