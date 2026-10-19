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

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../hero_here.dart';

part 'crossfade.dart';
part 'flip.dart';

/// Ready-made builders of what a flight shows as it flies, for
/// [HeroHere.flightShuttleBuilder].
///
/// Each shuttle follows the flight's animation itself, as a shuttle has to: a
/// flight builds its shuttle once per leg, not on each frame.
abstract final class HeroHereShuttles {
  /// Fades the hero a flight leaves out over the hero it flies to: the child
  /// of `fromHero` fades out as the flight goes, over the child of `toHero`.
  /// A flight that turns back fades it in again.
  static HeroHereFlightShuttleBuilder crossfade() => _crossfade;

  /// Turns the shuttle over as it flies, like a card, about [axis]: the
  /// vertical axis by default, so it turns from side to side, or the
  /// horizontal one, so it turns top over bottom. It shows the child of the
  /// hero the flight leaves until it's edge on, halfway, then the child of
  /// the hero it flies to, mirrored, so it reads the right way round once
  /// turned over.
  ///
  /// A flight that runs past its end, as on a spring that overshoots, turns
  /// it past its place and back.
  static HeroHereFlightShuttleBuilder flip({Axis axis = Axis.vertical}) =>
      _flip(axis);
}
