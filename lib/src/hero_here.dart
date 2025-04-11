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
    Widget child, Widget sky);

typedef AnimationControllerFactory = AnimationController Function(
    TickerProvider tickerProvider, Duration duration);

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

  static Widget defaultLayoutBuilder(Widget child, Widget sky) => Material(
        child: Stack(
          children: [child, sky],
        ),
      );
}

class _HeroHereSwitcherState extends State<HeroHereSwitcher>
    with TickerProviderStateMixin {
  final _childKey = GlobalKey();
  final _flightsByTag = <Object, _Flight>{};
  late _SwitchingState _switchingState = _Prepare(this);
  Widget? _child;
  StateSetter setChildState = (_) {};
  StateSetter setSkyState = (_) {};
  RawImage? _childScreenshot;
  bool _childOffstage = false;

  Iterable<_Flight> get flights => _flightsByTag.values;

  Iterable<Object> get flightTags => _flightsByTag.keys;

  void addFlight(_Flight flight) => _flightsByTag[flight.tag] = flight;

  void removeFlight(_Flight flight) =>
      _flightsByTag.remove(flight.tag)?.dispose();

  @override
  void dispose() {
    for (final flight in flights) {
      flight.dispose();
    }
    super.dispose();
  }

  Set<_Hero> findHeroes() => _childKey.currentContext?.findHeroes() ?? const {};

  _Flight? getFlight(Object tag) => _flightsByTag[tag];

  RawImage? takeChildScreenshot({double pixelRatio = 1.0}) {
    final renderRepaintBoundary =
        _childKey.currentContext?.findRenderRepaintBoundary();

    return renderRepaintBoundary != null
        ? _takeScreenshot(renderRepaintBoundary, pixelRatio: pixelRatio)
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final child = StatefulBuilder(builder: (context, setState) {
      setChildState = setState;
      return _buildChild();
    });
    final sky = StatefulBuilder(builder: (context, setState) {
      setSkyState = setState;
      return _buildSky();
    });

    return widget.layoutBuilder(child, sky);
  }

  Widget _buildChild() {
    _switchingState.execute();

    return Stack(
      children: [
        Offstage(
          offstage: _childOffstage,
          child: RepaintBoundary(
            key: _childKey,
            child: _child,
          ),
        ),
        if (_childScreenshot != null) _childScreenshot!,
      ],
    );
  }

  Widget _buildSky() => Stack(
        children: [
          ...flights.map(
            (flight) => _FlightWidget(
              key: ValueKey(flight.tag),
              flight: flight,
            ),
          ),
        ],
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

abstract class _SwitchingState {
  final _Switcher switcher;
  final Set<_Hero>? prevSwitchHeroes;

  _SwitchingState(
    this.switcher, {
    this.prevSwitchHeroes,
  });

  void notifyWillSwitch(Iterable<_Hero> heroes) {
    for (final hero in heroes) {
      hero.willSwitch();
    }
  }

  void execute();
}

class _Idle extends _SwitchingState {
  _Idle(
    super.switcher, {
    super.prevSwitchHeroes,
  });

  @override
  void execute() {
    switcher._child = switcher.widget.child;
    switcher._switchingState = _Prepare(
      switcher,
      prevSwitchHeroes: prevSwitchHeroes,
    );
  }
}

class _Prepare extends _SwitchingState {
  _Prepare(
    super.switcher, {
    super.prevSwitchHeroes,
  });

  @override
  void execute() =>
      WidgetsBinding.instance.addPostFrameCallback(_prepareSwitch);

  void _prepareSwitch(_) {
    final curHeroes = switcher.findHeroes();

    notifyWillSwitch(curHeroes);

    switcher.setChildState(() {
      switcher._childScreenshot = switcher.takeChildScreenshot(
        pixelRatio: MediaQuery.devicePixelRatioOf(switcher.context),
      );
      switcher._child = switcher.widget.child;
      switcher._childOffstage = true;
      switcher._switchingState = _Execute(
        switcher,
        prevSwitchHeroes: prevSwitchHeroes,
        curHeroes: curHeroes,
      );
    });
  }
}

class _Execute extends _SwitchingState {
  final Set<_Hero> curHeroes;

  _Execute(
    super.switcher, {
    super.prevSwitchHeroes,
    required this.curHeroes,
  });

  @override
  void execute() => WidgetsBinding.instance.addPostFrameCallback(_switch);

  void _switch(_) {
    final nextHeroes = switcher.findHeroes();
    final flightManifestsByTag = _getFlightManifests(nextHeroes);

    notifyWillSwitch(nextHeroes);

    _offstageRedundantNextHeroes(nextHeroes, flightManifestsByTag);

    _dispatchFlights(flightManifestsByTag);

    switcher.setChildState(() {
      switcher._childScreenshot = null;
      switcher._childOffstage = false;
      switcher._switchingState = _Idle(
        switcher,
        prevSwitchHeroes: nextHeroes,
      );
    });
  }

  Map<Object, _FlightManifest> _getFlightManifests(Set<_Hero> nextHeroes) {
    final result = <Object, _FlightManifest>{};

    for (final x in nextHeroes) {
      final manifest = result.putIfAbsent(
          x.tag, () => _FlightManifest(tag: x.tag, from: x, to: x));
      manifest.to = x;
    }

    for (final manifest in result.values) {
      final existingFlight = switcher.getFlight(manifest.tag);
      if (existingFlight?.manifest.from == manifest.to) {
        manifest.from = existingFlight!.manifest.to;
      } else if (existingFlight != null) {
        manifest.from = existingFlight.manifest.from;
      } else {
        manifest.from = curHeroes
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
    return result;
  }

  void _offstageRedundantNextHeroes(
    Set<_Hero> nextHeroes,
    Map<Object, _FlightManifest> flightManifestsByTag,
  ) {
    for (final hero in nextHeroes) {
      final manifest = flightManifestsByTag[hero.tag];
      if (manifest?.from != hero && manifest?.to != hero) {
        hero.offstage = true;
      }
    }
  }

  void _dispatchFlights(Map<Object, _FlightManifest> flightManifestsByTag) {
    final tags =
        flightManifestsByTag.keys.followedBy(switcher.flightTags).toSet();

    for (final tag in tags) {
      final flightManifest = flightManifestsByTag[tag];
      final existingFlight = switcher.getFlight(tag);

      if (flightManifest == null || flightManifest.isIdle) {
        existingFlight?.abort();
        continue;
      }

      if (existingFlight != null) {
        existingFlight.update(flightManifest);
      } else {
        _Flight.start(
          switcher: switcher,
          manifest: flightManifest,
        );
      }
    }
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
          TickerProvider tickerProvider, Duration duration) =>
      AnimationController(
        vsync: tickerProvider,
        duration: duration,
      );

  static Animation<double> defaultFlightAnimationFactory(
          AnimationController controller) =>
      CurvedAnimation(
        parent: controller,
        curve: defaultFlightAnimationCurve,
      );

  static TickerFuture defaultForwardFlightAnimation(
          AnimationController controller,
          {double? from}) =>
      controller.forward(from: from);

  static TickerFuture defaultReverseFlightAnimation(
          AnimationController controller,
          {double? from}) =>
      controller.reverse(from: from);

  static RectTween defaultFlightRectTweenFactory(Rect? begin, Rect? end) =>
      RectTween(begin: begin, end: end);

  static Widget defaultFlightShuttleBuilder(BuildContext flightContext,
          Animation<double> animation, HeroHere fromHero, HeroHere toHero) =>
      toHero.child;
}

class _HeroHereState extends State<HeroHere> {
  final _childKey = GlobalKey();
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

    final switcher = context.findAncestorStateOfType<_Switcher>();
    final existingFlight = switcher?.getFlight(tag);

    if (existingFlight != null) {
      _initState(existingFlight);
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
  Widget build(BuildContext context) => SizedBox(
        width: offstage ? _placeholderRect?.width : null,
        height: offstage ? _placeholderRect?.height : null,
        child: Offstage(
          offstage: offstage,
          child: KeyedSubtree(
            key: _childKey,
            child: widget.child,
          ),
        ),
      );

  @override
  bool operator ==(Object other) =>
      (other is _Hero && tag == other.tag) && key == other.key;

  @override
  int get hashCode => Object.hash(tag, key);

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      "_Hero(tag: '$tag', key: $key, offstage: $offstage)";

  void _initState(_Flight existingFlight) {
    if (key == existingFlight.manifest.from.key) {
      _placeholderRect = existingFlight.manifest.from.placeholderRect;
      // TODO: should notify existing flight listeners?
      existingFlight.manifest.from = this;
    }

    if (key == existingFlight.manifest.to.key) {
      _placeholderRect = existingFlight.manifest.to.placeholderRect;
      // TODO: should notify existing flight listeners?
      existingFlight.manifest.to = this;
    }

    _offstage = true;
  }

  void _setState(VoidCallback cb) {
    if (!mounted) return cb();
    setState(cb);
  }
}

class _FlightWidget extends StatefulWidget {
  final _Flight flight;
  const _FlightWidget({
    super.key,
    required this.flight,
  });

  @override
  State<_FlightWidget> createState() => _FlightWidgetState();
}

class _FlightWidgetState extends State<_FlightWidget> {
  Rect? fromRect;
  Rect? toRect;
  Rect curRect = Rect.zero;

  _Flight get flight => widget.flight;

  _Hero? get toHero => widget.flight.manifest.to;

  _Hero? get fromHero => widget.flight.manifest.from;

  @override
  void initState() {
    super.initState();
    flight.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    fromRect =
        fromRect ?? fromHero?.computeGlobalRect() ?? fromHero?.placeholderRect;

    return AnimatedBuilder(
      animation: flight.animation,
      builder: (context, child) {
        toRect = toHero?.computeGlobalRect() ?? toHero?.placeholderRect;
        curRect =
            toRect != null ? flight.evaluateRect(fromRect, toRect)! : curRect;

        return Transform.translate(
          offset: curRect.topLeft,
          child: SizedBox(
            width: curRect.width,
            height: curRect.height,
            child: IgnorePointer(
              child: child,
            ),
          ),
        );
      },
      child: flight.buildShuttle(context),
    );
  }
}

class _Flight extends ChangeNotifier {
  final _Switcher switcher;
  _FlightManifest _manifest;
  late final AnimationController _controller;
  late final Animation<double> animation;
  final RectTweenFactory _rectTweenFactory;
  final HeroHereFlightShuttleBuilder _shuttleBuilder;
  final StartAnimationCaller _forwardAnimation;
  final StartAnimationCaller _reverseAnimation;
  _Hero? _nextHero;
  bool _reversed = false;

  _Flight({
    required this.switcher,
    required _FlightManifest manifest,
  })  : _manifest = manifest,
        _rectTweenFactory = manifest.to.widget.rectTweenFactory ??
            manifest.from.widget.rectTweenFactory ??
            HeroHere.defaultFlightRectTweenFactory,
        _shuttleBuilder = manifest.to.widget.flightShuttleBuilder ??
            manifest.from.widget.flightShuttleBuilder ??
            HeroHere.defaultFlightShuttleBuilder,
        _forwardAnimation = manifest.to.widget.forwardFlightAnimation ??
            manifest.from.widget.forwardFlightAnimation ??
            HeroHere.defaultForwardFlightAnimation,
        _reverseAnimation = manifest.to.widget.reverseFlightAnimation ??
            manifest.from.widget.reverseFlightAnimation ??
            HeroHere.defaultReverseFlightAnimation {
    final animationDuration = _manifest.to.widget.flightAnimationDuration ??
        _manifest.from.widget.flightAnimationDuration ??
        HeroHere.defaultFlightAnimationDuration;
    final controllerFactory =
        _manifest.to.widget.flightAnimationControllerFactory ??
            _manifest.from.widget.flightAnimationControllerFactory ??
            HeroHere.defaultFlightAnimationControllerFactory;
    final animationFactory = _manifest.to.widget.flightAnimationFactory ??
        _manifest.from.widget.flightAnimationFactory ??
        HeroHere.defaultFlightAnimationFactory;

    _controller = controllerFactory(switcher, animationDuration);
    animation = animationFactory(_controller);
  }

  Object get tag => manifest.tag;

  _FlightManifest get manifest => _manifest;

  factory _Flight.start({
    required _Switcher switcher,
    required _FlightManifest manifest,
  }) {
    final flight = _Flight(
      switcher: switcher,
      manifest: manifest,
    );

    switcher.setSkyState(() => switcher.addFlight(flight));

    flight._forward().whenComplete(() {
      switcher.setSkyState(() => switcher.removeFlight(flight));
    });

    return flight;
  }

  void update(_FlightManifest manifest) {
    if (_shouldReverse(manifest)) {
      _manifest = manifest.reversed;
      notifyListeners();
      _reverse().whenComplete(() {
        switcher.setSkyState(() => switcher.removeFlight(this));
      });
    } else if (_shouldForward(manifest)) {
      _manifest = manifest;
      notifyListeners();
      _forward().whenComplete(() {
        switcher.setSkyState(() => switcher.removeFlight(this));
      });
    } else {
      _registerNextFlight(manifest.to);
    }
  }

  void abort() {
    _controller.stop(canceled: true);
    switcher.setSkyState(() => switcher.removeFlight(this));
  }

  Widget buildShuttle(BuildContext context) => _shuttleBuilder(
      context, animation, manifest.from.widget, manifest.to.widget);

  Rect? evaluateRect(Rect? begin, Rect? end) =>
      _rectTweenFactory(begin, end).evaluate(animation);

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

  Future<_Flight> _forward({
    double? from,
    Completer<_Flight>? completer,
  }) {
    completer ??= Completer();
    _reversed = false;
    _nextHero = null;
    _manifest.from.offstage = true;
    _manifest.to.offstage = true;

    _forwardAnimation(_controller, from: from).whenComplete(() {
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

    _reverseAnimation(_controller).whenComplete(() {
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

class _FlightManifest {
  final Object tag;
  _Hero from;
  _Hero to;

  _FlightManifest({
    required this.tag,
    required this.from,
    required this.to,
  });

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
