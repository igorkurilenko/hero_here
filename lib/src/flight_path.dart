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

/// Where a flight's shuttle is on each frame: on its leg's path, from where
/// the leg began to where the hero it lands on is, and off that path by the
/// speed it had when the flight last diverted.
///
/// The flight tells it where its heroes are and how far its animation is,
/// and when a leg begins, turns around or diverts.
class _FlightPath {
  final HeroHereFlightRectTweenFactory _tween;

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

  _FlightPath(this._tween);

  /// Works out where the shuttle is on this frame, at [value] of the
  /// flight's animation and [t] of its controller, which has run for
  /// [elapsed] of a run of [duration]: on its way from where its leg began
  /// to [end], where the hero it flies to is. While that hero is nowhere, the
  /// shuttle stays where it was.
  ///
  /// [from] tells where the hero the flight leaves is, [reversed] whether
  /// the flight flies back to it, and [size] is the size of the switcher's
  /// child.
  Rect evaluate({
    required Rect? end,
    required Rect? Function() from,
    required bool reversed,
    required double value,
    required double t,
    required Duration? elapsed,
    required Duration duration,
    required Size? size,
  }) {
    if (end != null) {
      // Both paths below take the hero the flight leaves where it is on
      // this frame, so it's measured once, and only if a path needs it.
      var fromRead = false;
      Rect? fromRect;
      Rect? fromOnce() {
        if (!fromRead) {
          fromRect = from();
          fromRead = true;
        }
        return fromRect;
      }

      Rect onPath(double value, double t) => _onPath(
        value,
        t,
        end: end,
        from: fromOnce,
        reversed: reversed,
        duration: duration,
        size: size,
      );
      _rect = onPath(value, t);

      // How fast the shuttle moves along the path as it is now, so heroes
      // that move, such as on a window resize, don't count. The elapsed time
      // starts over with each leg.
      final last = _rectFrame;
      if (last != null && elapsed != null && elapsed > last.elapsed) {
        _velocity = _rect!
            .minus(onPath(last.value, last.t))
            .times(1 / (elapsed - last.elapsed).seconds);
      }
      _rectFrame = elapsed == null
          ? null
          : (elapsed: elapsed, value: value, t: t);
    }
    return _rect ?? Rect.zero;
  }

  /// Starts a new leg where the shuttle is and, [onHero], on the hero the
  /// flight leaves, with the switcher's child of [size].
  void beginLeg({required bool onHero, required Size? size}) {
    _legBegin = _keep(_rect, size);
    _legBeginsOnHero = onHero;
    _turn = null;
    _rectFrame = null;
  }

  /// Turns the flight around where the shuttle is, at [value] of the
  /// flight's animation, with the switcher's child of [size].
  void turnHere({required double value, required Size? size}) {
    final rect = _keep(_rect, size);
    _turn = rect == null ? null : (rect: rect, value: value);
  }

  /// Starts a leg from where the shuttle is, at the speed it has, to [to],
  /// where the hero the flight diverts to is, with the switcher's child of
  /// [size].
  void divert({required Rect? to, required Size? size}) {
    _divertVelocity = _velocity;
    _divertSwing = _swingToward(to);
    beginLeg(onHero: false, size: size);
  }

  /// Where the shuttle is on its leg's path at [value] of the flight's
  /// animation and [t] of its controller, given [end], where the hero it
  /// lands on is, and [size], the size of the switcher's child. The path runs
  /// from where the leg began to [end]. Once the flight turns around, the
  /// rest of it runs from where it turned to where the hero it heads for is,
  /// so it lands on that hero even if it moved, such as on a window resize.
  Rect _onPath(
    double value,
    double t, {
    required Rect end,
    required Rect? Function() from,
    required bool reversed,
    required Duration duration,
    required Size? size,
  }) {
    final tween = _tween;
    final turn = _turn;
    final Rect rect;
    if (turn == null) {
      rect = tween(_legBeginOn(from, size), end).transform(value)!;
    } else if (reversed) {
      final turnRect = turn.rect.within(size);
      final begin = from() ?? turnRect;
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
    return _carried(rect, _momentum(t, duration), size);
  }

  /// [path] carried by [momentum], as far as that keeps it inside the
  /// switcher's child of [size] on each axis where [path] is inside it. So a
  /// shuttle that carries on or swings near an edge slides along it rather
  /// than out of the switcher, while one whose path is outside, such as from
  /// a hero scrolled away, carries on as it would.
  static Rect _carried(Rect path, Rect momentum, Size? size) {
    if (size == null) return path.plus(momentum);
    // The share of a push of an edge toward a side that keeps it on the side
    // it has room on.
    double share(double room, double push) =>
        room < 0 || push <= room ? 1 : room / push;
    final across = math.min(
      share(path.left, -momentum.left),
      share(size.width - path.right, momentum.right),
    );
    final down = math.min(
      share(path.top, -momentum.top),
      share(size.height - path.bottom, momentum.bottom),
    );
    return path.plus(
      Rect.fromLTRB(
        momentum.left * across,
        momentum.top * down,
        momentum.right * across,
        momentum.bottom * down,
      ),
    );
  }

  /// Where the leg begins, with the switcher's child of [size]: where the
  /// hero the flight leaves is now, as [from] tells, if the leg began on it,
  /// or else where the shuttle was when the leg began.
  Rect? _legBeginOn(Rect? Function() from, Size? size) =>
      (_legBeginsOnHero ? from() : null) ?? _legBegin?.within(size);

  /// How far the shuttle is off its leg's path at [t] of the controller, of
  /// a run of [duration], for the speed it had when the flight diverted. It
  /// sets off at that speed, so it turns rather than stops, and loses it on
  /// its way.
  Rect _momentum(double t, Duration duration) {
    final seconds = duration.seconds;
    final fade = t * (1 - t) * (1 - t) * (1 - t);
    // The swing sets in after the shuttle sets off, and fades out before it
    // lands.
    final swing = 3 * t * fade;
    return _divertVelocity
        .times(seconds * fade)
        .shift(_divertSwing * (seconds * swing));
  }

  /// How the shuttle swings out on its way to [to], where the hero the
  /// flight diverts to is: toward the side that hero is on, as hard as the
  /// shuttle moves, and the more so the more that hero is behind it. A hero
  /// ahead of it or to its side needs no swing, since the speed the shuttle
  /// carries on at already curves its path.
  Offset _swingToward(Rect? to) {
    final from = _rect;
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

  /// [rect], kept with the switcher's child of [size].
  static _KeptRect? _keep(Rect? rect, Size? size) =>
      rect == null ? null : _KeptRect(rect, size);
}
