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

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:hero_here/hero_here.dart';

const kHeroTag = 'hero';
const kAutoHeroSwitchingDuration = Duration(milliseconds: 500);
const kHeroFlightAnimationDuration = Duration(milliseconds: 1000);

void main() => runApp(
  MaterialApp(
    title: 'HeroHere Basic Example',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
    darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
    home: const AutoSwitchingExample(),
  ),
);

class AutoSwitchingExample extends StatefulWidget {
  const AutoSwitchingExample({super.key});

  @override
  State<AutoSwitchingExample> createState() => _AutoSwitchingExampleState();
}

class _AutoSwitchingExampleState extends State<AutoSwitchingExample> {
  HeroType _curHeroType = HeroType.red;
  HeroHereFlightRedirect _redirect = HeroHereFlightRedirect.chain;
  bool _paused = true;
  Timer? _timer;

  // Where each hero shows, picked at random once, so flights go every way.
  final _alignments = _pickAlignments();

  HeroType get curHeroType => _curHeroType;

  set curHeroType(HeroType value) {
    if (_curHeroType == value) return;
    setState(() => _curHeroType = value);
  }

  bool get paused => _paused;

  set paused(bool value) {
    if (value == _paused) return;
    setState(() {
      (_paused = value) ? _pauseHeroSwitching() : _startHeroSwitching();
    });
  }

  @override
  void initState() {
    super.initState();

    if (!paused) {
      _startHeroSwitching();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      centerTitle: true,
      // What a flight does when the hero changes mid-flight: land on each
      // hero in turn, or divert straight to the new one.
      title: SegmentedButton(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: HeroHereFlightRedirect.chain,
            label: Text('Chain'),
          ),
          ButtonSegment(
            value: HeroHereFlightRedirect.divert,
            label: Text('Divert'),
          ),
        ],
        selected: {_redirect},
        onSelectionChanged: (selected) =>
            setState(() => _redirect = selected.single),
      ),
    ),
    body: HeroHereSwitcher(
      // Only a new hero runs a switch. Other rebuilds of the page, such as on
      // a Chain or Divert tap, show the child in place.
      switchKey: curHeroType,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Align(
            alignment: _alignments[HeroType.red]!,
            child: SizedBox(
              width: 100,
              height: 100,
              child: curHeroType == HeroType.red
                  ? HeroHere(
                      key: const ValueKey(HeroType.red),
                      tag: kHeroTag,
                      flightAnimationDuration: kHeroFlightAnimationDuration,
                      flightShuttleBuilder: _flightShuttleBuilder,
                      flightRedirect: _redirect,
                      child: Container(color: Colors.red),
                    )
                  : null,
            ),
          ),
          Align(
            alignment: _alignments[HeroType.green]!,
            child: SizedBox(
              width: 150,
              height: 150,
              child: curHeroType == HeroType.green
                  ? HeroHere(
                      key: const ValueKey(HeroType.green),
                      tag: kHeroTag,
                      flightAnimationDuration: kHeroFlightAnimationDuration,
                      flightShuttleBuilder: _flightShuttleBuilder,
                      flightRedirect: _redirect,
                      child: Container(color: Colors.green),
                    )
                  : null,
            ),
          ),
          Align(
            alignment: _alignments[HeroType.blue]!,
            child: SizedBox(
              width: 100,
              height: 100,
              child: curHeroType == HeroType.blue
                  ? HeroHere(
                      key: const ValueKey(HeroType.blue),
                      tag: kHeroTag,
                      flightAnimationDuration: kHeroFlightAnimationDuration,
                      flightShuttleBuilder: _flightShuttleBuilder,
                      flightRedirect: _redirect,
                      child: Container(color: Colors.blue),
                    )
                  : null,
            ),
          ),
        ],
      ),
    ),
    // The buttons change on each switch, and paint for a while after a tap.
    // In a layer of their own, they repaint without the page.
    bottomNavigationBar: RepaintBoundary(
      child: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () => paused = !paused,
                  icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
                ),
              ],
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () {
                    paused = true;
                    curHeroType = HeroType.red;
                  },
                  icon: Icon(
                    curHeroType == HeroType.red
                        ? Icons.circle
                        : Icons.radio_button_off,
                  ),
                  color: curHeroType == HeroType.red
                      ? Colors.red
                      : Theme.of(context).colorScheme.secondary,
                ),
              ],
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () {
                    paused = true;
                    curHeroType = HeroType.green;
                  },
                  icon: Icon(
                    curHeroType == HeroType.green
                        ? Icons.circle
                        : Icons.radio_button_off,
                  ),
                  color: curHeroType == HeroType.green
                      ? Colors.green
                      : Theme.of(context).colorScheme.secondary,
                ),
              ],
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () {
                    paused = true;
                    curHeroType = HeroType.blue;
                  },
                  icon: Icon(
                    curHeroType == HeroType.blue
                        ? Icons.circle
                        : Icons.radio_button_off,
                  ),
                  color: curHeroType == HeroType.blue
                      ? Colors.blue
                      : Theme.of(context).colorScheme.secondary,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Widget _flightShuttleBuilder(
    BuildContext flightContext,
    Animation<double> animation,
    HeroHere fromHero,
    HeroHere toHero,
  ) => Stack(
    fit: StackFit.expand,
    children: [
      toHero.child,
      FadeTransition(
        opacity: ReverseAnimation(animation),
        child: fromHero.child,
      ),
    ],
  );

  void _startHeroSwitching() {
    _timer = Timer.periodic(kAutoHeroSwitchingDuration, (_) {
      final i = Random().nextInt(HeroType.values.length);
      curHeroType = HeroType.values[i];
    });
  }

  void _pauseHeroSwitching() {
    _timer?.cancel();
  }

  /// Picks a spot for each hero, far enough from the others that the heroes
  /// don't overlap on most screens.
  static Map<HeroType, Alignment> _pickAlignments() {
    final random = Random();
    final alignments = <Alignment>[];
    while (alignments.length < HeroType.values.length) {
      final alignment = Alignment(
        random.nextDouble() * 2 - 1,
        random.nextDouble() * 2 - 1,
      );
      final apart = alignments.every(
        (other) =>
            (other.x - alignment.x).abs() > 0.8 ||
            (other.y - alignment.y).abs() > 0.8,
      );
      if (apart) alignments.add(alignment);
    }
    return Map.fromIterables(HeroType.values, alignments);
  }
}

enum HeroType { red, green, blue }
