// Copyright 2024 Igor Kurilenko
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

part of 'hero_here.dart';

class _HeroHereState extends State<HeroHere> {
  final _childKey = GlobalKey();
  _Switcher? _switcher;
  bool _offstage = false;
  _KeptRect? _placeholder;
  bool _active = true;

  /// Tells the hero's [_Hide] when the hero hides or shows.
  final _hiding = _Hiding();

  Key get key => widget.key!;

  Object get tag => widget.tag;

  /// Hides or shows the hero. It hides or shows at once, through its
  /// [_Hide], even while the frame builds or lays out; its [_HeroOffstage],
  /// which tells finders whether it's offstage, follows on its next build.
  set offstage(bool value) {
    if (_offstage == value) return;
    _offstage = value;
    // A flight may still hide or show a hero that went away.
    if (!mounted) return;
    _hiding.notify();
    _rebuild();
  }

  bool get offstage => _offstage;

  bool get onstage => !offstage;

  /// Whether the hero went away: it left the tree, and no global key has
  /// moved it back in.
  bool get wentAway => !_active;

  /// Whether a disabled [HeroMode] between the hero and [switcher]'s child
  /// leaves the hero out of switches, as [_Switcher.findHeroes] leaves it
  /// out. A hero that went away isn't left out, nor is one that a global key
  /// moved out of [switcher]'s child, whatever hero modes are above it.
  bool isLeftOutOf(_Switcher switcher) {
    final root = switcher.childElement;
    if (root == null || wentAway) return false;
    return _pathBelow(root, context as Element) == null;
  }

  /// Where the hero was at the last switch, as it would be in [switcher]'s
  /// child now.
  Rect? placeholderRectIn(_Switcher switcher) =>
      _placeholder?.within(switcher.childSize);

  // Runs once the hero mounts, and again each time a global key moves it:
  // within its switcher, into another one, or out of one.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final switcher = _HeroScope.of(context);
    // Deactivating it, as a global key moves it, unregistered it.
    switcher?.register(this);
    if (switcher == _switcher) return;
    _switcher?.unregister(this);
    _switcher = switcher;

    // A hero that mounts, or moves in, while its tag flies hides, unless a
    // disabled hero mode leaves it out of switches, as it then shows as it
    // is. If it mounts anew a hero of the flight, it takes over that hero's
    // part and placeholder; any other hero shows when the flight ends.
    final flight = switcher?.flights[tag];
    if (flight != null) {
      _placeholder = flight.adopt(this)?._placeholder;
      if (!isLeftOutOf(switcher!)) _offstage = true;
    }
  }

  @override
  void activate() {
    super.activate();
    _active = true;
  }

  @override
  void deactivate() {
    super.deactivate();
    _active = false;
    _switcher?.unregister(this);
  }

  /// Keeps where the hero is in [switcher]'s child, as [switcher] switches.
  void willSwitch(_Switcher switcher) {
    final rect = computeRectIn(switcher);
    _placeholder = rect == null ? null : _KeptRect(rect, switcher.childSize);
  }

  /// The layer of the shuttle of a flight that just landed on the hero, kept
  /// until the frame after it landed ends, by when the hero painted.
  final _landedLayer = LayerHandle<OffsetLayer>();

  /// What the hero last showed, as a layer: its own, or, if a flight just
  /// landed on it, which it hasn't painted since, that flight's shuttle's.
  OffsetLayer? get lastLayer =>
      _landedLayer.layer ??
      (_childKey.currentContext?.findRenderObject() as _RenderBoundary?)
          ?.lastLayer;

  /// Keeps [shuttleLayer], of a flight that landed on the hero, as what the
  /// hero shows until it paints.
  void landedFrom(OffsetLayer? shuttleLayer) {
    if (shuttleLayer == null || !mounted) return;
    _landedLayer.layer = shuttleLayer;
    SchedulerBinding.instance.addPostFrameCallback(
      (_) => _landedLayer.layer = null,
    );
  }

  /// Where the hero is in [switcher]'s child, so in that switcher's space,
  /// even if a global key moved the hero into another one.
  Rect? computeRectIn(_Switcher switcher) {
    final space = switcher.childBox;
    if (!_active || space == null) return null;
    return _childKey.currentContext?.findRenderBox()?.rectIn(space);
  }

  @override
  Widget build(BuildContext context) => _HeroOffstage(
    offstage: offstage,
    child: _Hide(
      hides: _hides,
      changes: _hiding,
      child: KeyedSubtree(
        key: _childKey,
        child: _Boundary(child: widget.child),
      ),
    ),
  );

  // A hero set offstage hides at once, not from its next build.
  bool _hides() => offstage || (_switcher?.hides(this) ?? false);

  /// Repaints the hero's [_Hide], since whether it hides changed other than
  /// by its offstage.
  void hidingChanged() {
    if (mounted) _hiding.notify();
  }

  @override
  bool operator ==(Object other) =>
      (other is _Hero && tag == other.tag) && key == other.key;

  @override
  int get hashCode => Object.hash(tag, key);

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      "_Hero(tag: '$tag', key: $key, offstage: $offstage)";

  @override
  void dispose() {
    _hiding.dispose();
    _landedLayer.layer = null;
    super.dispose();
  }

  // While the frame builds or lays out, the hero may not be marked to build,
  // so it builds after the frame.
  void _rebuild() {
    final scheduler = SchedulerBinding.instance;
    if (scheduler.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      scheduler.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }
}

class _Hiding extends ChangeNotifier {
  void notify() => notifyListeners();
}

/// An [Offstage] that only tells finders whether a hero is offstage. It never
/// hides its child itself, so a hidden hero takes the space it would take
/// showing, and moves and resizes on a layout change, such as a window
/// resize, like a showing one. The hero's [_Hide] hides it.
class _HeroOffstage extends Offstage {
  const _HeroOffstage({required super.offstage, super.child});

  @override
  RenderOffstage createRenderObject(BuildContext context) =>
      RenderOffstage(offstage: false);

  @override
  void updateRenderObject(BuildContext context, RenderOffstage renderObject) {}
}

/// Doesn't paint, hit test or describe to semantics its child while [hides]
/// returns true, but keeps its size. Unlike [Offstage], it asks on every
/// paint and hit test, and repaints when [changes] notifies, so it can hide
/// or show a child before the child's next build, even from layout.
class _Hide extends SingleChildRenderObjectWidget {
  final bool Function() hides;
  final Listenable? changes;

  const _Hide({required this.hides, this.changes, super.child});

  @override
  _RenderHide createRenderObject(BuildContext context) =>
      _RenderHide(hides, changes);

  @override
  void updateRenderObject(BuildContext context, _RenderHide renderObject) =>
      renderObject.hides = hides;
}

class _RenderHide extends RenderProxyBox {
  bool Function() hides;
  final Listenable? changes;

  _RenderHide(this.hides, this.changes);

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    changes?.addListener(_changed);
  }

  @override
  void detach() {
    changes?.removeListener(_changed);
    super.detach();
  }

  void _changed() {
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (hides()) return;
    super.paint(context, offset);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) =>
      !hides() && super.hitTest(result, position: position);

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (hides()) return;
    super.visitChildrenForSemantics(visitor);
  }
}

/// A [RepaintBoundary] that tells the layer it last painted into. Each hero
/// paints its child into one, so a switch can show that layer, as the hero
/// last painted it, after the hero went away. The switcher's child is in one
/// too, where the layers a hero is in end.
class _Boundary extends SingleChildRenderObjectWidget {
  const _Boundary({super.key, super.child});

  @override
  _RenderBoundary createRenderObject(BuildContext context) => _RenderBoundary();
}

class _RenderBoundary extends RenderRepaintBoundary {
  /// The layer this boundary last painted into, if it painted.
  OffsetLayer? get lastLayer => layer as OffsetLayer?;
}
