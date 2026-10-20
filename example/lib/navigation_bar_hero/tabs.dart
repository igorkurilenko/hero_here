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

// What the navigation bar example looks like, apart from its heroes, which
// main.dart places.

import 'package:flutter/material.dart';
import 'package:hero_here/hero_here.dart';

import '../style/style.dart';

/// A tab of the navigation bar.
typedef NavTab = ({String label, String icon});

/// The tabs of the navigation bar.
const List<NavTab> kTabs = [
  (label: 'Home', icon: UniconData.home),
  (label: 'Search', icon: UniconData.search),
  (label: 'Saved', icon: UniconData.saved),
  (label: 'Profile', icon: UniconData.profile),
];

/// The page of [tab]: its icon and its name. It fades out, then the next
/// tab's fades in, as the indicator flies to the next tab.
class TabPage extends StatelessWidget {
  const TabPage(this.tab, {super.key});

  final NavTab tab;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: HeroHere.defaultFlightAnimationDuration,
    switchInCurve: const Interval(.5, 1),
    switchOutCurve: const Interval(.5, 1),
    child: Center(
      key: ValueKey(tab),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Unicon(
            tab.icon,
            size: S.s10,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          G.h16,
          Text(tab.label, style: Theme.of(context).textTheme.headlineSmall),
        ],
      ),
    ),
  );
}

/// The navigation bar's surface, under a hairline at the bottom of the page.
class TabBarSurface extends StatelessWidget {
  const TabBarSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    child: SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(),
          SizedBox(height: S.s10, child: child),
        ],
      ),
    ),
  );
}

/// A tab: its icon over its label, muted until it's selected, and
/// [indicator], if any, under the icon.
class TabButton extends StatelessWidget {
  const TabButton(
    this.tab, {
    super.key,
    required this.selected,
    required this.onTap,
    this.indicator,
  });

  final NavTab tab;
  final bool selected;
  final VoidCallback onTap;
  final Widget? indicator;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurfaceVariant;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: S.s10,
            height: S.s7,
            child: Stack(
              alignment: Alignment.center,
              children: [
                ?indicator,
                Unicon(tab.icon, color: color),
              ],
            ),
          ),
          G.h4,
          Text(
            tab.label,
            style: theme.textTheme.labelMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

/// What shows which tab is selected: a faint fill under its icon, as
/// rose_app's navigation shows it.
class TabIndicator extends StatelessWidget {
  const TabIndicator({super.key});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: ShapeDecoration(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .08),
      shape: squircle(R.xl),
    ),
    child: const SizedBox.expand(),
  );
}
