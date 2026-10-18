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

import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:hero_here/hero_here.dart';

import 'config.dart';
import 'eight_thousander.dart';

class EightThousanderDetailsHero extends StatefulWidget {
  final String tag;
  final EightThousander eightThousander;
  final ValueChanged<Velocity>? onClose;

  const EightThousanderDetailsHero({
    super.key,
    required this.tag,
    required this.eightThousander,
    this.onClose,
  });

  @override
  State<EightThousanderDetailsHero> createState() =>
      _EightThousanderDetailsHeroState();
}

class _EightThousanderDetailsHeroState
    extends State<EightThousanderDetailsHero> {
  final _scrollController = ScrollController();
  // A notifier rather than state, so a drag rebuilds only what it changes.
  final _factorToClose = ValueNotifier(0.0);
  VelocityTracker? _imageDragVelocityTracker;

  String get tag => widget.tag;

  TextStyle get titleStyle =>
      Theme.of(context).textTheme.titleLarge!
          .copyWith(fontWeight: FontWeight.w900);

  Size get screenSize => MediaQuery.sizeOf(context);

  double get factorToClose => _factorToClose.value;

  set factorToClose(double value) => _factorToClose.value = value;

  Velocity? get imageDragVelocity => _imageDragVelocityTracker?.getVelocity();

  Size get imageSize => Size(
    min(screenSize.width, kGridViewConstraints.maxWidth),
    min(screenSize.width, kGridViewConstraints.maxWidth) * kGoldenRatio,
  );

  BorderRadius get imageBorderRadius =>
      BorderRadius.circular(kPreviewImageBorderRadius * factorToClose);

  double get imageScale => 1.0 - (1.0 - kMinImageScaleOnDrag) * factorToClose;

  double get titleOrDescriptionOpacity => 1.0 - factorToClose;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _factorToClose.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScrollConfiguration(
    behavior: kScrollBehavior,
    child: ListView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: centerColumnPadding(screenSize.width),
      children: [
        SizedBox(
          width: imageSize.width,
          height: imageSize.height,
          child: Align(
            alignment: Alignment.center,
            child: _buildOnDrag(
              Image(
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                image: AssetImage(widget.eightThousander.image),
                // The grid's thumbnail, already decoded, until the full image
                // is, so the flight that opens the details never shows a gap.
                frameBuilder: (context, child, frame, _) => frame != null
                    ? child
                    : Image(
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        image: thumbnailOf(
                          widget.eightThousander,
                          MediaQuery.devicePixelRatioOf(context),
                        ),
                      ),
              ),
              (image) => SizedBox(
                width: imageSize.width * imageScale,
                child: Listener(
                  onPointerDown: _handleImagePointerDown,
                  onPointerMove: _handleImagePointerMove,
                  onPointerUp: _handleImagePointerUp,
                  child: AspectRatio(
                    aspectRatio: 1 / kGoldenRatio,
                    child: ClipRRect(
                      borderRadius: imageBorderRadius,
                      child: _buildImageHero(image),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // The text fades by its color, so a drag builds it anew.
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ValueListenableBuilder(
            valueListenable: _factorToClose,
            builder: (context, _, _) => _buildTitleHero(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ValueListenableBuilder(
            valueListenable: _factorToClose,
            builder: (context, _, _) => _buildDescriptionHero(),
          ),
        ),
        const SizedBox(height: 32),
      ],
    ),
  );

  /// Builds [builder] again whenever a drag changes [factorToClose], passing
  /// it the same [child] each time.
  ///
  /// Heroes go inside [builder], not inside [child]: a flight builds its
  /// shuttle from a hero's child after the details are gone, so that child
  /// mustn't listen to this state's notifier.
  Widget _buildOnDrag(Widget child, Widget Function(Widget child) builder) =>
      ValueListenableBuilder(
        valueListenable: _factorToClose,
        builder: (context, _, child) => builder(child!),
        child: child,
      );

  HeroHere _buildImageHero(Widget image) => HeroHere(
    key: ValueKey('$kDetailsHeroKeyPrefix$kImageHeroTagPrefix$tag'),
    tag: '$kImageHeroTagPrefix$tag',
    payload: imageBorderRadius,
    flightShuttleBuilder: _buildImageHeroFlightShuttle,
    rectTweenFactory: _createImageHeroRectTween,
    child: image,
  );

  // The texts are built from values read here, not from this state, since a
  // flight that closes the details builds them after the details are gone.
  HeroHere _buildTitleHero() {
    final name = widget.eightThousander.name;
    final style = titleStyle;
    final opacity = titleOrDescriptionOpacity;
    Widget title(double flight) => Text(
      name,
      style: style.copyWith(color: _faded(style.color, opacity * flight)),
    );

    return HeroHere(
      key: ValueKey('$kDetailsHeroKeyPrefix$kTitleHeroTagPrefix$tag'),
      tag: '$kTitleHeroTagPrefix$tag',
      rectTweenFactory: _createTitleOrDescriptionHeroRectTween,
      flightShuttleBuilder: _buildTitleOrDescriptionHeroFlightShuttle,
      payload: title,
      child: title(1),
    );
  }

  HeroHere _buildDescriptionHero() {
    final description = widget.eightThousander.description;
    final color = DefaultTextStyle.of(context).style.color;
    final opacity = titleOrDescriptionOpacity;
    Widget text(double flight) => Text(
      description,
      softWrap: true,
      maxLines: null,
      style: TextStyle(color: _faded(color, opacity * flight)),
    );

    return HeroHere(
      key: ValueKey('$kDetailsHeroKeyPrefix$kDescriptionHeroTagPrefix$tag'),
      tag: '$kDescriptionHeroTagPrefix$tag',
      rectTweenFactory: _createTitleOrDescriptionHeroRectTween,
      flightShuttleBuilder: _buildTitleOrDescriptionHeroFlightShuttle,
      payload: text,
      child: text(1),
    );
  }

  /// [color] faded by [opacity], as a drag closes the details or a flight
  /// fades them. Text faded by its color paints without the offscreen layer
  /// an [Opacity] would take, which on the web it takes even when opaque.
  static Color? _faded(Color? color, double opacity) =>
      color?.withValues(alpha: color.a * opacity);

  Widget _buildImageHeroFlightShuttle(
    BuildContext flightContext,
    Animation<double> animation,
    HeroHere fromHero,
    HeroHere toHero,
  ) => Stack(
    fit: StackFit.expand,
    children: [
      AnimatedBuilder(
        animation: animation,
        builder: (context, child) => ClipRRect(
          borderRadius: BorderRadiusTween(
            begin: BorderRadius.circular(kPreviewImageBorderRadius),
            end: BorderRadius.zero,
          ).evaluate(animation)!,
          child: child,
        ),
        child: toHero.child,
      ),
    ],
  );

  RectTween _createImageHeroRectTween(Rect? begin, Rect? end) =>
      RectTween(begin: begin, end: end);

  RectTween _createTitleOrDescriptionHeroRectTween(Rect? begin, Rect? end) =>
      RectTween(begin: end, end: end);

  Widget _buildTitleOrDescriptionHeroFlightShuttle(
    BuildContext flightContext,
    Animation<double> animation,
    HeroHere fromHero,
    HeroHere toHero,
  ) => AnimatedBuilder(
    animation: animation,
    builder: (context, _) => (toHero.payload! as FadedText)(animation.value),
  );

  void _handleScroll() {
    if (_scrollController.position.pixels > 0) return;

    factorToClose =
        min(_scrollController.position.pixels.abs(), kDragDistanceToClose) /
        kDragDistanceToClose;
  }

  void _handleImagePointerDown(PointerDownEvent event) =>
      _imageDragVelocityTracker = VelocityTracker.withKind(event.kind);

  void _handleImagePointerMove(PointerMoveEvent event) =>
      _imageDragVelocityTracker?.addPosition(event.timeStamp, event.position);

  void _handleImagePointerUp(PointerUpEvent event) {
    final imageDragVelocityDy = imageDragVelocity?.pixelsPerSecond.dy ?? 0;

    if (factorToClose < 1 && imageDragVelocityDy < kDragVelocityToClose) return;

    widget.onClose?.call(_imageDragVelocityTracker!.getVelocity());
  }
}
