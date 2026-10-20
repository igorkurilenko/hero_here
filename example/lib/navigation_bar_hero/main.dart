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
import 'tabs.dart';

void main() => runApp(
  MaterialApp(
    title: 'HeroHere Navigation Bar Example',
    debugShowCheckedModeBanner: false,
    theme: exampleTheme,
    home: const NavigationBarExample(),
  ),
);

/// A bottom navigation bar whose indicator flies to the tapped tab, within
/// the page:
///
/// 1. A [HeroHereSwitcher] wraps the tabs.
/// 2. The selected tab shows the indicator, a [HeroHere], under its icon:
///    with the same tag on every tab, and a key of its own on each.
/// 3. A tap selects another tab, and the switcher flies the indicator there.
class NavigationBarExample extends StatefulWidget {
  const NavigationBarExample({super.key});

  @override
  State<NavigationBarExample> createState() => _NavigationBarExampleState();
}

class _NavigationBarExampleState extends State<NavigationBarExample> {
  var _selected = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: TabPage(kTabs[_selected]),
    bottomNavigationBar: TabBarSurface(
      // 1. The switcher. Its sky, the layer flights fly in, lies under the
      // tabs, so the indicator flies under their icons.
      child: HeroHereSwitcher(
        layoutBuilder: HeroHereSwitcher.skyUnderLayoutBuilder,
        child: Row(
          children: [
            for (final (index, tab) in kTabs.indexed)
              Expanded(
                child: TabButton(
                  tab,
                  selected: index == _selected,
                  // 3. A tap selects the tab.
                  onTap: () => setState(() => _selected = index),
                  // 2. The indicator, on the selected tab only.
                  indicator: index == _selected
                      ? HeroHere(
                          key: ValueKey(index), // Its own key on each tab.
                          tag: 'indicator', // The same tag on every tab.
                          // A tap mid-flight starts it over to the new tab,
                          // from where it is.
                          flightRedirect: HeroHereFlightRedirect.restart,
                          child: const TabIndicator(),
                        )
                      : null,
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
