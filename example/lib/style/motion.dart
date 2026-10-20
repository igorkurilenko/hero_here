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

// A soft spring for flights, which carries a hero a little past its place
// and back as it lands. A hero takes it through four of its options:
//
//   flightAnimationControllerFactory: softSpringController,
//   flightAnimationFactory: softSpringAnimation,
//   forwardFlightAnimation: softSpringForward,
//   reverseFlightAnimation: softSpringReverse,

import 'package:flutter/animation.dart';
import 'package:flutter/physics.dart';

/// A soft spring: it settles in about half a second, with a little bounce.
final _softSpring = SpringDescription.withDurationAndBounce(
  duration: const Duration(milliseconds: 500),
  bounce: .25,
);

/// An unbounded controller, so the spring can carry a flight past its end
/// and back.
AnimationController softSpringController(
  TickerProvider tickerProvider,
  Duration _,
) => AnimationController.unbounded(vsync: tickerProvider);

/// The spring is the curve.
Animation<double> softSpringAnimation(AnimationController controller) =>
    controller;

/// Springs a flight to its end.
TickerFuture softSpringForward(
  AnimationController controller, {
  double? from,
}) => controller.animateWith(_springTo(1, controller, from: from));

/// Springs a flight back to its start, as when it's sent back mid-flight.
TickerFuture softSpringReverse(
  AnimationController controller, {
  double? from,
}) => controller.animateBackWith(_springTo(0, controller, from: from));

/// Springs [controller] to [end], from [from] or else from where it is, at
/// the speed it has, so a flight sent back mid-flight swings round rather
/// than stops.
SpringSimulation _springTo(
  double end,
  AnimationController controller, {
  double? from,
}) => SpringSimulation(
  _softSpring,
  from ?? controller.value,
  end,
  controller.velocity,
  // Lands once the hero looks still, rather than when the spring comes fully
  // to rest, a while later.
  tolerance: const Tolerance(distance: .005, velocity: .05),
);
