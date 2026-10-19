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
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

part 'switcher.dart';
part 'hero.dart';
part 'stand_in.dart';
part 'flight.dart';
part 'flight_path.dart';
part 'layout.dart';

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

/// Builds a flight's shuttle, what it shows as it flies, from [animation],
/// which runs from 0 at the hero the flight leaves, [fromHero], to 1 at the
/// hero it flies to, [toHero]. A flight that turns back runs it in reverse,
/// with the same two heroes. [flightContext] is the flight's context in the
/// switcher's sky.
///
/// It's called when the flight starts, and again whenever its heroes change,
/// such as on the next leg of a chain or when a rebuild gives one of them a
/// new widget, but not on each frame.
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
  /// around to a hero behind it rather than doubling back. Near the
  /// switcher's edge, it slides along the edge rather than out of the
  /// switcher. Its `fromHero` becomes a stand-in for the shuttle as it was,
  /// with the key, tag and payload of the hero the flight left, so a shuttle
  /// that fades `fromHero` into `toHero` fades from what it showed.
  divert,
}

/// Flies [HeroHere] widgets between their places in [child] when [child]
/// changes.
///
/// Every rebuild of the switcher runs a switch, unless [switchKey] says
/// otherwise. The new child shows on the frame of the rebuild. On that frame,
/// its heroes of the tags that may fly hide, the heroes that stay show as
/// they are, and each hero that went away shows where it was, as it last
/// showed, with the clips, fades and transforms around it. After that frame,
/// once the new child is laid out, the switch flies each tag whose [HeroHere]
/// changed, from where its hero showed. The first child shows on the first
/// frame, and nothing flies.
///
/// A rebuild builds the switcher's child anew, and its switch looks for the
/// heroes in it, so keep frequently changing state, such as timers, streams
/// or text being typed, below the switcher, so it rebuilds only when heroes
/// may move. Where such state, or sizes, such as from a [LayoutBuilder] or a
/// `MediaQuery.sizeOf`, can't be read below it, set [switchKey].
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
  /// flies on, with its shuttle built anew from its heroes.
  final Object? switchKey;

  /// Creates a switcher that flies the heroes in [child] when it changes.
  const HeroHereSwitcher({
    super.key,
    this.child,
    this.layoutBuilder = HeroHereSwitcher.defaultLayoutBuilder,
    this.switchKey,
  });

  @override
  State<HeroHereSwitcher> createState() => _HeroHereSwitcherState();

  /// Puts the sky over the child in a [Stack], in a transparent [Material].
  ///
  /// The material gives the child and the shuttles a default text style and
  /// a surface for ink, and the switcher takes the taps that land on neither,
  /// as a material would. It paints no background, so what's behind the
  /// switcher, such as a [Scaffold]'s, shows through.
  static Widget defaultLayoutBuilder(Widget child, Widget sky) => Material(
    type: MaterialType.transparency,
    child: MetaData(
      behavior: HitTestBehavior.opaque,
      child: Stack(children: [child, sky]),
    ),
  );
}

/// A [child] that flies, when a [HeroHereSwitcher]'s child changes, from
/// where the hero with its [tag] was to where it is now.
///
/// It paints [child] into a layer of its own, which a switch shows where the
/// hero was, as it last showed, for the frame after the hero goes away,
/// before its flight starts.
///
/// A flight takes each of its options, such as [flightAnimationDuration] or
/// [flightShuttleBuilder], from the hero it flies to, or else from the hero
/// it leaves, or else the default, once, when it starts. A flight that
/// changes course keeps them.
///
/// A hero under a disabled [HeroMode] in the switcher's child takes no part
/// in the switches that find it there: they send no flight to it, and hide
/// it neither behind a later hero of its tag nor for a flight, so it shows
/// as it is. A flight under way may still land on it. A hero mode that
/// changes takes effect at the next switch.
class HeroHere extends StatefulWidget {
  /// The curve of [defaultFlightAnimationFactory]'s animation.
  static const defaultFlightAnimationCurve = Curves.easeInOut;

  /// How long a flight takes when neither of its heroes sets
  /// [flightAnimationDuration].
  static const defaultFlightAnimationDuration = Duration(milliseconds: 300);

  /// What a flight does when the hero it flies to changes mid-flight, if
  /// neither of its heroes sets [flightRedirect].
  static const defaultFlightRedirect = HeroHereFlightRedirect.chain;

  /// What the hero flies by. When a switch brings a hero with this tag and
  /// another key, it flies from where the hero with this tag was.
  ///
  /// Of the heroes with one tag in the switcher's child, only the last shows.
  /// The others hide, keeping their space.
  final Object tag;

  /// What the hero shows. The default shuttle shows the child of the hero a
  /// flight flies to.
  final Widget child;

  /// How long a flight takes. Defaults to [defaultFlightAnimationDuration].
  final Duration? flightAnimationDuration;

  /// Makes the controller that drives a flight, from the flight's duration.
  /// Defaults to [defaultFlightAnimationControllerFactory].
  final HeroHereFlightAnimationControllerFactory?
  flightAnimationControllerFactory;

  /// Makes the animation a flight runs on, from its controller. Defaults to
  /// [defaultFlightAnimationFactory], which curves it by
  /// [defaultFlightAnimationCurve].
  final HeroHereFlightAnimationFactory? flightAnimationFactory;

  /// Starts a flight's controller forward: when the flight starts, from 0 on
  /// each leg after that, and from where it is when the flight turns around
  /// again toward the hero it flies to. The flight lands once the future it
  /// returns completes. It may drive the controller as it likes, such as
  /// with `controller.fling(velocity: velocity)` to land a drag at its speed.
  /// Defaults to [defaultForwardFlightAnimation].
  final HeroHereFlightAnimationStarter? forwardFlightAnimation;

  /// Starts a flight's controller in reverse, when the flight turns back to
  /// the hero it left, as a [HeroHereFlightRedirect.chain] flight does. The
  /// flight lands back on that hero once the future it returns completes.
  /// Defaults to [defaultReverseFlightAnimation].
  final HeroHereFlightAnimationStarter? reverseFlightAnimation;

  /// Builds what a flight shows as it flies. Defaults to
  /// [defaultFlightShuttleBuilder], which shows the child of the hero the
  /// flight flies to.
  final HeroHereFlightShuttleBuilder? flightShuttleBuilder;

  /// Makes the tween of the rect a flight's shuttle takes. Defaults to
  /// [defaultFlightRectTweenFactory].
  final HeroHereFlightRectTweenFactory? rectTweenFactory;

  /// What a flight does when the hero it flies to changes mid-flight, or
  /// [defaultFlightRedirect] when neither the hero it lands on nor the one it
  /// leaves says. Like the other flight options, it's taken when the flight
  /// starts.
  final HeroHereFlightRedirect? flightRedirect;

  /// Anything a [flightShuttleBuilder] needs to know about the hero, which it
  /// reads from `fromHero` and `toHero`, such as each hero's corner radius to
  /// tween between. A flight that diverts keeps the payload of the hero it
  /// left on the stand-in it shows for it.
  final Object? payload;

  /// Creates a hero with [tag] that shows [child].
  ///
  /// Its `key` tells a switch whether it's the hero with its tag that was
  /// there before. A hero with another key flies from where that one was. One
  /// with the same key is the same hero, and shows where it is now, with
  /// nothing flying, even when it moved.
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

  /// Makes an [AnimationController] of [duration] that ticks with
  /// [tickerProvider].
  static AnimationController defaultFlightAnimationControllerFactory(
    TickerProvider tickerProvider,
    Duration duration,
  ) => AnimationController(vsync: tickerProvider, duration: duration);

  /// Curves [controller] by [defaultFlightAnimationCurve].
  static Animation<double> defaultFlightAnimationFactory(
    AnimationController controller,
  ) => CurvedAnimation(parent: controller, curve: defaultFlightAnimationCurve);

  /// Runs [controller] forward, [from] a value if given.
  static TickerFuture defaultForwardFlightAnimation(
    AnimationController controller, {
    double? from,
  }) => controller.forward(from: from);

  /// Runs [controller] in reverse, [from] a value if given.
  static TickerFuture defaultReverseFlightAnimation(
    AnimationController controller, {
    double? from,
  }) => controller.reverse(from: from);

  /// A [RectTween] from [begin] to [end], which moves the shuttle's
  /// corners along straight lines.
  static RectTween defaultFlightRectTweenFactory(Rect? begin, Rect? end) =>
      RectTween(begin: begin, end: end);

  /// Shows the child of the hero the flight flies to, [toHero].
  static Widget defaultFlightShuttleBuilder(
    BuildContext flightContext,
    Animation<double> animation,
    HeroHere fromHero,
    HeroHere toHero,
  ) => toHero.child;
}
