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

import 'package:flutter/material.dart';
import 'package:hero_here/hero_here.dart';

import '../show_details_hero/eight_thousander.dart';
import '../style/motion.dart';

void main() => runApp(
  MaterialApp(
    title: 'HeroHere Flip Card Example',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
    darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
    home: const FlipCardExample(),
  ),
);

/// The grid's `maxCrossAxisExtent`.
const kMaxCrossAxisExtent = 250.0;

/// The space between the grid's cells.
const kGridSpacing = 32.0;

/// The largest a grid cell gets, in a grid of one column. A grid's cells can
/// be wider than its maxCrossAxisExtent, by up to its spacing, since it counts
/// a spacing for each column but puts one fewer between them.
const kLargestCellExtent = kMaxCrossAxisExtent + kGridSpacing;

/// The size of the open card, on a screen with room for it.
const kCardExtent = 360.0;

const _borderRadius = BorderRadius.all(Radius.circular(32));

class FlipCardExample extends StatefulWidget {
  const FlipCardExample({super.key});

  @override
  State<FlipCardExample> createState() => _FlipCardExampleState();
}

class _FlipCardExampleState extends State<FlipCardExample>
    with TickerProviderStateMixin {
  int? _openIndex;

  /// How dim each card is, from 0 to 1: while a card is open, the others
  /// dim. Each card dims its own faces, in its cell and in flight alike,
  /// rather than lie under a layer that dims the grid, since flights fly over
  /// the grid's layers. So a card on its way back to the grid dims along with
  /// it when another card opens meanwhile.
  late final _dims = [
    for (final _ in kEightThousanders)
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      ),
  ];

  @override
  void dispose() {
    for (final dim in _dims) {
      dim.dispose();
    }
    super.dispose();
  }

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
                maxCrossAxisExtent: kMaxCrossAxisExtent,
                mainAxisSpacing: kGridSpacing,
                crossAxisSpacing: kGridSpacing,
              ),
              itemCount: kEightThousanders.length,
              // A card in its cell: the cell's index as its tag, and a key of
              // its own.
              itemBuilder: (context, index) => HeroHere(
                key: ValueKey('cell-$index'),
                tag: index,
                // Flips over as it flies, on a bouncy spring.
                flightShuttleBuilder: HeroHereShuttles.flip(),
                flightAnimationControllerFactory: bouncySpring.controller,
                flightAnimationFactory: bouncySpring.animation,
                forwardFlightAnimation: bouncySpring.forward,
                reverseFlightAnimation: bouncySpring.reverse,
                child: _Photo(
                  kEightThousanders[index],
                  dim: _dims[index],
                  onTap: () => _show(index),
                ),
              ),
            ),
          ),
          if (openIndex != null) ...[
            // Closes the open card on a tap beside it.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _close,
              ),
            ),
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
                    // The open card: the same tag as its cell's, with another
                    // key, so it flies from the cell here, and back once it
                    // closes. It takes the cell's options too, since a flight
                    // takes them from the hero it lands on.
                    child: HeroHere(
                      key: ValueKey('card-$openIndex'),
                      tag: openIndex,
                      flightShuttleBuilder: HeroHereShuttles.flip(),
                      flightAnimationControllerFactory: bouncySpring.controller,
                      flightAnimationFactory: bouncySpring.animation,
                      forwardFlightAnimation: bouncySpring.forward,
                      reverseFlightAnimation: bouncySpring.reverse,
                      child: _Details(
                        kEightThousanders[openIndex],
                        dim: _dims[openIndex],
                        onTap: _close,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _close() => _show(null);

  /// Opens the card at [index], or none if it's null, and dims the others
  /// while one is open.
  void _show(int? index) {
    setState(() => _openIndex = index);
    for (final (i, dim) in _dims.indexed) {
      if (index == null || i == index) {
        dim.reverse();
      } else {
        dim.forward();
      }
    }
  }
}

/// The front of an eight-thousander's card: its photo.
class _Photo extends StatelessWidget {
  const _Photo(this.eightThousander, {required this.dim, required this.onTap});

  final EightThousander eightThousander;
  final Animation<double> dim;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _Face(
    dim: dim,
    elevation: 8,
    onTap: onTap,
    decoration: BoxDecoration(
      image: DecorationImage(
        // Decoded at the height of the largest cell rather than at full
        // size, mostly 2048 pixels wide, so all the photos fit in the image
        // cache.
        image: ResizeImage(
          AssetImage(eightThousander.image),
          height: (kLargestCellExtent * MediaQuery.devicePixelRatioOf(context))
              .ceil(),
        ),
        fit: BoxFit.cover,
      ),
    ),
  );
}

/// The back of an eight-thousander's card: its name and description.
class _Details extends StatelessWidget {
  const _Details(
    this.eightThousander, {
    required this.dim,
    required this.onTap,
  });

  final EightThousander eightThousander;
  final Animation<double> dim;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Laid out at the open card's size and scaled to the size it shows at,
    // so as the card grows and shrinks in flight, its words keep their lines
    // rather than jump from one to the next.
    return FittedBox(
      child: SizedBox.square(
        dimension: kCardExtent,
        child: _Face(
          dim: dim,
          elevation: 24,
          onTap: onTap,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
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
    );
  }
}

/// A face of a card, with [decoration] and [child], dimmed by [dim]: under a
/// veil of the canvas's color, and with its shadow fading as the veil
/// thickens.
class _Face extends StatelessWidget {
  const _Face({
    required this.dim,
    required this.elevation,
    required this.onTap,
    required this.decoration,
    this.child,
  });

  final Animation<double> dim;
  final int elevation;
  final VoidCallback onTap;
  final BoxDecoration decoration;
  final Widget? child;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedBuilder(
      animation: dim,
      builder: (context, child) {
        final veil = .9 * dim.value;
        return Container(
          decoration: decoration.copyWith(
            borderRadius: _borderRadius,
            boxShadow: [
              for (final shadow in kElevationToShadow[elevation]!)
                shadow.copyWith(
                  color: shadow.color.withValues(
                    alpha: shadow.color.a * (1 - veil),
                  ),
                ),
            ],
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: _borderRadius,
            color: Theme.of(context).canvasColor.withValues(alpha: veil),
          ),
          child: child,
        );
      },
      child: child,
    ),
  );
}
