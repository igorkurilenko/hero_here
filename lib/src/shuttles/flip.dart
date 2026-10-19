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

part of 'shuttles.dart';

HeroHereFlightShuttleBuilder _flip(Axis axis) =>
    (flightContext, animation, fromHero, toHero) => AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final turn = math.pi * animation.value;
        // In perspective, so the edge turning away shrinks.
        final transform = Matrix4.identity()..setEntry(3, 2, .001);
        switch (axis) {
          case Axis.vertical:
            transform.rotateY(turn);
          case Axis.horizontal:
            transform.rotateX(turn);
        }
        return Transform(
          alignment: Alignment.center,
          transform: transform,
          child: animation.value < .5
              ? fromHero.child
              : Transform.flip(
                  flipX: axis == Axis.vertical,
                  flipY: axis == Axis.horizontal,
                  child: toHero.child,
                ),
        );
      },
    );
