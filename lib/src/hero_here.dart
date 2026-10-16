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
  /// switcher. Its `fromHero`
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

/// A [child] that flies, when a [HeroHereSwitcher]'s child changes, from
/// where the hero with its [tag] was to where it is now.
///
/// It paints [child] into a layer of its own, which a switch shows where the
/// hero was, as it last showed, for the frame after the hero goes away,
/// before its flight starts.
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
