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

void main() => runApp(
  const MaterialApp(
    title: 'HeroHere Example',
    debugShowCheckedModeBanner: false,
    home: FlippersExample(),
  ),
);

/// The flippers photo from Flutter's hero animations guide, flying between
/// the middle of the page and its corner, within the page:
///
/// 1. A [HeroHereSwitcher] wraps the page's body.
/// 2. The photo is a [HeroHere], in the middle or in the corner: with the
///    same tag in both places, and a key of its own in each.
/// 3. A tap moves the photo to the other place, and the switcher flies it
///    there.
class FlippersExample extends StatefulWidget {
  const FlippersExample({super.key});

  @override
  State<FlippersExample> createState() => _FlippersExampleState();
}

class _FlippersExampleState extends State<FlippersExample> {
  var _inCorner = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Basic Hero Animation')),
    body: GestureDetector(
      // 3. A tap moves the photo to the other place.
      onTap: () => setState(() => _inCorner = !_inCorner),
      // 1. The switcher.
      child: HeroHereSwitcher(
        // 2. The photo, in the corner or in the middle.
        child: _inCorner
            ? Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 100,
                  child: HeroHere(
                    key: const ValueKey('corner'), // Its own key in each place.
                    tag: 'flippers', // The same tag in both places.
                    child: Image.asset('images/flippers.png'),
                  ),
                ),
              )
            : Center(
                child: SizedBox(
                  width: 300,
                  child: HeroHere(
                    key: const ValueKey('center'),
                    tag: 'flippers',
                    child: Image.asset('images/flippers.png'),
                  ),
                ),
              ),
      ),
    ),
  );
}
