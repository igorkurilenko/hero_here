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

import 'eight_thousander.dart';

const kGoldenRatio = 1.618;

const kGridViewConstraints = BoxConstraints(maxWidth: 560);

/// Padding that centers a column no wider than [kGridViewConstraints] in a
/// scroll view [width] wide. The scroll view can then span the window, which
/// puts its scrollbar at the window's edge.
EdgeInsets centerColumnPadding(double width) => EdgeInsets.symmetric(
  horizontal: max(0, (width - kGridViewConstraints.maxWidth) / 2),
);

const kGridViewPadding = EdgeInsets.all(8);
const kGridViewDelegate = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 2,
  childAspectRatio: 0.618,
  mainAxisSpacing: 16,
  crossAxisSpacing: 16,
);

/// How tall a grid cell is with the grid [width] wide, or as wide as
/// [kGridViewConstraints] lets it be, if that's less.
double gridViewCellHeight(double width) =>
    (min(width, kGridViewConstraints.maxWidth) -
        kGridViewPadding.horizontal -
        (kGridViewDelegate.crossAxisCount - 1) *
            kGridViewDelegate.crossAxisSpacing) /
    kGridViewDelegate.crossAxisCount /
    kGridViewDelegate.childAspectRatio;

/// [eightThousander]'s image decoded no taller than a grid cell shows it,
/// rather than at the full size the details show it at.
///
/// The cell is the one of a grid as wide as the wider of the window and the
/// display. On a phone that's its screen, so the grid's images fit in the
/// image cache. A resize of a window doesn't change the size, as the
/// display's stays, so it decodes no image anew, and the details, which show
/// the image until their own decodes, work out the same size.
ImageProvider thumbnailOf(
  BuildContext context,
  EightThousander eightThousander,
) {
  final display = View.of(context).display;
  final width = max(
    MediaQuery.sizeOf(context).width,
    display.size.width / display.devicePixelRatio,
  );
  return ResizeImage.resizeIfNeeded(
    null,
    (gridViewCellHeight(width) * MediaQuery.devicePixelRatioOf(context)).ceil(),
    AssetImage(eightThousander.image),
  );
}

const kGridViewScaleWhenDetailsOpen = 1.2;
const kGridViewOpacityOnOpen = 0.1;

const kImageHeroTagPrefix = 'image-';
const kTitleHeroTagPrefix = 'title-';
const kDescriptionHeroTagPrefix = 'description-';
const kDetailsHeroKeyPrefix = 'details-';

/// The payload of the details' title and description heroes: their text at
/// [opacity], faded by its color, so their flights fade them without an
/// opacity layer, which on the web paints offscreen on every frame.
typedef FadedText = Widget Function(double opacity);

const kPreviewImageBorderRadius = 32.0;
const kDragDistanceToClose = 50.0;
const kDragVelocityToClose = 300.0;
const kMinImageScaleOnDrag = 0.9;

final kScrollBehavior = const MaterialScrollBehavior().copyWith(
  dragDevices: {
    PointerDeviceKind.mouse,
    PointerDeviceKind.touch,
    PointerDeviceKind.stylus,
    PointerDeviceKind.unknown,
  },
);
