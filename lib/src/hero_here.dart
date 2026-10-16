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

import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

typedef _Hero = _HeroHereState;
typedef _Switcher = _HeroHereSwitcherState;

/// Lays out a [HeroHereSwitcher]'s `child` and its `sky`, the layer its
/// flights fly in. See [HeroHereSwitcher.layoutBuilder].
typedef HeroHereSwitcherLayoutBuilder = Widget Function(
  Widget child,
  Widget sky,
);

/// Makes the controller that drives a flight, from the flight's duration.
typedef HeroHereFlightAnimationControllerFactory = AnimationController Function(
  TickerProvider tickerProvider,
  Duration duration,
);

/// Makes the animation a flight runs on from its controller, such as a
/// [CurvedAnimation].
typedef HeroHereFlightAnimationFactory = Animation<double> Function(
  AnimationController controller,
);

/// Starts a flight's controller forward or in reverse, [from] a value if
/// given, and returns its ticker's future.
typedef HeroHereFlightAnimationStarter = TickerFuture Function(
  AnimationController controller, {
  double? from,
});

/// Makes the tween of the rect a flight's shuttle takes, from where its leg
/// [begin]s to where the hero it lands on is, its [end]. Once the flight
/// turns around, the rest of it takes a tween between where it turned and
/// where the hero it heads for is, backward if it heads back. It's called on
/// every frame of the flight with where that hero is on that frame, so the
/// shuttle follows the hero when it moves.
typedef HeroHereFlightRectTweenFactory = RectTween Function(
  Rect? begin,
  Rect? end,
);

typedef HeroHereFlightShuttleBuilder = Widget Function(
  BuildContext flightContext,
  Animation<double> animation,
  HeroHere fromHero,
  HeroHere toHero,
);

/// What a flight does when the hero it flies to changes while it flies, such
/// as when the switcher's child changes again mid-flight.
enum HeroHereFlightRedirect {
  /// Lands on the hero it flies to, then flies on to the new one. A flight
  /// sent back to the hero it left turns back from where it is, and takes as
  /// long as it flew.
  chain,

  /// Flies from where the shuttle is to the new hero, the hero it left too,
  /// over the flight's whole duration. The shuttle sets off at the speed it
  /// had, so it turns toward the new hero rather than stops, and swings
  /// around to a hero behind it rather than doubling back. Its `fromHero`
  /// becomes a stand-in for the shuttle as it was, with the key, tag and
  /// payload of the hero the flight left, so a shuttle that fades `fromHero`
  /// into `toHero` fades from what it showed.
  divert,
}

@Deprecated(
  'Use HeroHereFlightAnimationControllerFactory. '
  'This name will be removed in 2.0.0.',
)
typedef AnimationControllerFactory = HeroHereFlightAnimationControllerFactory;

@Deprecated(
  'Use HeroHereFlightAnimationFactory. This name will be removed in 2.0.0.',
)
typedef AnimationFactory<T> = Animation<T> Function(
  AnimationController controller,
);

@Deprecated(
  'Use HeroHereFlightAnimationStarter. This name will be removed in 2.0.0.',
)
typedef StartAnimationCaller = HeroHereFlightAnimationStarter;

@Deprecated(
  'Use HeroHereFlightRectTweenFactory. This name will be removed in 2.0.0.',
)
typedef RectTweenFactory = HeroHereFlightRectTweenFactory;

/// Flies [HeroHere] widgets between their places in [child] when [child]
/// changes.
///
/// Every rebuild of the switcher runs a switch, unless [switchKey] says
/// otherwise: it takes a snapshot of the current child, lays the new child
/// out offstage for a frame to find its heroes, then flies each tag whose
/// [HeroHere] changed. The new child shows two frames after the rebuild. The
/// first child shows on the first frame, and nothing flies. Keep frequently
/// changing state, such as timers, streams or text being typed, below the
/// switcher, so it rebuilds only when heroes may move.
///
/// The same goes for sizes. A [LayoutBuilder] or a `MediaQuery.sizeOf` read
/// above the switcher rebuilds it on each frame of a window resize, and each
/// of those switches shows a snapshot of the old layout for a frame. Read
/// sizes below the switcher instead, such as with a [LayoutBuilder] in its
/// child. Where state or sizes can't be read below it, set [switchKey].
class HeroHereSwitcher extends StatefulWidget {
  /// The widget whose heroes fly when it changes.
  final Widget? child;

  /// Lays out the switcher's [child] and its sky, the layer its flights fly
  /// in. Defaults to [defaultLayoutBuilder].
  ///
  /// Put the sky after the child in a [Stack], as the default does. The stack
  /// paints the sky over the child and lays it out after the child, so on
  /// each frame a flight finds its heroes where that frame's layout puts
  /// them. A sky laid out before the child, such as one before it in a stack
  /// that doesn't position it, places its shuttles by the layout of the frame
  /// before, so on a window resize they lag a frame behind their heroes.
  ///
  /// Shuttles fly where their heroes are on the screen, wherever the sky is.
  /// The sky takes the smallest size its constraints allow, so it doesn't
  /// size the switcher. To clip the flights to the switcher, give the sky the
  /// switcher's size:
  ///
  /// ```dart
  /// HeroHereSwitcher(
  ///   layoutBuilder: (child, sky) => Stack(
  ///     children: [child, Positioned.fill(child: ClipRect(child: sky))],
  ///   ),
  ///   child: child,
  /// )
  /// ```
  final HeroHereSwitcherLayoutBuilder layoutBuilder;

  /// Which rebuilds of the switcher run a switch. Unset, every rebuild does.
  /// Set, only a rebuild that changes it does, by `==`, so it may be a record
  /// of what the heroes' places depend on, such as `(tab, expandedId)`. A key
  /// set to null is unset.
  ///
  /// A rebuild that keeps the key shows its child at once, in place of the
  /// current one, as a rebuild below the switcher would. Nothing flies, so
  /// heroes it adds or moves show where they are, and a flight under way
  /// flies on, with its shuttle built anew from its heroes. A rebuild during
  /// a switch that keeps the key the switch runs to shows its child once the
  /// switch ends.
  final Object? switchKey;

  const HeroHereSwitcher({
    super.key,
    this.child,
    this.layoutBuilder = HeroHereSwitcher.defaultLayoutBuilder,
    this.switchKey,
  });

  @override
  State<HeroHereSwitcher> createState() => _HeroHereSwitcherState();

  /// Puts the sky over the child in a [Stack], in a [Material].
  static Widget defaultLayoutBuilder(Widget child, Widget sky) =>
      Material(child: Stack(children: [child, sky]));
}

class _HeroHereSwitcherState extends State<HeroHereSwitcher>
    with TickerProviderStateMixin {
  final _childKey = GlobalKey();
  late final flights = _FlightRegistry(this);
  late _SwitchingState _switchingState;
  Widget? _child;

  /// The [HeroHereSwitcher.switchKey] that [_child] came with.
  Object? _switchKey;

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

  /// The switcher's child. Flights work out their rects in its space, so the
  /// rects don't depend on where the switcher is on the screen, which may not
  /// be known yet when they do, such as when a window resize lays the
  /// switcher out anew and moves it.
  RenderBox? get childBox => _childKey.currentContext?.findRenderBox();

  /// The size of the switcher's child, which the rects kept from earlier
  /// frames move with, see [_KeptRect].
  Size? get childSize {
    final box = childBox;
    return box != null && box.hasSize ? box.size : null;
  }

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

  /// Takes the widget's child, with its switch key, as the one to show.
  void takeChild() {
    _child = widget.child;
    _switchKey = widget.switchKey;
  }

  /// Whether the widget's child shows by a switch rather than in place of the
  /// current one, as it does unless its switch key is set and is the current
  /// child's.
  bool get switchesChild =>
      widget.switchKey == null || widget.switchKey != _switchKey;

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
  //
  // The sky takes the smallest size it may, with flights or without, so it
  // doesn't size the switcher: in a Center, an empty stack would fill the
  // screen until a flight starts. The relayout boundary also keeps the
  // flights' layouts on each frame inside the sky.
  Widget _buildSky() => RepaintBoundary(
    child: _RelayoutBoundary(
      child: Stack(
        children: [
          ...flights.all.map(
            (flight) =>
                _FlightWidget(key: ValueKey(flight.tag), flight: flight),
          ),
        ],
      ),
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
/// entering the next one. A build of the switcher runs a switch, unless its
/// switch key says its child shows in place: from [_Idle] it enters
/// [_Prepare], and a build during a switch is taken up by that switch, or by
/// the next one if its child arrived too late.
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
  void onBuild() => switcher.takeChild();

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
  void onBuild() {
    if (switcher.switchesChild) {
      switcher.enter(_Prepare(switcher, prevSwitchHeroes: prevSwitchHeroes));
    } else {
      switcher.takeChild();
    }
  }
}

/// Snapshots the current child and lays the new one out offstage. Holds the
/// flights' landings from the snapshot until the switch runs. Builds while
/// it waits need nothing: it takes the newest child.
class _Prepare extends _SwitchingState {
  _Prepare(super.switcher, {super.prevSwitchHeroes});

  @override
  void enter() => afterFrame(_prepareSwitch);

  void _prepareSwitch() {
    final curHeroes = switcher.findHeroes();

    notifyWillSwitch(curHeroes);
    switcher.flights.holdLandings();

    switcher.setChildState(() {
      switcher._childScreenshot = switcher.takeChildScreenshot(
        pixelRatio: MediaQuery.devicePixelRatioOf(switcher.context),
      );
      switcher.takeChild();
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
/// waits gets a switch of its own after this one, or shows in place once
/// this one ends.
class _Execute extends _SwitchingState {
  final Set<_Hero> curHeroes;

  _Execute(super.switcher, {super.prevSwitchHeroes, required this.curHeroes});

  @override
  void enter() => afterFrame(_switch);

  void _switch() {
    switcher.flights.releaseLandings();

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

      // A build that brought a child or a key this switch didn't take runs
      // another switch, unless its child shows in place.
      final rebuilt =
          !identical(switcher._child, switcher.widget.child) ||
          switcher._switchKey != switcher.widget.switchKey;
      if (rebuilt && switcher.switchesChild) {
        switcher.enter(_Prepare(switcher, prevSwitchHeroes: nextHeroes));
      } else {
        switcher.takeChild();
        switcher.enter(_Idle(switcher, prevSwitchHeroes: nextHeroes));
      }
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
  /// switch. With neither, nothing flies: the last one shows at once, as on
  /// mount.
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
            manifest.to;
      }
    }

    // A flight under way goes on while a next hero has its tag, even when it
    // flies back to the hero it left, as a diverted flight may.
    return _SwitchPlan._(
      {
        for (final manifest in manifests.values)
          if (!manifest.isIdle || flying.containsKey(manifest.tag))
            manifest.tag: manifest,
      },
      {
        for (final tag in flying.keys)
          if (!manifests.containsKey(tag)) tag,
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
  static const defaultFlightRedirect = HeroHereFlightRedirect.chain;

  final Object tag;
  final Widget child;
  final Duration? flightAnimationDuration;
  final HeroHereFlightAnimationControllerFactory?
  flightAnimationControllerFactory;
  final HeroHereFlightAnimationFactory? flightAnimationFactory;
  final HeroHereFlightAnimationStarter? forwardFlightAnimation;
  final HeroHereFlightAnimationStarter? reverseFlightAnimation;
  final HeroHereFlightShuttleBuilder? flightShuttleBuilder;
  final HeroHereFlightRectTweenFactory? rectTweenFactory;

  /// What a flight does when the hero it flies to changes mid-flight, or
  /// [defaultFlightRedirect] when neither the hero it lands on nor the one it
  /// leaves says. Like the other flight options, it's taken when the flight
  /// starts.
  final HeroHereFlightRedirect? flightRedirect;
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
    this.flightRedirect,
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

  /// Where the hero was at the last switch, as it would be in the
  /// switcher's child now.
  Rect? get placeholderRect => _placeholder?.within(_switcher?.childSize);

  @override
  void initState() {
    super.initState();

    _switcher = context.findAncestorStateOfType<_Switcher>();

    // A hero mounted while its tag flies hides. If it mounts anew a hero of
    // the flight, it takes over that hero's part and placeholder; any other
    // hero shows when the flight ends.
    final flight = _switcher?.flights[tag];
    if (flight != null) {
      _placeholder = flight.adopt(this)?._placeholder;
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

  void willSwitch() {
    final rect = computeRect();
    _placeholder = rect == null ? null : _KeptRect(rect, _switcher?.childSize);
  }

  /// Where the hero is in the switcher's child.
  Rect? computeRect() {
    final space = _switcher?.childBox;
    if (!_active || space == null) return null;
    return _childKey.currentContext?.findRenderBox()?.rectIn(space);
  }

  @override
  Widget build(BuildContext context) => _HeroOffstage(
    offstage: offstage,
    child: _Hide(
      hides: _hides,
      changes: _hiding,
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

  @override
  void dispose() {
    _hiding.dispose();
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
  final Listenable changes;

  const _Hide({required this.hides, required this.changes, super.child});

  @override
  _RenderHide createRenderObject(BuildContext context) =>
      _RenderHide(hides, changes);

  @override
  void updateRenderObject(BuildContext context, _RenderHide renderObject) =>
      renderObject.hides = hides;
}

class _RenderHide extends RenderProxyBox {
  bool Function() hides;
  final Listenable changes;

  _RenderHide(this.hides, this.changes);

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    changes.addListener(_changed);
  }

  @override
  void detach() {
    changes.removeListener(_changed);
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
          child: IgnorePointer(child: RepaintBoundary(child: flight.shuttle)),
        ),
      ),
    ),
  );
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

/// Lays its child out with its own constraints and takes the smallest size
/// they allow, so a layout below it, such as a flight's on each frame, lays
/// out nothing above it.
class _RelayoutBoundary extends SingleChildRenderObjectWidget {
  const _RelayoutBoundary({super.child});

  @override
  _RenderRelayoutBoundary createRenderObject(BuildContext context) =>
      _RenderRelayoutBoundary();
}

class _RenderRelayoutBoundary extends RenderProxyBox {
  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      constraints.smallest;

  // Its size doesn't depend on its child, so it doesn't ask its child, which
  // a layout builder couldn't answer, such as in an IntrinsicHeight.
  @override
  double computeMinIntrinsicWidth(double height) => 0;

  @override
  double computeMaxIntrinsicWidth(double height) => 0;

  @override
  double computeMinIntrinsicHeight(double width) => 0;

  @override
  double computeMaxIntrinsicHeight(double width) => 0;

  @override
  double? computeDryBaseline(
    covariant BoxConstraints constraints,
    TextBaseline baseline,
  ) => null;

  @override
  void performLayout() {
    child?.layout(constraints);
  }
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

  /// Where the shuttle was when its leg began.
  _KeptRect? _legBegin;

  /// Whether the leg began on the hero the flight leaves, so it begins
  /// wherever that hero is on each frame, while it's anywhere, rather than at
  /// [_legBegin].
  bool _legBeginsOnHero = true;

  Rect? _rect;

  /// The controller's elapsed time, and the values of the flight's animation
  /// and of its controller, when the shuttle was at [_rect].
  ({Duration elapsed, double value, double t})? _rectFrame;

  /// How fast each of the shuttle's edges moves along its leg's path, in
  /// logical pixels a second, as of its last frame.
  Rect _velocity = Rect.zero;

  /// The shuttle's [_velocity] when the flight last diverted.
  Rect _divertVelocity = Rect.zero;

  /// Where the shuttle was when the flight last turned around on its leg,
  /// and the value of the flight's animation then. The leg goes on from
  /// there.
  ({_KeptRect rect, double value})? _turn;

  /// How fast, and which way, the shuttle swings out to the side when the
  /// flight diverts to a hero behind it, in logical pixels a second, so it
  /// comes around to that hero rather than doubling back.
  Offset _divertSwing = Offset.zero;

  /// What the shuttle shows as the hero it leaves once the flight diverts:
  /// the shuttle as it was then.
  HeroHere? _divertedFrom;

  /// The shuttle as last made, by [shuttle].
  _Shuttle? _shuttle;

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
      _turnHere();
      notifyListeners();
      _reverse();
    } else if (_shouldForward(manifest)) {
      _manifest = manifest;
      _turnHere();
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
  Rect evaluateRect() {
    final size = _registry.switcher.childSize;
    final end = _manifest.to.computeRect() ?? _manifest.to.placeholderRect;
    if (end != null) {
      final value = animation.value;
      final t = _controller.value;
      _rect = _onPath(value, t, end, size);

      // How fast the shuttle moves along the path as it is now, so heroes
      // that move, such as on a window resize, don't count. The elapsed time
      // starts over with each leg.
      final last = _rectFrame;
      final elapsed = _controller.lastElapsedDuration;
      if (last != null && elapsed != null && elapsed > last.elapsed) {
        _velocity = _rect!
            .minus(_onPath(last.value, last.t, end, size))
            .times(1 / (elapsed - last.elapsed).seconds);
      }
      _rectFrame = elapsed == null
          ? null
          : (elapsed: elapsed, value: value, t: t);
    }
    return _rect ?? Rect.zero;
  }

  /// Where the shuttle is on its leg's path at [value] of the flight's
  /// animation and [t] of its controller, given [end], where the hero it
  /// lands on is, and [size], the size of the switcher's child. The path runs
  /// from where the leg began to [end]. Once the flight turns around, the
  /// rest of it runs from where it turned to where the hero it heads for is,
  /// so it lands on that hero even if it moved, such as on a window resize.
  Rect _onPath(double value, double t, Rect end, Size? size) {
    final tween = _style.rectTweenFactory;
    final turn = _turn;
    final Rect rect;
    if (turn == null) {
      rect = tween(_legBeginOn(size), end).transform(value)!;
    } else if (_reversed) {
      final turnRect = turn.rect.within(size);
      final begin =
          _manifest.from.computeRect() ??
          _manifest.from.placeholderRect ??
          turnRect;
      rect = turn.value == 0
          ? begin
          : tween(begin, turnRect).transform(value / turn.value)!;
    } else {
      rect = turn.value == 1
          ? end
          : tween(
              turn.rect.within(size),
              end,
            ).transform((value - turn.value) / (1 - turn.value))!;
    }
    return rect.plus(_momentum(t));
  }

  /// Where the leg begins, with the switcher's child of [size]: where the
  /// hero the flight leaves is now, if the leg began on it, or else where the
  /// shuttle was when the leg began.
  Rect? _legBeginOn(Size? size) =>
      (_legBeginsOnHero
          ? _manifest.from.computeRect() ?? _manifest.from.placeholderRect
          : null) ??
      _legBegin?.within(size);

  /// How far the shuttle is off its leg's path at [t] of the controller, for
  /// the speed it had when the flight diverted. It sets off at that speed, so
  /// it turns rather than stops, and loses it on its way.
  Rect _momentum(double t) {
    final seconds = (_controller.duration ?? _style.duration).seconds;
    final fade = t * (1 - t) * (1 - t) * (1 - t);
    // The swing sets in after the shuttle sets off, and fades out before it
    // lands.
    final swing = 3 * t * fade;
    return _divertVelocity
        .times(seconds * fade)
        .shift(_divertSwing * (seconds * swing));
  }

  /// How the shuttle swings out on its way to [hero]: toward the side [hero]
  /// is on, as hard as it moves, and the more so the more [hero] is behind
  /// it. A hero ahead of it or to its side needs no swing, since the speed
  /// the shuttle carries on at already curves its path.
  Offset _swingToward(_Hero hero) {
    final from = _rect;
    final to = hero.computeRect() ?? hero.placeholderRect;
    final velocity = _divertVelocity.center;
    if (from == null || to == null || velocity == Offset.zero) {
      return Offset.zero;
    }
    final toward = to.center - from.center;
    if (toward == Offset.zero) return Offset.zero;

    final cos =
        (velocity.dx * toward.dx + velocity.dy * toward.dy) /
        (velocity.distance * toward.distance);
    final behind = (-cos).clamp(0.0, 1.0);
    final cross = velocity.dx * toward.dy - velocity.dy * toward.dx;
    final side = Offset(-velocity.dy, velocity.dx) * (cross < 0 ? -1 : 1);
    return side * behind;
  }

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
    _divertVelocity = _velocity;
    _divertSwing = _swingToward(hero);
    _beginLeg(_rect, onHero: false);
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

  /// Starts a new leg where the shuttle is, at [begin], and, [onHero], on the
  /// hero the flight leaves.
  void _beginLeg(Rect? begin, {required bool onHero}) {
    _legBegin = _keep(begin);
    _legBeginsOnHero = onHero;
    _turn = null;
    _rectFrame = null;
  }

  /// Turns the flight around where the shuttle is.
  void _turnHere() {
    final rect = _keep(_rect);
    _turn = rect == null ? null : (rect: rect, value: animation.value);
  }

  /// [rect], kept with the size the switcher's child has now.
  _KeptRect? _keep(Rect? rect) =>
      rect == null ? null : _KeptRect(rect, _registry.switcher.childSize);

  void _forward({double? from}) {
    _reversed = false;
    _nextHero = null;
    _manifest.from.offstage = true;
    _manifest.to.offstage = true;

    final run = ++_runs;
    _style
        .forwardAnimation(_controller, from: from)
        .whenComplete(() => _registry.land(() => _landForward(run)));
  }

  void _landForward(int run) {
    if (run != _runs) return;

    if (_nextHero != null) {
      // The next leg starts on the hero the shuttle landed on.
      _beginLeg(_rect, onHero: true);
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
    _style
        .reverseAnimation(_controller)
        .whenComplete(() => _registry.land(() => _landBack(run)));
  }

  void _landBack(int run) {
    if (run != _runs) return;

    if (_nextHero != null) {
      // The next leg starts on the hero the shuttle landed back on.
      _beginLeg(_rect, onHero: true);
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

  /// The landings that wait for the switch under way to run.
  List<VoidCallback>? _heldLandings;

  /// Holds the flights' landings until [releaseLandings]. A switch's
  /// snapshot shows the heroes the flights land on hidden, so a flight that
  /// lands while it shows keeps its shuttle there instead.
  void holdLandings() => _heldLandings ??= [];

  /// Lands the flights that landed since [holdLandings].
  void releaseLandings() {
    final held = _heldLandings;
    _heldLandings = null;
    for (final land in held ?? const <VoidCallback>[]) {
      land();
    }
  }

  /// Runs [landing] now, or on [releaseLandings] while landings are held.
  void land(VoidCallback landing) {
    final held = _heldLandings;
    held == null ? landing() : held.add(landing);
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

/// A rect in the switcher's child kept from an earlier frame, with the size
/// the child had then. When the child changes size, such as on a window
/// resize, the rect keeps
/// its size, and its place in the room the child has around it, as an
/// [Align] keeps a child's: as far across that room, in proportion. So a rect
/// at an edge stays there, and one in the middle stays in the middle. A rect
/// outside that room, such as a hero's that was scrolled away, keeps its
/// distance from it, so it stays outside.
class _KeptRect {
  final Rect rect;

  /// The size of the switcher's child when the rect was kept.
  final Size? size;

  const _KeptRect(this.rect, this.size);

  /// The rect, with the switcher's child of size [now].
  Rect within(Size? now) {
    final then = size;
    if (then == null || now == null || now == then) return rect;
    return Rect.fromLTWH(
      _place(rect.left, then.width - rect.width, now.width - rect.width),
      _place(rect.top, then.height - rect.height, now.height - rect.height),
      rect.width,
      rect.height,
    );
  }

  /// Where a rect [offset] from the child's start goes along an axis, given
  /// the room the child had around it, [room], and has now, [nowRoom].
  static double _place(double offset, double room, double nowRoom) {
    if (offset <= 0) return offset;
    if (offset >= room) return nowRoom + (offset - room);
    return offset / room * nowRoom;
  }
}

/// Rects as the four numbers of their edges, such as the edges' speeds.
extension _RectEdges on Rect {
  Rect plus(Rect other) => Rect.fromLTRB(
    left + other.left,
    top + other.top,
    right + other.right,
    bottom + other.bottom,
  );

  Rect minus(Rect other) => plus(other.times(-1));

  Rect times(double factor) => Rect.fromLTRB(
    left * factor,
    top * factor,
    right * factor,
    bottom * factor,
  );
}

extension _Seconds on Duration {
  double get seconds => inMicroseconds / Duration.microsecondsPerSecond;
}

extension _RenderBox on RenderBox {
  /// Where this box is in [ancestor]'s space.
  Rect? rectIn(RenderObject ancestor) {
    if (!hasSize) return null;
    return localToGlobal(Offset.zero, ancestor: ancestor) & size;
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
      element.visitChildren(findHeroes);
    }

    // Unlike visitChildElements, visitChildren may run while the tree builds
    // or lays out, such as from a layout callback.
    (this as Element).visitChildren(findHeroes);

    return result;
  }
}
