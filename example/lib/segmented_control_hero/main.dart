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

import '../style/style.dart';
import 'activity.dart';

void main() => runApp(
  MaterialApp(
    title: 'HeroHere Segmented Control Example',
    debugShowCheckedModeBanner: false,
    theme: exampleTheme,
    home: const SegmentedControlExample(),
  ),
);

/// A sliding segmented control, whose thumb flies to the tapped segment
/// within the page:
///
/// 1. A [HeroHereSwitcher] wraps the segments.
/// 2. The selected segment shows the thumb, a [HeroHere], under its label:
///    with the same tag in every segment, and a key of its own in each.
/// 3. A tap selects another segment, and the switcher flies the thumb there.
class SegmentedControlExample extends StatefulWidget {
  const SegmentedControlExample({super.key});

  @override
  State<SegmentedControlExample> createState() =>
      _SegmentedControlExampleState();
}

class _SegmentedControlExampleState extends State<SegmentedControlExample> {
  var _selected = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Activity')),
    body: Padding(
      padding: const EdgeInsets.all(S.s6),
      child: Column(
        children: [
          SegmentTrack(
            // 1. The switcher. Its sky, the layer flights fly in, lies under
            // the segments, so the thumb flies under their labels.
            child: HeroHereSwitcher(
              layoutBuilder: HeroHereSwitcher.skyUnderLayoutBuilder,
              child: Row(
                children: [
                  for (final (index, period) in kPeriods.indexed)
                    Expanded(
                      child: Segment(
                        period.label,
                        selected: index == _selected,
                        // 3. A tap selects the period.
                        onTap: () => setState(() => _selected = index),
                        // 2. The thumb, in the selected segment only.
                        thumb: index == _selected
                            ? HeroHere(
                                key: ValueKey(index), // Its own in each.
                                tag: 'thumb', // The same in every segment.
                                // A tap mid-flight starts it over to the new
                                // one, from where it is.
                                flightRedirect: HeroHereFlightRedirect.restart,
                                child: const SegmentThumb(),
                              )
                            : null,
                      ),
                    ),
                ],
              ),
            ),
          ),
          G.h32,
          StepsChart(kPeriods[_selected]),
        ],
      ),
    ),
  );
}
