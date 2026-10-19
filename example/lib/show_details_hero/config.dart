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

const kEightThousanders = [
  EightThousander(
    image: 'assets/images/mount-everest.jpeg',
    name: 'Mount Everest',
    description: 'Mount Everest is Earth\'s highest mountain above sea level, located in the Mahalangur Himal sub-range of the Himalayas. The China–Nepal border runs across its summit point. Its elevation of 8,848.86 m was most recently established in 2020 by the Chinese and Nepali authorities.',
  ),
  EightThousander(
    image: 'assets/images/k2.jpeg',
    name: 'K2',
    description: 'K2, at 8,611 metres above sea level, is the second-highest mountain on Earth, after Mount Everest at 8,849 metres.',
  ),
  EightThousander(
    image: 'assets/images/kangchenjunga.jpeg',
    name: 'Kangchenjunga',
    description: 'Kangchenjunga, also spelled Kanchenjunga, Kanchanjanghā and Khangchendzonga, is the third-highest mountain in the world. ',
  ),
  EightThousander(
    image: 'assets/images/lhotse.jpeg',
    name: 'Lhotse',
    description: 'Lhotse is the fourth highest mountain in the world at 8,516 metres, after Mount Everest, K2, and Kangchenjunga. The main summit is on the border between Tibet Autonomous Region of China and the Khumbu region of Nepal.',
  ),
  EightThousander(
    image: 'assets/images/makalu.jpeg',
    name: 'Makalu',
    description: 'Makalu is the fifth highest mountain in the world at 8,485 metres. It is located in the Mahalangur Himalayas 19 km southeast of Mount Everest, on the China–Nepal border. One of the eight-thousanders, Makalu is an isolated peak in the shape of a four-sided pyramid. Makalu has two notable subsidiary peaks.',
  ),
  EightThousander(
    image: 'assets/images/cho-oyu.jpeg',
    name: 'Cho Oyu',
    description: 'Cho Oyu is the sixth-highest mountain in the world at 8,188 metres above sea level. Cho Oyu means "Turquoise Goddess" in Tibetan. The mountain is the westernmost major peak of the Khumbu sub-section of the Mahalangur Himalaya 20 km west of Mount Everest.',
  ),
  EightThousander(
    image: 'assets/images/dhaulagiri.jpeg',
    name: 'Dhaulagiri',
    description: 'Dhaulagiri, located in Nepal, is the seventh highest mountain in the world at 8,167 metres above sea level, and the highest mountain within the borders of a single country. It was first climbed on 13 May 1960 by a Swiss-Austrian-Nepali expedition. Annapurna I is 34 km east of Dhaulagiri.',
  ),
  EightThousander(
    image: 'assets/images/manaslu.jpeg',
    name: 'Manaslu',
    description: 'Manaslu is the eighth-highest mountain in the world at 8,163 metres above sea level. It is in the Mansiri Himal, part of the Nepalese Himalayas, in west-central Nepal. Manaslu means "mountain of the spirit" and the word is derived from the Sanskrit word manasa, meaning "intellect" or "soul".',
  ),
  EightThousander(
    image: 'assets/images/nanga-parbat.jpeg',
    name: 'Nanga Parbat',
    description: 'Nanga Parbat, known locally as Diamer, is the ninth-highest mountain on Earth and its summit is at 8,126 m above sea level.',
  ),
  EightThousander(
    image: 'assets/images/annapurna-one.jpeg',
    name: 'Annapurna I',
    description: 'Annapurna is a mountain situated in the Annapurna mountain range of Gandaki Province, north-central Nepal. It is the 10th highest mountain in the world at 8,091 metres above sea level and is well known for the difficulty and danger involved in its ascent.',
  ),
  EightThousander(
    image: 'assets/images/gasherbrum-one.jpeg',
    name: 'Gasherbrum I',
    description: 'Gasherbrum I, surveyed as K5 and also known as Hidden Peak, is the 11th highest mountain in the world at 8,080 metres above sea level. It is located between Shigar District in the Gilgit–Baltistan region of Pakistan and Tashkurgan in the Xinjiang of China.',
  ),
  EightThousander(
    image: 'assets/images/broad-peak.jpeg',
    name: 'Broad Peak',
    description: 'Broad Peak is one of the eight-thousanders, and is located in the Karakoram range spanning Gilgit-Baltistan, Pakistan and Xinjiang, China. It is the 12th highest mountain in the world with 8,051 metres elevation above sea level.',
  ),
  EightThousander(
    image: 'assets/images/gasherbrum-two.jpeg',
    name: 'Gasherbrum II',
    description: 'Gasherbrum II; surveyed as K4, is the 13th highest mountain in the world at 8,035 metres above sea level. It is the third-highest peak of the Gasherbrum massif, and is located in the Karakoram, on the border between Gilgit–Baltistan, Pakistan and Xinjiang, China.',
  ),
  EightThousander(
    image: 'assets/images/shishapangma.jpeg',
    name: 'Shishapangma',
    description: 'Shishapangma, or Shishasbangma or Xixiabangma, is the 14th-highest mountain in the world, at 8,027 metres above sea level. It is located entirely within Tibet. In 1964, it became the final eight-thousander to be climbed.',
  ),
];
