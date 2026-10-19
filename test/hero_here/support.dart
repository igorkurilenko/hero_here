part of '../hero_here_test.dart';

const _shuttleKey = ValueKey('shuttle');

/// A shuttle that fills its rect, with [_shuttleKey], so a test can find
/// where a flight is.
Widget _shuttleBox(
  BuildContext _,
  Animation<double> _,
  HeroHere _,
  HeroHere _,
) => const SizedBox.expand(key: _shuttleKey);

/// The color most of the tests' heroes show.
const _heroColor = Color(0xFF2196F3);

/// A frame at 60 frames a second.
const _frame = Duration(milliseconds: 16);

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

/// Sets the view to 800 by 600 logical pixels, at a pixel ratio of 1, for
/// the rest of the test, which may resize it from there.
void _setUpView(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(800, 600);
  addTearDown(tester.view.reset);
}

/// Pumps the frames of a switch: the frame of its build, which shows the new
/// child and after which the switch starts its flights; the next one, from
/// which their shuttles show; and a third, as a switch took before 1.5.0.
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
          flightShuttleBuilder: _shuttleBox,
          child: ColoredBox(key: ValueKey('box$slot'), color: _heroColor),
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
            flightShuttleBuilder: _shuttleBox,
            child: SizedBox.fromSize(size: spots[slot].size),
          ),
        ),
      ),
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
                flightShuttleBuilder: _shuttleBox,
                child: ColoredBox(key: ValueKey('box$slot'), color: _heroColor),
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
                    flightShuttleBuilder: shuttleBuilder ?? _shuttleBox,
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

/// Calls [onPaint] each time it paints.
class _PaintCounter extends CustomPainter {
  _PaintCounter(this.onPaint);

  final VoidCallback onPaint;

  @override
  void paint(Canvas canvas, Size size) => onPaint();

  @override
  bool shouldRepaint(_PaintCounter oldDelegate) => false;
}

/// A hero with [key] at [rect] in a stack, whose shuttle is a box with
/// [_shuttleKey]. [_boxOf] finds its child.
Widget _heroAt(Key key, Rect rect) => Positioned.fromRect(
  rect: rect,
  child: HeroHere(
    key: key,
    tag: 'hero',
    flightShuttleBuilder: _shuttleBox,
    child: const ColoredBox(color: _heroColor),
  ),
);

/// The child of the hero with [key] from [_heroAt], while it shows, or also
/// while it hides unless [skipOffstage].
Finder _boxOf(Key key, {bool skipOffstage = true}) => find.descendant(
  of: find.byKey(key, skipOffstage: skipOffstage),
  matching: find.byType(ColoredBox, skipOffstage: skipOffstage),
  skipOffstage: skipOffstage,
);
