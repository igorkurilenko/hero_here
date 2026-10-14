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

import 'package:flutter/material.dart';
import 'package:hero_here/hero_here.dart';

import 'config.dart';
import 'eight_thousander_details_hero.dart';
import 'eight_thousander_preview_hero.dart';

void main() => runApp(
  MaterialApp(
    title: 'HeroHere Show Details Example',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
    darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
    home: const ShowDetailsExample(),
  ),
);

class ShowDetailsExample extends StatefulWidget {
  const ShowDetailsExample({super.key});

  @override
  State<ShowDetailsExample> createState() => _ShowDetailsExampleState();
}

class _ShowDetailsExampleState extends State<ShowDetailsExample> {
  int? _showDetailsIndex;
  Velocity? _dragEndVelocityOnClose;
  Offset _gridViewOffset = Offset.zero;
  bool _isHeroSwitching = false;

  bool get detailsVisible => _showDetailsIndex != null;

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBodyBehindAppBar: true,
    extendBody: true,
    appBar: _buildAppBar(),
    body: _buildBody(),
  );

  AppBar _buildAppBar() => AppBar(
    forceMaterialTransparency: true,
    leading: AnimatedSwitcher(
      duration: HeroHere.defaultFlightAnimationDuration,
      child: detailsVisible
          ? Material(
              color: Colors.transparent,
              key: UniqueKey(),
              child: IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _isHeroSwitching ? null : _closeDetails,
              ),
            )
          : SizedBox(key: UniqueKey()),
    ),
  );

  Widget _buildBody() => HeroHereSwitcher(
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: ConstrainedBox(
            constraints: kGridViewConstraints,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                AnimatedSlide(
                  offset: _gridViewOffset,
                  duration: HeroHere.defaultFlightAnimationDuration,
                  curve: HeroHere.defaultFlightAnimationCurve,
                  child: AnimatedScale(
                    scale: _gridViewScale,
                    duration: HeroHere.defaultFlightAnimationDuration,
                    curve: HeroHere.defaultFlightAnimationCurve,
                    child: AnimatedOpacity(
                      opacity: _gridViewOpacity,
                      duration: HeroHere.defaultFlightAnimationDuration,
                      curve: HeroHere.defaultFlightAnimationCurve,
                      child: IgnorePointer(
                        ignoring: _isHeroSwitching,
                        child: ScrollConfiguration(
                          behavior: kScrollBehavior,
                          child: GridView.builder(
                            clipBehavior: Clip.none,
                            padding: const EdgeInsets.all(8),
                            gridDelegate: kGridViewDelegate,
                            itemCount: kEightThousanders.length,
                            itemBuilder: _buildGridItem,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (detailsVisible) _buildDetails(_showDetailsIndex!),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildGridItem(BuildContext context, int index) {
    final eightThousander = kEightThousanders[index];

    return EightThousanderPreviewHero(
      tag: eightThousander.image,
      eightThousander: eightThousander,
      onTap: (context) => _showDetails(context, index),
      imageHeroFlightAnimationFactory: (controller) {
        final animation = _dragEndVelocityOnClose == null
            ? HeroHere.defaultFlightAnimationFactory(controller)
            : controller;
        animation.addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => setState(() => _isHeroSwitching = false),
            );
          }
        });
        return animation;
      },
      forwardImageHeroFlightAnimation: _dragEndVelocityOnClose == null
          ? HeroHere.defaultForwardFlightAnimation
          : (controller, {from}) {
              final screenSize = MediaQuery.sizeOf(context);
              final pixelsPerSecond = _dragEndVelocityOnClose!.pixelsPerSecond;
              final unitsPerSecondX = pixelsPerSecond.dx / screenSize.width;
              final unitsPerSecondY = pixelsPerSecond.dy / screenSize.height;
              final unitsPerSecond = Offset(unitsPerSecondX, unitsPerSecondY);
              final unitVelocity = unitsPerSecond.distance;
              return controller.fling(velocity: unitVelocity);
            },
    );
  }

  Widget _buildDetails(int index) {
    final eightThousander = kEightThousanders[index];

    return EightThousanderDetailsHero(
      tag: eightThousander.image,
      eightThousander: eightThousander,
      onClose: _closeDetails,
    );
  }

  void _showDetails(BuildContext context, int index) => setState(() {
    final renderBox = context.findRenderObject() as RenderBox;
    final itemPosition = renderBox.localToGlobal(Offset.zero);
    final itemCenter = renderBox.size.center(itemPosition);
    _gridViewOffset = _computeGridViewSlideOffset(index, itemCenter);
    _showDetailsIndex = index;
    _dragEndVelocityOnClose = null;
    _isHeroSwitching = true;
  });

  void _closeDetails([Velocity? dragEndVelocity]) => setState(() {
    _gridViewOffset = Offset.zero;
    _dragEndVelocityOnClose = dragEndVelocity;
    _showDetailsIndex = null;
    _isHeroSwitching = true;
  });

  double get _gridViewScale =>
      detailsVisible ? kGridViewScaleWhenDetailsOpen : 1.0;

  double get _gridViewOpacity => detailsVisible ? kGridViewOpacityOnOpen : 1.0;

  Offset _computeGridViewSlideOffset(int index, Offset begin) {
    final screenSize = MediaQuery.sizeOf(context);
    final a = begin;
    final b = Offset(screenSize.width / 2, screenSize.height / 2);
    final xOffset = b.dx - a.dx;
    final yOffset = b.dy - a.dy;
    final maxXOffset =
        screenSize.width * (kGridViewScaleWhenDetailsOpen - 1) / 2;
    final maxYOffset =
        screenSize.height * (kGridViewScaleWhenDetailsOpen - 1) / 2;
    Offset e = a;

    if (xOffset.abs() > maxXOffset) {
      final x = a.dx + xOffset.sign * maxXOffset;
      final y = (x - a.dx) * (b.dy - a.dy) / (b.dx - a.dx) + a.dy;
      e = Offset(x, y);
    } else if (yOffset.abs() > maxYOffset) {
      final y = a.dy + yOffset.sign * maxYOffset;
      final x = (y - a.dy) * (b.dx - a.dx) / (b.dy - a.dy) + a.dx;
      e = Offset(x, y);
    }

    return (e - a).scale(1 / screenSize.width, 1 / screenSize.height);
  }
}
