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

import 'package:example/show_details_hero/config.dart';
import 'package:flutter/material.dart';
import 'package:hero_here/hero_here.dart';

import 'eight_thousander.dart';

class EightThousanderPreviewHero extends StatefulWidget {
  final String tag;
  final EightThousander eightThousander;
  final ValueChanged<BuildContext>? onTap;
  final HeroHereFlightAnimationControllerFactory?
  imageHeroFlightAnimationControllerFactory;
  final HeroHereFlightAnimationFactory? imageHeroFlightAnimationFactory;
  final HeroHereFlightAnimationStarter? forwardImageHeroFlightAnimation;

  const EightThousanderPreviewHero({
    super.key,
    required this.tag,
    required this.eightThousander,
    this.onTap,
    this.imageHeroFlightAnimationControllerFactory,
    this.imageHeroFlightAnimationFactory,
    this.forwardImageHeroFlightAnimation,
  });

  @override
  State<EightThousanderPreviewHero> createState() =>
      _EightThousanderPreviewHeroState();
}

class _EightThousanderPreviewHeroState
    extends State<EightThousanderPreviewHero> {
  String get tag => widget.tag;

  TextStyle get titleStyle =>
      Theme.of(context).textTheme.titleSmall!
          .copyWith(fontWeight: FontWeight.w900);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: widget.onTap != null ? _onTap : null,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildImageHero()),
        const SizedBox(height: 8),
        _buildTitle(),
        _buildFakeTitleHero(),
        _buildFakeDescriptionHero(),
      ],
    ),
  );

  HeroHere _buildImageHero() => HeroHere(
    key: ValueKey('$kImageHeroTagPrefix$tag'),
    tag: '$kImageHeroTagPrefix$tag',
    flightAnimationControllerFactory:
        widget.imageHeroFlightAnimationControllerFactory,
    flightAnimationFactory: widget.imageHeroFlightAnimationFactory,
    forwardFlightAnimation: widget.forwardImageHeroFlightAnimation,
    flightShuttleBuilder: _buildImageHeroFlightShuttle,
    child: ClipRRect(
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(kPreviewImageBorderRadius),
      child: Image(
        width: double.infinity,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        image: thumbnailOf(
          widget.eightThousander,
          MediaQuery.devicePixelRatioOf(context),
        ),
      ),
    ),
  );

  Text _buildTitle() => Text(widget.eightThousander.name, style: titleStyle);

  HeroHere _buildFakeDescriptionHero() => HeroHere(
    key: ValueKey('$kDescriptionHeroTagPrefix$tag'),
    tag: '$kDescriptionHeroTagPrefix$tag',
    rectTweenFactory: _createTitleOrDescriptionHeroRectTween,
    flightShuttleBuilder: _buildTitleOrDescriptionHeroFlightShuttle,
    child: const SizedBox(),
  );

  HeroHere _buildFakeTitleHero() => HeroHere(
    key: ValueKey('$kTitleHeroTagPrefix$tag'),
    tag: '$kTitleHeroTagPrefix$tag',
    rectTweenFactory: _createTitleOrDescriptionHeroRectTween,
    flightShuttleBuilder: _buildTitleOrDescriptionHeroFlightShuttle,
    child: const SizedBox(),
  );

  Widget _buildImageHeroFlightShuttle(
    BuildContext flightContext,
    Animation<double> animation,
    HeroHere fromHero,
    HeroHere toHero,
  ) {
    final fromBorderRadius = fromHero.payload as BorderRadius;
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedBuilder(
          animation: animation,
          builder: (context, child) => ClipRRect(
            borderRadius: BorderRadiusTween(
              begin: fromBorderRadius,
              end: BorderRadius.circular(kPreviewImageBorderRadius),
            ).evaluate(animation)!,
            child: child,
          ),
          child: fromHero.child,
        ),
      ],
    );
  }

  RectTween _createTitleOrDescriptionHeroRectTween(Rect? begin, Rect? end) =>
      RectTween(begin: begin, end: begin);

  Widget _buildTitleOrDescriptionHeroFlightShuttle(
    BuildContext flightContext,
    Animation<double> animation,
    HeroHere fromHero,
    HeroHere toHero,
  ) => AnimatedBuilder(
    animation: animation,
    builder: (context, _) =>
        (fromHero.payload! as FadedText)(1 - animation.value),
  );

  void _onTap() => widget.onTap?.call(context);
}
