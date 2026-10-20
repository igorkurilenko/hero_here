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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hero_here/hero_here.dart';

import '../style/style.dart';
import 'launches.dart';

void main() => runApp(
  MaterialApp(
    title: 'HeroHere Splash Screen Example',
    debugShowCheckedModeBanner: false,
    theme: exampleTheme,
    home: const SplashLogoExample(),
  ),
);

/// A splash screen whose logo and name fly into the app bar once the app has
/// loaded, within the page:
///
/// 1. A [HeroHereSwitcher] wraps the page.
/// 2. The logo and the name are [HeroHere]s, on the splash screen or in the
///    app bar: with the same tags in both, and keys of their own in each.
/// 3. Once the app has loaded, the page shows the app bar in place of the
///    splash screen, and the switcher flies them there.
class SplashLogoExample extends StatefulWidget {
  const SplashLogoExample({super.key});

  @override
  State<SplashLogoExample> createState() => _SplashLogoExampleState();
}

class _SplashLogoExampleState extends State<SplashLogoExample> {
  var _loaded = false;
  Timer? _loading;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _loading?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    // 1. The switcher.
    return HeroHereSwitcher(
      child: SplashBackground(
        splash: !_loaded,
        child: _loaded
            ? Scaffold(
                backgroundColor: Colors.transparent,
                appBar: AppBar(
                  backgroundColor: Colors.transparent,
                  // A tap on them shows the splash screen again.
                  title: GestureDetector(
                    onTap: _reload,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 2. The logo and the name in the app bar: the same
                        // tags as on the splash screen, and keys of their own.
                        SizedBox.square(
                          dimension: kAppBarLogoExtent,
                          child: HeroHere(
                            key: const ValueKey('app-bar-logo'),
                            tag: 'logo',
                            // Lands on a soft spring.
                            flightAnimationControllerFactory:
                                softSpringController,
                            flightAnimationFactory: softSpringAnimation,
                            forwardFlightAnimation: softSpringForward,
                            reverseFlightAnimation: softSpringReverse,
                            child: const Logo(),
                          ),
                        ),
                        G.w12,
                        HeroHere(
                          key: const ValueKey('app-bar-name'),
                          tag: 'name',
                          // Scaled from one size to the other, rather than
                          // laid out anew at each.
                          flightShuttleBuilder: HeroHereShuttles.scale(
                            fit: BoxFit.contain,
                          ),
                          flightAnimationControllerFactory:
                              softSpringController,
                          flightAnimationFactory: softSpringAnimation,
                          forwardFlightAnimation: softSpringForward,
                          reverseFlightAnimation: softSpringReverse,
                          child: AppName(style: text.titleLarge),
                        ),
                      ],
                    ),
                  ),
                ),
                body: const Launches(),
              )
            : Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 2. The logo and the name on the splash screen.
                    SizedBox.square(
                      dimension: kSplashLogoExtent,
                      child: HeroHere(
                        key: const ValueKey('splash-logo'),
                        tag: 'logo',
                        flightAnimationControllerFactory: softSpringController,
                        flightAnimationFactory: softSpringAnimation,
                        forwardFlightAnimation: softSpringForward,
                        reverseFlightAnimation: softSpringReverse,
                        child: const Logo(),
                      ),
                    ),
                    G.h24,
                    HeroHere(
                      key: const ValueKey('splash-name'),
                      tag: 'name',
                      flightShuttleBuilder: HeroHereShuttles.scale(
                        fit: BoxFit.contain,
                      ),
                      flightAnimationControllerFactory: softSpringController,
                      flightAnimationFactory: softSpringAnimation,
                      forwardFlightAnimation: softSpringForward,
                      reverseFlightAnimation: softSpringReverse,
                      child: AppName(style: text.displaySmall),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  /// 3. Shows the splash screen until the app has loaded.
  void _load() {
    _loading?.cancel();
    _loading = Timer(kLoadingDuration, () => setState(() => _loaded = true));
  }

  void _reload() {
    setState(() => _loaded = false);
    _load();
  }
}
