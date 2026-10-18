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

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:hero_here/hero_here.dart';

import '../show_details_hero/config.dart' show kEightThousanders;
import '../show_details_hero/eight_thousander.dart';

void main() => runApp(
  MaterialApp(
    title: 'HeroHere Flip Card Example',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
    darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
    home: const FlipCardExample(),
  ),
);

/// The largest a grid cell gets, but for a grid of one column.
const kMaxCellExtent = 250.0;

/// The size of the open card, on a screen with room for it.
const kCardExtent = 360.0;

const _borderRadius = BorderRadius.all(Radius.circular(32));

/// A bouncy spring, as heroine's default motion, `CupertinoMotion.bouncy()`.
final _spring = SpringDescription.withDurationAndBounce(
  duration: const Duration(milliseconds: 500),
  bounce: 0.3,
);

class FlipCardExample extends StatefulWidget {
  const FlipCardExample({super.key});

  @override
  State<FlipCardExample> createState() => _FlipCardExampleState();
}

class _FlipCardExampleState extends State<FlipCardExample> {
  int? _openIndex;

  @override
  Widget build(BuildContext context) {
    final openIndex = _openIndex;

    return HeroHereSwitcher(
      child: Stack(
        children: [
          Scaffold(
            appBar: AppBar(title: const Text('Eight-thousanders')),
            body: GridView.builder(
              padding: const EdgeInsets.all(32),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: kMaxCellExtent,
                mainAxisSpacing: 32,
                crossAxisSpacing: 32,
              ),
              itemCount: kEightThousanders.length,
              itemBuilder: (context, index) => _cardHero(
                key: ValueKey('cell-$index'),
                index: index,
                child: _Photo(
                  kEightThousanders[index],
                  onTap: () => setState(() => _openIndex = index),
                ),
              ),
            ),
          ),
          // Dims the grid behind the open card, and closes it on a tap.
          Positioned.fill(
            child: IgnorePointer(
              ignoring: openIndex == null,
              child: GestureDetector(
                onTap: _close,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  color: Theme.of(context).canvasColor
                      .withValues(alpha: openIndex == null ? 0 : .9),
                ),
              ),
            ),
          ),
          if (openIndex != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: kCardExtent,
                    maxHeight: kCardExtent,
                  ),
                  child: AspectRatio(
                    aspectRatio: 1,
                    // The same tag as the cell's, with another key, so the
                    // card flies from the cell here, and back once it closes.
                    child: _cardHero(
                      key: ValueKey('card-$openIndex'),
                      index: openIndex,
                      child: _Details(
                        kEightThousanders[openIndex],
                        onTap: _close,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _close() => setState(() => _openIndex = null);
}

/// A hero of the card of the eight-thousander at [index], whose flights flip
/// the card over on a spring. The cell's hero and the open card's take the
/// same options, since a flight takes them from the hero it lands on.
HeroHere _cardHero({
  required Key key,
  required int index,
  required Widget child,
}) => HeroHere(
  key: key,
  tag: index,
  // Unbounded, so the spring can carry the card past its place and back.
  flightAnimationControllerFactory: (vsync, _) =>
      AnimationController.unbounded(vsync: vsync),
  // The spring is the curve.
  flightAnimationFactory: (controller) => controller,
  forwardFlightAnimation: (controller, {from}) =>
      controller.animateWith(_springTo(1, controller, from: from)),
  // A card closed mid-flight turns back on the spring too. The default,
  // controller.reverse(), needs a controller with bounds.
  reverseFlightAnimation: (controller, {from}) =>
      controller.animateBackWith(_springTo(0, controller, from: from)),
  flightShuttleBuilder: _flipShuttleBuilder,
  child: child,
);

/// Springs [controller] to [end], from [from] or else from where it is, at
/// the speed it has, so a card sent back mid-flight swings round rather than
/// stops.
SpringSimulation _springTo(
  double end,
  AnimationController controller, {
  double? from,
}) => SpringSimulation(
  _spring,
  from ?? controller.value,
  end,
  controller.velocity,
  // The cards take no taps until their flight lands, so it lands once the
  // card looks still, rather than when the spring comes fully to rest, about
  // a third of a second later.
  tolerance: const Tolerance(distance: .005, velocity: .05),
);

/// Flips the card over as it flies, as heroine's `FlipShuttleBuilder` does.
/// It turns about its upright axis, and shows the hero it leaves until it's
/// edge on, then the hero it lands on.
Widget _flipShuttleBuilder(
  BuildContext flightContext,
  Animation<double> animation,
  HeroHere fromHero,
  HeroHere toHero,
) => AnimatedBuilder(
  animation: animation,
  builder: (context, _) => Transform(
    alignment: Alignment.center,
    transform: Matrix4.identity()
      ..setEntry(3, 2, .001)
      ..rotateY(math.pi * animation.value),
    child: animation.value < .5
        ? fromHero.child
        // Mirrored, so it reads the right way round once turned over.
        : Transform.flip(flipX: true, child: toHero.child),
  ),
);

/// The front of an eight-thousander's card: its photo.
class _Photo extends StatelessWidget {
  const _Photo(this.eightThousander, {required this.onTap});

  final EightThousander eightThousander;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: _borderRadius,
        boxShadow: kElevationToShadow[8],
        image: DecorationImage(
          // Decoded at the height of the largest cell rather than at full
          // size, mostly 2048 pixels wide, so all the photos fit in the image
          // cache.
          image: ResizeImage(
            AssetImage(eightThousander.image),
            height: (kMaxCellExtent * MediaQuery.devicePixelRatioOf(context))
                .ceil(),
          ),
          fit: BoxFit.cover,
        ),
      ),
    ),
  );
}

/// The back of an eight-thousander's card: its name and description.
class _Details extends StatelessWidget {
  const _Details(this.eightThousander, {required this.onTap});

  final EightThousander eightThousander;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      // Laid out at the open card's size and scaled to the size it shows at,
      // so as the card grows and shrinks in flight, its words keep their
      // lines rather than jump from one to the next.
      child: FittedBox(
        child: SizedBox.square(
          dimension: kCardExtent,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: _borderRadius,
              boxShadow: kElevationToShadow[24],
            ),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eightThousander.name,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: Text(
                      eightThousander.description,
                      overflow: TextOverflow.fade,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
