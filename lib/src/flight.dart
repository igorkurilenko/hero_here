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

class _FlightWidget extends StatelessWidget {
  final _Flight flight;
  const _FlightWidget({super.key, required this.flight});

  // The layout builder builds what changes below it while it lays out, which
  // is after the switcher's child lays out, in the default layout. So the
  // flight finds its heroes where this frame's layout puts them, such as on
  // the frame of a window resize, rather than where they were on the last
  // frame, and its shuttle shows what they are on this frame's build.
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, _) => ListenableBuilder(
      listenable: flight,
      builder: (context, _) => AnimatedBuilder(
        animation: flight.animation,
        builder: (context, _) => _ShuttleRect(
          rect: flight.evaluateRect(),
          space: () => flight._registry.switcher.childBox,
          // The shuttle moves on each frame. In its own layer, it repaints
          // only when it changes, such as when it changes size.
          child: IgnorePointer(
            child: _ShuttleLayer(flight: flight, child: flight.shuttle),
          ),
        ),
      ),
    ),
  );
}

/// The shuttle's own layer, which its flight knows, so the hero the flight
/// lands on can show it until the hero paints.
class _ShuttleLayer extends SingleChildRenderObjectWidget {
  final _Flight flight;

  const _ShuttleLayer({required this.flight, super.child});

  @override
  _RenderShuttleLayer createRenderObject(BuildContext context) =>
      _RenderShuttleLayer(flight);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderShuttleLayer renderObject,
  ) => renderObject.flight = flight;
}

class _RenderShuttleLayer extends RenderRepaintBoundary {
  _Flight _flight;

  _RenderShuttleLayer(this._flight);

  set flight(_Flight value) {
    if (identical(_flight, value)) return;
    if (identical(_flight._shuttleLayer, this)) _flight._shuttleLayer = null;
    _flight = value;
    if (attached) _flight._shuttleLayer = this;
  }

  /// The layer this boundary last painted into, if it painted.
  OffsetLayer? get lastLayer => layer as OffsetLayer?;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _flight._shuttleLayer = this;
  }

  @override
  void detach() {
    if (identical(_flight._shuttleLayer, this)) _flight._shuttleLayer = null;
    super.detach();
  }
}

/// Builds a flight's shuttle from the heroes it shows.
class _Shuttle extends StatelessWidget {
  final HeroHereFlightShuttleBuilder builder;
  final Animation<double> animation;
  final HeroHere from;
  final HeroHere to;

  const _Shuttle({
    required this.builder,
    required this.animation,
    required this.from,
    required this.to,
  });

  @override
  Widget build(BuildContext context) => builder(context, animation, from, to);
}

/// Sizes its child to [rect] and paints it there. The [rect] is global, so
/// the flight lands on its heroes wherever the switcher's sky is placed.
/// Places a shuttle at [rect], in the space of the switcher's child, which
/// [space] gives. It works out where that is on the screen when it paints,
/// once the whole screen is laid out, so the shuttle is where its heroes are
/// even when the switcher moves on the frame, such as on a window resize
/// that lays the switcher out anew.
class _ShuttleRect extends SingleChildRenderObjectWidget {
  final Rect rect;
  final RenderBox? Function() space;

  const _ShuttleRect({required this.rect, required this.space, super.child});

  @override
  _RenderShuttleRect createRenderObject(BuildContext context) =>
      _RenderShuttleRect(rect, space);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderShuttleRect renderObject,
  ) => renderObject
    ..rect = rect
    ..space = space;
}

class _RenderShuttleRect extends RenderProxyBox {
  Rect _rect;
  RenderBox? Function() space;

  _RenderShuttleRect(this._rect, this.space);

  set rect(Rect value) {
    if (_rect == value) return;
    if (_rect.size != value.size) {
      markNeedsLayout();
    } else {
      markNeedsPaint();
    }
    _rect = value;
  }

  Offset get _childOffset {
    final topLeft = space()?.localToGlobal(_rect.topLeft) ?? _rect.topLeft;
    return topLeft - localToGlobal(Offset.zero);
  }

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

  /// Where the shuttle is on each frame.
  late final _path = _FlightPath(_style.rectTweenFactory);

  /// What the shuttle shows as the hero it leaves once the flight diverts:
  /// the shuttle as it was then.
  HeroHere? _divertedFrom;

  /// The shuttle as last made, by [shuttle].
  _Shuttle? _shuttle;

  /// The layer the shuttle paints into, while it shows.
  _RenderShuttleLayer? _shuttleLayer;

  /// The heroes with no part in this flight that mounted while it flew, with
  /// no switch since. They hide until it ends.
  final _latecomers = <_Hero>{};

  /// Counts the runs of the flight's animation and the flight's end. A run's
  /// completion that comes after a later run started or the flight ended does
  /// nothing: on the web, it comes after the frame it landed on, so after a
  /// switch on that frame that redirected or stopped the flight.
  int _runs = 0;

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
    flight._forward();

    return flight;
  }

  void update(_FlightManifest manifest) {
    // The switch decides about every hero, the latecomers too.
    _latecomers.clear();

    if (_shouldReverse(manifest)) {
      _manifest = manifest.reversed;
      _path.turnHere(value: animation.value, size: _childSize);
      notifyListeners();
      _reverse();
    } else if (_shouldForward(manifest)) {
      _manifest = manifest;
      _path.turnHere(value: animation.value, size: _childSize);
      notifyListeners();
      _forward();
    } else if (manifest.to == _target) {
      _nextHero = null;
    } else if (_style.redirect == HeroHereFlightRedirect.divert) {
      _divert(manifest.to);
    } else {
      _nextHero = manifest.to;
    }
  }

  void abort() {
    _controller.stop(canceled: true);
    _end();
  }

  /// Gives [hero] the part in this flight of the hero it mounts anew, the
  /// one with its key, if any, and returns that hero: the hero the flight
  /// leaves, lands on, or lands on next. Any other hero is a latecomer, which
  /// shows when the flight ends.
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
    _latecomers
      ..remove(hero)
      ..add(hero);
    return null;
  }

  /// The shuttle, made anew only when a hero it shows has a new widget: on a
  /// new leg, or when a switch or a rebuild gives a hero of the flight a new
  /// widget mid-flight. So it builds then, and on no other frame.
  Widget get shuttle {
    final from = _divertedFrom ?? _manifest.from.widget;
    final to = _manifest.to.widget;
    final shuttle = _shuttle;
    if (shuttle != null &&
        identical(shuttle.from, from) &&
        identical(shuttle.to, to)) {
      return shuttle;
    }
    return _shuttle = _Shuttle(
      builder: _style.shuttleBuilder,
      animation: animation,
      from: from,
      to: to,
    );
  }

  /// Works out where the shuttle is on this frame: on its way from where its
  /// leg began to where the hero it flies to is. While that hero is nowhere,
  /// the shuttle stays where it was.
  Rect evaluateRect() => _path.evaluate(
    end: _manifest.to.computeRect() ?? _manifest.to.placeholderRect,
    from: () => _manifest.from.computeRect() ?? _manifest.from.placeholderRect,
    reversed: _reversed,
    value: animation.value,
    t: _controller.value,
    elapsed: _controller.lastElapsedDuration,
    duration: _controller.duration ?? _style.duration,
    size: _childSize,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The hero the shuttle is on its way to.
  _Hero get _target => _reversed ? _manifest.from : _manifest.to;

  bool _shouldReverse(_FlightManifest manifest) =>
      _style.redirect == HeroHereFlightRedirect.chain &&
      !_reversed &&
      (_manifest.from == manifest.to);

  bool _shouldForward(_FlightManifest manifest) =>
      _reversed && (_manifest.to == manifest.to);

  /// Flies on to [hero] from where the shuttle is, at the speed it has, and
  /// from what it shows.
  void _divert(_Hero hero) {
    _path.divert(
      to: hero.computeRect() ?? hero.placeholderRect,
      size: _childSize,
    );
    _divertedFrom = _freezeShuttle();
    _manifest.to = hero;
    notifyListeners();
    _forward(from: 0);
  }

  /// A stand-in for the hero the flight leaves, with that hero's key, tag and
  /// payload, whose child is the shuttle as it is now, stopped.
  HeroHere _freezeShuttle() {
    final from = _divertedFrom ?? _manifest.from.widget;
    final to = _manifest.to.widget;
    final stopped = AlwaysStoppedAnimation(animation.value);

    return HeroHere(
      key: from.key,
      tag: from.tag,
      payload: from.payload,
      child: Builder(
        builder: (context) => _style.shuttleBuilder(context, stopped, from, to),
      ),
    );
  }

  /// The size the switcher's child has now.
  Size? get _childSize => _registry.switcher.childSize;

  void _forward({double? from}) {
    _reversed = false;
    _nextHero = null;
    _manifest.from.offstage = true;
    _manifest.to.offstage = true;

    final run = ++_runs;
    _style
        .forwardAnimation(_controller, from: from)
        .whenComplete(() => _landForward(run));
  }

  void _landForward(int run) {
    if (run != _runs) return;

    if (_nextHero != null) {
      // The next leg starts on the hero the shuttle landed on.
      _path.beginLeg(onHero: true, size: _childSize);
      _manifest.from = _manifest.to;
      _manifest.to = _nextHero!;
      notifyListeners();
      _forward(from: 0);
    } else {
      _end(landedOn: _manifest.to);
    }
  }

  void _reverse() {
    _reversed = true;
    _nextHero = null;

    final run = ++_runs;
    _style.reverseAnimation(_controller).whenComplete(() => _landBack(run));
  }

  void _landBack(int run) {
    if (run != _runs) return;

    if (_nextHero != null) {
      // The next leg starts on the hero the shuttle landed back on.
      _path.beginLeg(onHero: true, size: _childSize);
      _manifest.to = _nextHero!;
      notifyListeners();
      _forward(from: 0);
    } else {
      _end(landedOn: _manifest.from);
    }
  }

  /// Ends this flight: shows the hero it [landedOn], if any, and the
  /// latecomers, and leaves the registry, which disposes it.
  void _end({_Hero? landedOn}) {
    _runs++;
    landedOn?.landedFrom(_shuttleLayer?.lastLayer);
    landedOn?.offstage = false;
    for (final hero in _latecomers) {
      hero.offstage = false;
    }
    _registry.remove(this);
  }
}

/// The flights under way, by tag. Tells its listeners, such as the sky, when
/// a flight starts or ends.
class _FlightRegistry extends ChangeNotifier {
  final _flightsByTag = <Object, _Flight>{};

  /// The switcher whose flights these are.
  final _Switcher switcher;

  _FlightRegistry(this.switcher);

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

  /// Tells the sky to build anew, such as when a switch drops its stand-ins.
  void changed() => notifyListeners();

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
  final HeroHereFlightAnimationControllerFactory controllerFactory;
  final HeroHereFlightAnimationFactory animationFactory;
  final HeroHereFlightAnimationStarter forwardAnimation;
  final HeroHereFlightAnimationStarter reverseAnimation;
  final HeroHereFlightShuttleBuilder shuttleBuilder;
  final HeroHereFlightRectTweenFactory rectTweenFactory;
  final HeroHereFlightRedirect redirect;

  const _FlightStyle._({
    required this.duration,
    required this.controllerFactory,
    required this.animationFactory,
    required this.forwardAnimation,
    required this.reverseAnimation,
    required this.shuttleBuilder,
    required this.rectTweenFactory,
    required this.redirect,
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
      redirect: pick((x) => x.flightRedirect, HeroHere.defaultFlightRedirect),
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
