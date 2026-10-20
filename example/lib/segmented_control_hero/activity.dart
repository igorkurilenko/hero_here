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

// What the segmented control example looks like, apart from its heroes,
// which main.dart places.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hero_here/hero_here.dart';

import '../style/style.dart';

/// A period of the activity: the steps walked in it, and a bar of the chart
/// for each part of it.
typedef Period = ({String label, int steps, List<Bar> bars});

/// A bar of the chart: the part of the period it stands for, and its height,
/// as a share of the chart's.
typedef Bar = ({String label, double share});

/// The periods the segmented control switches between.
const List<Period> kPeriods = [
  (
    label: 'Day',
    steps: 8432,
    bars: [
      (label: '6', share: .15),
      (label: '9', share: .5),
      (label: '12', share: .9),
      (label: '15', share: .6),
      (label: '18', share: .8),
      (label: '21', share: .4),
      (label: '24', share: .1),
    ],
  ),
  (
    label: 'Week',
    steps: 61207,
    bars: [
      (label: 'M', share: .6),
      (label: 'T', share: .8),
      (label: 'W', share: .5),
      (label: 'T', share: .9),
      (label: 'F', share: .7),
      (label: 'S', share: 1.0),
      (label: 'S', share: .4),
    ],
  ),
  (
    label: 'Month',
    steps: 243980,
    bars: [
      (label: '1', share: .7),
      (label: '5', share: .45),
      (label: '10', share: .8),
      (label: '15', share: .6),
      (label: '20', share: .95),
      (label: '25', share: .75),
      (label: '30', share: .55),
    ],
  ),
];

/// How long the chart takes to change to another period: as long as the
/// thumb's flight to its segment.
const kChartDuration = HeroHere.defaultFlightAnimationDuration;

/// The chart's height: a bar's at a share of 1.
const kChartHeight = 200.0;

/// The segmented control's track, which the segments lie on.
class SegmentTrack extends StatelessWidget {
  const SegmentTrack({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    height: S.s9,
    padding: const EdgeInsets.all(S.s1),
    decoration: ShapeDecoration(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .05),
      shape: squircle(R.lg),
    ),
    child: child,
  );
}

/// A segment: its label, and [thumb], if any, under it.
class Segment extends StatelessWidget {
  const Segment(
    this.label, {
    super.key,
    required this.selected,
    required this.onTap,
    this.thumb,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? thumb;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ?thumb,
          Center(
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: selected
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The selected segment's thumb: a white surface on the track.
class SegmentThumb extends StatelessWidget {
  const SegmentThumb({super.key});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: ShapeDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: squircle(
        R.md,
        side: BorderSide(color: Theme.of(context).colorScheme.outline),
      ),
    ),
  );
}

/// The steps walked in [period], and its chart. They count, and its bars
/// grow and shrink, to the next period's.
class StepsChart extends StatelessWidget {
  const StepsChart(this.period, {super.key});

  final Period period;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tallest = period.bars.map((bar) => bar.share).reduce(math.max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Steps',
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        // In digits of one width, so the number stays where it is as it
        // counts.
        TweenAnimationBuilder<double>(
          tween: Tween(end: period.steps.toDouble()),
          duration: kChartDuration,
          curve: HeroHere.defaultFlightAnimationCurve,
          builder: (context, steps, _) => Text(
            _withCommas(steps.round()),
            style: theme.textTheme.displaySmall?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        G.h32,
        SizedBox(
          // With room for the labels under the bars.
          height: kChartHeight + S.s8,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final bar in period.bars)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      AnimatedContainer(
                        duration: kChartDuration,
                        curve: HeroHere.defaultFlightAnimationCurve,
                        width: S.s6,
                        height: kChartHeight * bar.share,
                        decoration: ShapeDecoration(
                          // The tallest bar stands out.
                          color: bar.share == tallest
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: .1,
                                ),
                          shape: squircle(R.md),
                        ),
                      ),
                      G.h8,
                      Text(
                        bar.label,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// [number] with a comma between each three digits, such as 61,207.
String _withCommas(int number) =>
    '$number'.replaceAllMapped(RegExp(r'\B(?=(\d{3})+$)'), (_) => ',');
