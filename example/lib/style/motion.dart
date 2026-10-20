// Copyright 2026 Igor Kurilenko
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

// Springs for flights, which carry a hero a little past its place and back
// as it lands. A hero takes one through four of its options:
//
//   flightAnimationControllerFactory: softSpring.controller,
//   flightAnimationFactory: softSpring.animation,
//   forwardFlightAnimation: softSpring.forward,
//   reverseFlightAnimation: softSpring.reverse,

import 'package:flutter/animation.dart';
import 'package:flutter/physics.dart';

/// A soft spring: it settles in about half a second, with a little bounce.
final softSpring = FlightSpring(
  SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 500),
    bounce: .25,
  ),
);

/// A bouncy spring, as heroine's default motion, `CupertinoMotion.bouncy()`.
final bouncySpring = FlightSpring(
  SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 500),
    bounce: .3,
  ),
);

/// A spring that drives a hero's flight, in place of its curve.
class FlightSpring {
  FlightSpring(this.description);

  /// The spring's mass, stiffness and damping.
  final SpringDescription description;

  /// An unbounded controller, so the spring can carry a flight past its end
  /// and back.
  AnimationController controller(TickerProvider vsync, Duration _) =>
      AnimationController.unbounded(vsync: vsync);

  /// The spring is the curve.
  Animation<double> animation(AnimationController controller) => controller;

  /// Springs a flight to its end.
  TickerFuture forward(AnimationController controller, {double? from}) =>
      controller.animateWith(_to(1, controller, from: from));

  /// Springs a flight back to its start, as when it's sent back mid-flight.
  /// The default, `controller.reverse()`, needs a controller with bounds.
  TickerFuture reverse(AnimationController controller, {double? from}) =>
      controller.animateBackWith(_to(0, controller, from: from));

  /// Springs [controller] to [end], from [from] or else from where it is, at
  /// the speed it has, so a flight sent back mid-flight swings round rather
  /// than stops.
  SpringSimulation _to(
    double end,
    AnimationController controller, {
    double? from,
  }) => SpringSimulation(
    description,
    from ?? controller.value,
    end,
    controller.velocity,
    // Lands once the hero looks still, rather than when the spring comes
    // fully to rest, a while later, so what waits for the landing, such as
    // the flip card's taps, doesn't lag behind what shows.
    tolerance: const Tolerance(distance: .005, velocity: .05),
  );
}
