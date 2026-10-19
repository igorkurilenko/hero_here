part of '../hero_here_test.dart';

/// What a flight lays out and paints, and what it leaves alone.
void _performanceTests() {
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
      await tester.pump(_frame);
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
      await tester.pump(_frame);
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
      await tester.pump(_frame);
    }

    expect(find.byKey(_moverKey), findsOneWidget);
    expect(shuttlePaints, 0);
  });
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
