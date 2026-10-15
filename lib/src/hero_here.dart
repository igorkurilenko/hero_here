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

import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

typedef _Hero = _HeroHereState;
typedef _Switcher = _HeroHereSwitcherState;

typedef HeroHereSwitcherLayoutBuilder = Widget Function(
  Widget child,
  Widget sky,
);

typedef AnimationControllerFactory = AnimationController Function(
  TickerProvider tickerProvider,
  Duration duration,
);

typedef AnimationFactory<T> = Animation<T> Function(
  AnimationController controller,
);

typedef StartAnimationCaller = TickerFuture Function(
  AnimationController controller, {
  double? from,
});

typedef RectTweenFactory = RectTween Function(Rect? begin, Rect? end);

typedef HeroHereFlightShuttleBuilder = Widget Function(
  BuildContext flightContext,
  Animation<double> animation,
  HeroHere fromHero,
  HeroHere toHero,
);

/// Flies [HeroHere] widgets between their places in [child] when [child]
/// changes.
///
/// Every rebuild of the switcher runs a switch: it takes a snapshot of the
/// current child, lays the new child out offstage for a frame to find its
/// heroes, then flies each tag whose [HeroHere] changed. The new child shows
/// two frames after the rebuild. The first child shows on the first frame,
/// and nothing flies. Keep frequently changing state, such as timers, streams
/// or text being typed, below the switcher, so it rebuilds only when heroes
/// may move.
class HeroHereSwitcher extends StatefulWidget {
  final Widget? child;
  final HeroHereSwitcherLayoutBuilder layoutBuilder;

  const HeroHereSwitcher({
    super.key,
    this.child,
    this.layoutBuilder = HeroHereSwitcher.defaultLayoutBuilder,
  });

  @override
  State<HeroHereSwitcher> createState() => _HeroHereSwitcherState();

  static Widget defaultLayoutBuilder(Widget child, Widget sky) =>
      Material(child: Stack(children: [child, sky]));
}

class _HeroHereSwitcherState extends State<HeroHereSwitcher>
    with TickerProviderStateMixin {
  final _childKey = GlobalKey();
  final flights = _FlightRegistry();
  late _SwitchingState _switchingState;
  Widget? _child;
  StateSetter setChildState = (_) {};
  RawImage? _childScreenshot;
  bool _childOffstage = false;

  @override
  void dispose() {
    flights.dispose();
    // RawImage doesn't dispose its image.
    _childScreenshot?.image?.dispose();
    super.dispose();
  }

  Set<_Hero> findHeroes() => _childKey.currentContext?.findHeroes() ?? const {};

  bool hidesOnMount(_Hero hero) => switch (_switchingState) {
    final _Mount mount => mount.hiddenHeroes.contains(hero),
    _ => false,
  };

  RawImage? takeChildScreenshot({double pixelRatio = 1.0}) {
    final renderRepaintBoundary = _childKey.currentContext
        ?.findRenderRepaintBoundary();

    return renderRepaintBoundary != null
        ? _takeScreenshot(renderRepaintBoundary, pixelRatio: pixelRatio)
        : null;
  }

  /// Moves to [state], the one way the switcher changes state.
  void enter(_SwitchingState state) {
    _switchingState = state;
    state.enter();
  }

  @override
  void initState() {
    super.initState();
    enter(_Mount(this));
  }

  @override
  Widget build(BuildContext context) {
    _switchingState.onBuild();

    final child = StatefulBuilder(
      builder: (context, setState) {
        setChildState = setState;
        return _buildChild();
      },
    );
    final sky = ListenableBuilder(
      listenable: flights,
      builder: (context, _) => _buildSky(),
    );

    return widget.layoutBuilder(child, sky);
  }

  Widget _buildChild() => Stack(
    children: [
      Offstage(
        offstage: _childOffstage,
        child: RepaintBoundary(key: _childKey, child: _child),
      ),
      ?_childScreenshot,
    ],
  );

  // Flights repaint on every frame. The boundary keeps those repaints off the
  // rest of the screen, whatever the layout builder puts around the sky.
  Widget _buildSky() => RepaintBoundary(
    child: Stack(
      children: [
        ...flights.all.map(
          (flight) => _FlightWidget(key: ValueKey(flight.tag), flight: flight),
        ),
      ],
    ),
  );

  RawImage? _takeScreenshot(
    RenderRepaintBoundary renderRepaintBoundary, {
    double pixelRatio = 1.0,
  }) {
    try {
      return RawImage(
        width: renderRepaintBoundary.size.width,
        height: renderRepaintBoundary.size.height,
        image: renderRepaintBoundary.toImageSync(pixelRatio: pixelRatio),
      );
    } catch (_) {
      return null;
    }
  }
}

/// A phase of the switcher's life. The switcher [enter]s a state once, then
/// tells it about each of its builds; a state moves the switcher on by
/// entering the next one. Every build of the switcher runs a switch: from
/// [_Idle] it enters [_Prepare], and a build during a switch is taken up by
/// that switch, or by the next one if its child arrived too late.
abstract class _SwitchingState {
  final _Switcher switcher;
  final Set<_Hero>? prevSwitchHeroes;

  _SwitchingState(this.switcher, {this.prevSwitchHeroes});

  /// Called once, when the switcher enters this state.
  void enter() {}

  /// Called on each build of the switcher, which may bring a new child.
  void onBuild() {}

  /// Runs [work] after this frame, if the switcher is still mounted by then.
  void afterFrame(VoidCallback work) =>
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (switcher.mounted) work();
      });

  void notifyWillSwitch(Iterable<_Hero> heroes) {
    for (final hero in heroes) {
      hero.willSwitch();
    }
  }
}

/// Shows the first child as it is, with no flights. Of the heroes that share
/// a tag, only the last one shows, as after a switch.
class _Mount extends _SwitchingState {
  /// The heroes that a later hero with their tag hides. They are found when
  /// the first hero paints, once the whole child is built and laid out, so
  /// they hide from the first frame.
  late final Set<_Hero> hiddenHeroes = _findHiddenHeroes(switcher.findHeroes());

  _Mount(super.switcher);

  @override
  void enter() => afterFrame(_mount);

  @override
  void onBuild() => switcher._child = switcher.widget.child;

  void _mount() {
    final heroes = switcher.findHeroes();

    notifyWillSwitch(heroes);

    for (final hero in hiddenHeroes) {
      hero.offstage = true;
    }

    switcher.enter(_Idle(switcher, prevSwitchHeroes: heroes));
  }

  Set<_Hero> _findHiddenHeroes(Set<_Hero> heroes) {
    final lastHeroesByTag = {for (final hero in heroes) hero.tag: hero};
    return heroes.where((hero) => lastHeroesByTag[hero.tag] != hero).toSet();
  }
}

class _Idle extends _SwitchingState {
  _Idle(super.switcher, {super.prevSwitchHeroes});

  @override
  void onBuild() =>
      switcher.enter(_Prepare(switcher, prevSwitchHeroes: prevSwitchHeroes));
}

/// Snapshots the current child and lays the new one out offstage. Builds
/// while it waits need nothing: it takes the newest child.
class _Prepare extends _SwitchingState {
  _Prepare(super.switcher, {super.prevSwitchHeroes});

  @override
  void enter() => afterFrame(_prepareSwitch);

  void _prepareSwitch() {
    final curHeroes = switcher.findHeroes();

    notifyWillSwitch(curHeroes);

    switcher.setChildState(() {
      switcher._childScreenshot = switcher.takeChildScreenshot(
        pixelRatio: MediaQuery.devicePixelRatioOf(switcher.context),
      );
      switcher._child = switcher.widget.child;
      switcher._childOffstage = true;
      switcher.enter(
        _Execute(
          switcher,
          prevSwitchHeroes: prevSwitchHeroes,
          curHeroes: curHeroes,
        ),
      );
    });
  }
}

/// Flies the heroes and shows the new child. A child that arrives while it
/// waits gets a switch of its own after this one.
class _Execute extends _SwitchingState {
  final Set<_Hero> curHeroes;

  _Execute(super.switcher, {super.prevSwitchHeroes, required this.curHeroes});

  @override
  void enter() => afterFrame(_switch);

  void _switch() {
    final nextHeroes = switcher.findHeroes();
    final plan = _SwitchPlan(
      curHeroes: curHeroes,
      nextHeroes: nextHeroes,
      prevSwitchHeroes: prevSwitchHeroes,
      flying: {
        for (final flight in switcher.flights.all) flight.tag: flight.manifest,
      },
    );

    notifyWillSwitch(nextHeroes);

    for (final hero in plan.hiddenHeroes) {
      hero.offstage = true;
    }

    for (final tag in plan.stoppedTags) {
      switcher.flights[tag]!.abort();
    }

    for (final manifest in plan.flights.values) {
      final flight = switcher.flights[manifest.tag];
      if (flight != null) {
        flight.update(manifest);
      } else {
        _Flight.start(
          vsync: switcher,
          registry: switcher.flights,
          manifest: manifest,
        );
      }
    }

    switcher.setChildState(() {
      switcher._childScreenshot?.image?.dispose();
      switcher._childScreenshot = null;
      switcher._childOffstage = false;
      switcher.enter(
        identical(switcher._child, switcher.widget.child)
            ? _Idle(switcher, prevSwitchHeroes: nextHeroes)
            : _Prepare(switcher, prevSwitchHeroes: nextHeroes),
      );
    });
  }
}

/// What a switch does, worked out without changing any hero or flight.
class _SwitchPlan {
  /// The flight each tag needs to start or redirect, by tag.
  final Map<Object, _FlightManifest> flights;

  /// The tags whose flight under way stops.
  final Set<Object> stoppedTags;

  /// The next heroes that hide, since another hero with their tag shows.
  final Set<_Hero> hiddenHeroes;

  _SwitchPlan._(this.flights, this.stoppedTags, this.hiddenHeroes);

  /// Plans the switch from [curHeroes] to [nextHeroes], given the heroes of
  /// the last switch and the manifests of the flights [flying], by tag.
  ///
  /// Of the next heroes that share a tag, the last one is where its tag
  /// flies to. It flies from where its flight under way is, or else from the
  /// current hero with its tag that shows, preferring one of the last
  /// switch.
  factory _SwitchPlan({
    required Set<_Hero> curHeroes,
    required Set<_Hero> nextHeroes,
    required Set<_Hero>? prevSwitchHeroes,
    required Map<Object, _FlightManifest> flying,
  }) {
    final manifests = <Object, _FlightManifest>{};

    for (final x in nextHeroes) {
      final manifest = manifests.putIfAbsent(
        x.tag,
        () => _FlightManifest(tag: x.tag, from: x, to: x),
      );
      manifest.to = x;
    }

    for (final manifest in manifests.values) {
      final flight = flying[manifest.tag];
      if (flight?.from == manifest.to) {
        manifest.from = flight!.to;
      } else if (flight != null) {
        manifest.from = flight.from;
      } else {
        manifest.from =
            curHeroes
                .where((x) => x.tag == manifest.tag)
                .where((x) => x.onstage)
                .where((x) => prevSwitchHeroes?.contains(x) ?? false)
                .firstOrNull ??
            curHeroes
                .where((x) => x.tag == manifest.tag)
                .where((x) => x.onstage)
                .firstOrNull ??
            manifest.from;
      }
    }

    return _SwitchPlan._(
      {
        for (final manifest in manifests.values)
          if (!manifest.isIdle) manifest.tag: manifest,
      },
      {
        for (final tag in flying.keys)
          if (manifests[tag]?.isIdle ?? true) tag,
      },
      {
        for (final hero in nextHeroes)
          if (manifests[hero.tag]!.from != hero &&
              manifests[hero.tag]!.to != hero)
            hero,
      },
    );
  }
}

class HeroHere extends StatefulWidget {
  static const defaultFlightAnimationCurve = Curves.easeInOut;
  static const defaultFlightAnimationDuration = Duration(milliseconds: 300);

  final Object tag;
  final Widget child;
  final Duration? flightAnimationDuration;
  final AnimationControllerFactory? flightAnimationControllerFactory;
  final AnimationFactory<double>? flightAnimationFactory;
  final StartAnimationCaller? forwardFlightAnimation;
  final StartAnimationCaller? reverseFlightAnimation;
  final HeroHereFlightShuttleBuilder? flightShuttleBuilder;
  final RectTweenFactory? rectTweenFactory;
  final Object? payload;

  const HeroHere({
    required super.key,
    required this.tag,
    required this.child,
    this.flightAnimationDuration,
    this.flightAnimationControllerFactory,
    this.flightAnimationFactory,
    this.forwardFlightAnimation,
    this.reverseFlightAnimation,
    this.flightShuttleBuilder,
    this.rectTweenFactory,
    this.payload,
  });

  @override
  State<HeroHere> createState() => _HeroHereState();

  static AnimationController defaultFlightAnimationControllerFactory(
    TickerProvider tickerProvider,
    Duration duration,
  ) => AnimationController(vsync: tickerProvider, duration: duration);

  static Animation<double> defaultFlightAnimationFactory(
    AnimationController controller,
  ) => CurvedAnimation(parent: controller, curve: defaultFlightAnimationCurve);

  static TickerFuture defaultForwardFlightAnimation(
    AnimationController controller, {
    double? from,
  }) => controller.forward(from: from);

  static TickerFuture defaultReverseFlightAnimation(
    AnimationController controller, {
    double? from,
  }) => controller.reverse(from: from);

  static RectTween defaultFlightRectTweenFactory(Rect? begin, Rect? end) =>
      RectTween(begin: begin, end: end);

  static Widget defaultFlightShuttleBuilder(
    BuildContext flightContext,
    Animation<double> animation,
    HeroHere fromHero,
    HeroHere toHero,
  ) => toHero.child;
}

class _HeroHereState extends State<HeroHere> {
  final _childKey = GlobalKey();
  _Switcher? _switcher;
  bool _offstage = false;
  Rect? _placeholderRect;
  bool _active = true;

  Key get key => widget.key!;

  Object get tag => widget.tag;

  set offstage(bool value) {
    if (_offstage == value) return;
    _setState(() => _offstage = value);
  }

  bool get offstage => _offstage;

  bool get onstage => !offstage;

  Rect? get placeholderRect => _placeholderRect;

  @override
  void initState() {
    super.initState();

    _switcher = context.findAncestorStateOfType<_Switcher>();

    // A hero mounted while its tag flies hides until a flight lands on it.
    // If it mounts anew a hero of the flight, it takes over that hero's part
    // and placeholder.
    final flight = _switcher?.flights[tag];
    if (flight != null) {
      _placeholderRect = flight.adopt(this)?.placeholderRect;
      _offstage = true;
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
  }

  void willSwitch() => _placeholderRect = computeGlobalRect();

  Rect? computeGlobalRect() => _active
      ? _childKey.currentContext?.findRenderBox()?.globalRect(Offset.zero)
      : null;

  @override
  Widget build(BuildContext context) => _HeroOffstage(
    offstage: offstage,
    child: _Hide(
      hides: _hides,
      child: KeyedSubtree(key: _childKey, child: widget.child),
    ),
  );

  // A hero set offstage hides at once, not from its next build.
  bool _hides() => offstage || (_switcher?.hidesOnMount(this) ?? false);

  @override
  bool operator ==(Object other) =>
      (other is _Hero && tag == other.tag) && key == other.key;

  @override
  int get hashCode => Object.hash(tag, key);

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      "_Hero(tag: '$tag', key: $key, offstage: $offstage)";

  void _setState(VoidCallback cb) {
    if (!mounted) return cb();
    setState(cb);
  }
}

/// An [Offstage] that keeps its child's size while offstage. A hidden hero
/// takes the space it would take showing, so a layout change, such as a
/// window resize, moves and resizes it like a showing one, and a flight
/// landing on it lands where it shows.
class _HeroOffstage extends Offstage {
  const _HeroOffstage({required super.offstage, super.child});

  @override
  RenderOffstage createRenderObject(BuildContext context) =>
      _RenderHeroOffstage(offstage: offstage);
}

/// Lays out like a [RenderProxyBox] whether offstage or not.
class _RenderHeroOffstage extends RenderOffstage {
  _RenderHeroOffstage({super.offstage});

  @override
  bool get sizedByParent => false;

  @override
  double computeMinIntrinsicWidth(double height) =>
      child?.getMinIntrinsicWidth(height) ?? 0;

  @override
  double computeMaxIntrinsicWidth(double height) =>
      child?.getMaxIntrinsicWidth(height) ?? 0;

  @override
  double computeMinIntrinsicHeight(double width) =>
      child?.getMinIntrinsicHeight(width) ?? 0;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      child?.getMaxIntrinsicHeight(width) ?? 0;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      child?.getDryLayout(constraints) ?? constraints.smallest;

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(constraints, parentUsesSize: true);
    size = child.size;
  }
}

/// Doesn't paint or hit test its child while [hides] returns true, but keeps
/// its size. Unlike [Offstage], it asks on every paint and hit test, so it
/// can hide a child before the child's next build.
class _Hide extends SingleChildRenderObjectWidget {
  final bool Function() hides;

  const _Hide({required this.hides, super.child});

  @override
  _RenderHide createRenderObject(BuildContext context) => _RenderHide(hides);

  @override
  void updateRenderObject(BuildContext context, _RenderHide renderObject) =>
      renderObject.hides = hides;
}

class _RenderHide extends RenderProxyBox {
  bool Function() hides;

  _RenderHide(this.hides);

  @override
  void paint(PaintingContext context, Offset offset) {
    if (hides()) return;
    super.paint(context, offset);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) =>
      !hides() && super.hitTest(result, position: position);
}

class _FlightWidget extends StatefulWidget {
  final _Flight flight;
  const _FlightWidget({super.key, required this.flight});

  @override
  State<_FlightWidget> createState() => _FlightWidgetState();
}

class _FlightWidgetState extends State<_FlightWidget> {
  Rect? fromRect;
  Rect? toRect;
  Rect curRect = Rect.zero;
  _Hero? _legFromHero;

  _Flight get flight => widget.flight;

  _Hero? get toHero => widget.flight.manifest.to;

  _Hero? get fromHero => widget.flight.manifest.from;

  @override
  void initState() {
    super.initState();
    _legFromHero = fromHero;
    flight.addListener(
      () => setState(() {
        // A new leg starts from the hero the last one landed on, so it
        // starts where the shuttle is.
        if (fromHero != _legFromHero) {
          _legFromHero = fromHero;
          fromRect = curRect;
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    fromRect =
        fromRect ?? fromHero?.computeGlobalRect() ?? fromHero?.placeholderRect;

    return AnimatedBuilder(
      animation: flight.animation,
      builder: (context, child) {
        toRect = toHero?.computeGlobalRect() ?? toHero?.placeholderRect;
        curRect = toRect != null
            ? flight.evaluateRect(fromRect, toRect)!
            : curRect;

        return _GlobalRect(
          rect: curRect,
          child: IgnorePointer(child: child),
        );
      },
      child: flight.buildShuttle(context),
    );
  }
}

/// Sizes its child to [rect] and paints it there. The [rect] is global, so
/// the flight lands on its heroes wherever the switcher's sky is placed.
class _GlobalRect extends SingleChildRenderObjectWidget {
  final Rect rect;

  const _GlobalRect({required this.rect, super.child});

  @override
  _RenderGlobalRect createRenderObject(BuildContext context) =>
      _RenderGlobalRect(rect);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderGlobalRect renderObject,
  ) => renderObject.rect = rect;
}

class _RenderGlobalRect extends RenderProxyBox {
  Rect _rect;

  _RenderGlobalRect(this._rect);

  set rect(Rect value) {
    if (_rect == value) return;
    if (_rect.size != value.size) {
      markNeedsLayout();
    } else {
      markNeedsPaint();
    }
    _rect = value;
  }

  Offset get _childOffset => _rect.topLeft - localToGlobal(Offset.zero);

  // Sizing by the constraints alone makes this a relayout boundary, so a
  // shuttle that changes size doesn't lay out the screen on every frame.
  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      constraints.smallest;

  @override
  void performLayout() {
    child?.layout(BoxConstraints.tight(_rect.size));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    context.paintChild(child!, offset + _childOffset);
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final childOffset = _childOffset;
    transform.translateByDouble(childOffset.dx, childOffset.dy, 0, 1);
  }
}

class _Flight extends ChangeNotifier {
  final _FlightRegistry _registry;
  _FlightManifest _manifest;
  final _FlightStyle _style;
  late final AnimationController _controller;
  late final Animation<double> animation;
  _Hero? _nextHero;
  bool _reversed = false;

  _Flight({
    required TickerProvider vsync,
    required this._registry,
    required _FlightManifest manifest,
  }) : _manifest = manifest,
       _style = _FlightStyle.of(
         from: manifest.from.widget,
         to: manifest.to.widget,
       ) {
    _controller = _style.controllerFactory(vsync, _style.duration);
    animation = _style.animationFactory(_controller);
  }

  Object get tag => manifest.tag;

  _FlightManifest get manifest => _manifest;

  factory _Flight.start({
    required TickerProvider vsync,
    required _FlightRegistry registry,
    required _FlightManifest manifest,
  }) {
    final flight = _Flight(
      vsync: vsync,
      registry: registry,
      manifest: manifest,
    );

    registry.add(flight);

    flight._forward().whenComplete(() => registry.remove(flight));

    return flight;
  }

  void update(_FlightManifest manifest) {
    if (_shouldReverse(manifest)) {
      _manifest = manifest.reversed;
      notifyListeners();
      _reverse().whenComplete(() => _registry.remove(this));
    } else if (_shouldForward(manifest)) {
      _manifest = manifest;
      notifyListeners();
      _forward().whenComplete(() => _registry.remove(this));
    } else {
      _registerNextFlight(manifest.to);
    }
  }

  void abort() {
    _controller.stop(canceled: true);
    _registry.remove(this);
  }

  /// Gives [hero] the part in this flight of the hero it mounts anew, the
  /// one with its key, if any, and returns that hero: the hero the flight
  /// leaves, lands on, or lands on next.
  ///
  /// Listeners need no notice: the new hero equals the old one, so the
  /// flight's leg doesn't change.
  _Hero? adopt(_Hero hero) {
    if (hero == _manifest.from) {
      final replaced = _manifest.from;
      _manifest.from = hero;
      return replaced;
    }
    if (hero == _manifest.to) {
      final replaced = _manifest.to;
      _manifest.to = hero;
      return replaced;
    }
    if (hero == _nextHero) {
      final replaced = _nextHero;
      _nextHero = hero;
      return replaced;
    }
    return null;
  }

  Widget buildShuttle(BuildContext context) => _style.shuttleBuilder(
    context,
    animation,
    manifest.from.widget,
    manifest.to.widget,
  );

  Rect? evaluateRect(Rect? begin, Rect? end) =>
      _style.rectTweenFactory(begin, end).evaluate(animation);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _shouldReverse(_FlightManifest manifest) =>
      !_reversed && (_manifest.from == manifest.to);

  bool _shouldForward(_FlightManifest manifest) =>
      _reversed && (_manifest.to == manifest.to);

  void _registerNextFlight(_Hero? to) {
    if (!_reversed && _manifest.to == to) {
      _nextHero = null;
      return;
    }
    if (_reversed && _manifest.from == to) {
      _nextHero = null;
      return;
    }
    _nextHero = to;
  }

  Future<_Flight> _forward({double? from, Completer<_Flight>? completer}) {
    completer ??= Completer();
    _reversed = false;
    _nextHero = null;
    _manifest.from.offstage = true;
    _manifest.to.offstage = true;

    _style.forwardAnimation(_controller, from: from).whenComplete(() {
      if (_controller.status == AnimationStatus.reverse) return;

      if (_nextHero != null) {
        _manifest.from = _manifest.to;
        _manifest.to = _nextHero!;
        notifyListeners();
        _forward(from: 0, completer: completer);
      } else {
        _manifest.to.offstage = false;
        completer!.complete(this);
      }
    });

    return completer.future;
  }

  Future<_Flight> _reverse() {
    final completer = Completer<_Flight>();
    _reversed = true;
    _nextHero = null;

    _style.reverseAnimation(_controller).whenComplete(() {
      if (_controller.status == AnimationStatus.forward) return;

      if (_nextHero != null) {
        _manifest.to = _nextHero!;
        notifyListeners();
        _forward(from: 0, completer: completer);
      } else {
        _manifest.from.offstage = false;
        completer.complete(this);
      }
    });

    return completer.future;
  }
}

/// The flights under way, by tag. Tells its listeners, such as the sky, when
/// a flight starts or ends.
class _FlightRegistry extends ChangeNotifier {
  final _flightsByTag = <Object, _Flight>{};

  Iterable<_Flight> get all => _flightsByTag.values;

  _Flight? operator [](Object tag) => _flightsByTag[tag];

  void add(_Flight flight) {
    _flightsByTag[flight.tag] = flight;
    notifyListeners();
  }

  /// Ends the flight with [flight]'s tag and disposes it.
  void remove(_Flight flight) {
    _flightsByTag.remove(flight.tag)?.dispose();
    notifyListeners();
  }

  @override
  void dispose() {
    for (final flight in all) {
      flight.dispose();
    }
    super.dispose();
  }
}

/// How a flight animates and looks. Each option comes from the hero the
/// flight lands on, else from the hero it leaves, else from [HeroHere]'s
/// default.
class _FlightStyle {
  final Duration duration;
  final AnimationControllerFactory controllerFactory;
  final AnimationFactory<double> animationFactory;
  final StartAnimationCaller forwardAnimation;
  final StartAnimationCaller reverseAnimation;
  final HeroHereFlightShuttleBuilder shuttleBuilder;
  final RectTweenFactory rectTweenFactory;

  const _FlightStyle._({
    required this.duration,
    required this.controllerFactory,
    required this.animationFactory,
    required this.forwardAnimation,
    required this.reverseAnimation,
    required this.shuttleBuilder,
    required this.rectTweenFactory,
  });

  factory _FlightStyle.of({required HeroHere from, required HeroHere to}) {
    T pick<T>(T? Function(HeroHere hero) option, T fallback) =>
        option(to) ?? option(from) ?? fallback;

    return _FlightStyle._(
      duration: pick(
        (x) => x.flightAnimationDuration,
        HeroHere.defaultFlightAnimationDuration,
      ),
      controllerFactory: pick(
        (x) => x.flightAnimationControllerFactory,
        HeroHere.defaultFlightAnimationControllerFactory,
      ),
      animationFactory: pick(
        (x) => x.flightAnimationFactory,
        HeroHere.defaultFlightAnimationFactory,
      ),
      forwardAnimation: pick(
        (x) => x.forwardFlightAnimation,
        HeroHere.defaultForwardFlightAnimation,
      ),
      reverseAnimation: pick(
        (x) => x.reverseFlightAnimation,
        HeroHere.defaultReverseFlightAnimation,
      ),
      shuttleBuilder: pick(
        (x) => x.flightShuttleBuilder,
        HeroHere.defaultFlightShuttleBuilder,
      ),
      rectTweenFactory: pick(
        (x) => x.rectTweenFactory,
        HeroHere.defaultFlightRectTweenFactory,
      ),
    );
  }
}

class _FlightManifest {
  final Object tag;
  _Hero from;
  _Hero to;

  _FlightManifest({required this.tag, required this.from, required this.to});

  bool get isIdle => from == to;

  _FlightManifest get reversed => _FlightManifest(tag: tag, from: to, to: from);

  @override
  int get hashCode => Object.hash(from, to);

  @override
  bool operator ==(Object other) =>
      (other is _FlightManifest && from == other.from) && to == other.to;

  @override
  String toString() => '_FlightManifest(from: $from, to: $to)';
}

extension _RenderBox on RenderBox {
  Rect? globalRect(Offset offset) {
    if (!hasSize) return null;
    return localToGlobal(offset) & size;
  }
}

extension _BuildContext on BuildContext {
  RenderBox? findRenderBox() => findRenderObject() as RenderBox?;

  RenderRepaintBoundary? findRenderRepaintBoundary() =>
      findRenderObject() as RenderRepaintBoundary?;

  Set<_Hero> findHeroes() {
    // ignore: prefer_collection_literals
    final result = LinkedHashSet<_Hero>();

    void findHeroes(Element element) {
      final widget = element.widget;
      if (widget is HeroHere && element is StatefulElement) {
        result.add(element.state as _Hero);
      } else if ((widget is HeroMode && !widget.enabled) ||
          (widget is HeroHereSwitcher) ||
          (widget is _FlightWidget)) {
        return;
      }
      element.visitChildElements(findHeroes);
    }

    visitChildElements(findHeroes);

    return result;
  }
}
