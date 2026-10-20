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

// What the splash screen example looks like, apart from its heroes, which
// main.dart places.

import 'package:flutter/material.dart';

import '../style/style.dart';

/// How long the splash screen shows, as if the app loaded meanwhile.
const kLoadingDuration = Duration(milliseconds: 1500);

/// The logo's size on the splash screen.
const kSplashLogoExtent = 112.0;

/// The logo's size in the app bar.
const kAppBarLogoExtent = S.s8;

/// How long the splash screen's color takes to give way to the page's.
const _fadeDuration = Duration(milliseconds: 400);

/// The launches the app lists once it has loaded.
const _launches = [
  (title: 'Lunar lander', when: 'In 3 days', icon: UniconData.compass),
  (title: 'Crew rotation', when: 'In 9 days', icon: UniconData.crew),
  (title: 'Weather satellite', when: 'In 2 weeks', icon: UniconData.chart),
  (title: 'Cargo resupply', when: 'In 3 weeks', icon: UniconData.clock),
];

/// The page's background: the splash screen's shade while [splash], else
/// the page's, which it fades to.
class SplashBackground extends StatelessWidget {
  const SplashBackground({
    super.key,
    required this.splash,
    required this.child,
  });

  final bool splash;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: _fadeDuration,
    color: splash
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : Theme.of(context).colorScheme.surface,
    child: child,
  );
}

/// The app's logo: a rocket on the accent. It's laid out at one size and
/// scaled to any, so its corners and its rocket grow and shrink with it.
class Logo extends StatelessWidget {
  const Logo({super.key});

  @override
  Widget build(BuildContext context) => FittedBox(
    child: SizedBox.square(
      dimension: S.s9,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: squircle(R.lg),
        ),
        child: Center(
          child: Unicon(
            UniconData.rocket,
            size: S.s7,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
      ),
    ),
  );
}

/// The app's name, in [style].
class AppName extends StatelessWidget {
  const AppName({super.key, required this.style});

  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Text('Orbit', style: style);
}

/// What the app shows once it has loaded: the launches coming up, which slide
/// up into place as they fade in.
class Launches extends StatelessWidget {
  const Launches({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: _fadeDuration,
      curve: Curves.easeOut,
      builder: (context, shown, child) => Opacity(
        opacity: shown,
        child: Transform.translate(
          offset: Offset(0, S.s7 * (1 - shown)),
          child: child,
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(S.s4),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(S.s1, S.s2, S.s1, S.s3),
            child: Text(
              'Upcoming launches',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Card(
            child: Column(
              children: [
                for (final (index, launch) in _launches.indexed) ...[
                  if (index > 0) const Divider(),
                  ListTile(
                    leading: Unicon(
                      launch.icon,
                      color: theme.colorScheme.onSurface,
                    ),
                    title: Text(launch.title),
                    subtitle: Text(launch.when),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
