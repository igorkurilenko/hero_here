A Flutter library that enables hero transitions on the same screen without the need for navigation.

<p>
  <img src="https://github.com/igorkurilenko/hero_here/blob/main/assets/hero_here_basic.gif?raw=true"
    alt="The hero_here basic example" width="180"/>
  &nbsp;
  <img src="https://github.com/igorkurilenko/hero_here/blob/main/assets/hero_here_chat_message.gif?raw=true"
   alt="The hero_here chat message example" width="180"/>
  &nbsp;
  <img src="https://github.com/igorkurilenko/hero_here/blob/main/assets/hero_here_show_details.gif?raw=true"
   alt="The hero_here show details example" width="180"/>
</p>

## Purpose

**hero_here** is designed to help developers create seamless and visually appealing transitions within a single screen using the hero animation pattern. It is inspired by Flutter's `AnimatedSwitcher` and `Hero` mechanics and provides a convenient way to achieve these transitions without requiring navigation.

## Features

- Allows hero transitions within the same screen.
- Similar widgets to `AnimatedSwitcher` and `Hero`: `HeroHereSwitcher` and `HeroHere`.
- Customizable flight animations
- Flights that change course mid-flight, either landing on each hero in turn or diverting straight to the new one

## Getting Started

Add the following line to your `pubspec.yaml` file:

```yaml
dependencies:
  hero_here: ^1.5.4
```

Then, run:

```bash
flutter pub get
```

## Usage

Here’s a basic example of how to use **hero_here**:

```dart
import 'package:flutter/material.dart';
import 'package:hero_here/hero_here.dart';

const kHeroTag = 'hero';

void main() => runApp(
      MaterialApp(
        title: 'HeroHere Example',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
        darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
        home: const HeroHereExample(),
      ),
    );

enum HeroType { red, green }

class HeroHereExample extends StatefulWidget {
  const HeroHereExample({super.key});

  @override
  State<HeroHereExample> createState() => _HeroHereExampleState();
}

class _HeroHereExampleState extends State<HeroHereExample> {
  HeroType _curHeroType = HeroType.red;

  HeroType get curHeroType => _curHeroType;

  set curHeroType(HeroType value) {
    if (_curHeroType == value) return;
    setState(() => _curHeroType = value);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: HeroHereSwitcher(
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: curHeroType == HeroType.red
                      ? HeroHere(
                          key: const ValueKey(HeroType.red),
                          tag: kHeroTag,
                          flightShuttleBuilder: _flightShuttleBuilder,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(75),
                            ),
                          ),
                        )
                      : null,
                ),
                SizedBox(
                  width: 150,
                  height: 150,
                  child: curHeroType == HeroType.green
                      ? HeroHere(
                          key: const ValueKey(HeroType.green),
                          tag: kHeroTag,
                          flightShuttleBuilder: _flightShuttleBuilder,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(75),
                            ),
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: BottomAppBar(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () => curHeroType = HeroType.red,
                    icon: Icon(curHeroType == HeroType.red
                        ? Icons.circle
                        : Icons.radio_button_off),
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
                    onPressed: () => curHeroType = HeroType.green,
                    icon: Icon(curHeroType == HeroType.green
                        ? Icons.circle
                        : Icons.radio_button_off),
                    color: curHeroType == HeroType.green
                        ? Colors.green
                        : Theme.of(context).colorScheme.secondary,
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _flightShuttleBuilder(
    BuildContext flightContext,
    Animation<double> animation,
    HeroHere fromHero,
    HeroHere toHero,
  ) =>
      Stack(
        fit: StackFit.expand,
        children: [
          toHero.child,
          FadeTransition(
            opacity: ReverseAnimation(animation),
            child: fromHero.child,
          ),
        ],
      );
}
```

More advanced examples are in the repository's [example folder](https://github.com/igorkurilenko/hero_here/tree/main/example/lib).

## Redirected flights

When the switcher's child changes again while a hero flies, the hero's flight changes course. By default, it lands on the hero it was flying to, then flies on to the new one (`HeroHereFlightRedirect.chain`). To fly from where the shuttle is to the new hero instead, turning toward it at the speed the shuttle had, set `flightRedirect` on the heroes:

```dart
HeroHere(
  key: ValueKey(slot),
  tag: 'avatar',
  flightRedirect: HeroHereFlightRedirect.divert,
  child: avatar,
)
```

When a flight diverts, its shuttle's `fromHero` becomes a stand-in for the shuttle as it was, so a shuttle that fades `fromHero` into `toHero` fades from what it showed.

With `chain`, a flight sent back to the hero it left turns back from where it is. With `divert`, it swings around to that hero, as to any hero behind it.

## Layout

`HeroHereSwitcher` puts the layer its flights fly in, its sky, over its child in a `Stack`. To lay them out yourself, set `layoutBuilder`. Keep the sky after the child in the stack, so it paints over the child and lays out after it: then on each frame, such as on a window resize, flights find their heroes where that frame's layout puts them.

Shuttles fly where their heroes are on the screen, wherever the sky is. The sky takes the smallest size it may, so it doesn't size the switcher. To clip the flights to the switcher, give the sky the switcher's size:

```dart
HeroHereSwitcher(
  layoutBuilder: (child, sky) => Stack(
    children: [child, Positioned.fill(child: ClipRect(child: sky))],
  ),
  child: child,
)
```

## Performance

Every rebuild of `HeroHereSwitcher` runs a switch, with no snapshot of the old child. The new child shows on the frame of the rebuild. On that frame, each hero that went away shows where it was, as it last showed, and after it, the switcher looks for the heroes in the new child and flies each tag whose hero changed. A rebuild still builds the switcher's child anew, so keep frequently changing state, such as timers, streams or text being typed, below the switcher, so it rebuilds only when heroes may move.

Where such state, or sizes, such as from a `LayoutBuilder` or a `MediaQuery.sizeOf`, can't be read below the switcher, set its `switchKey` to what the heroes' places depend on. Then only a rebuild that changes the key runs a switch. Any other rebuild shows its child at once, in place of the current one, and nothing flies:

```dart
HeroHereSwitcher(
  switchKey: (tab, expandedId),
  child: child,
)
```

Each `HeroHere` paints its child into a layer of its own, which a switch keeps to show a hero that went away for that one frame.

## Support and Contact

For any questions or issues related to **hero_here**, please contact me via email at [mail@igorkurilenko.dev](mailto:mail@igorkurilenko.dev).


## Contributing

Contributions are welcome! Feel free to submit pull requests on [GitHub](https://github.com/igorkurilenko/hero_here) to help improve **hero_here**.

## Author and License

**hero_here** was created by Igor Kurilenko and is licensed under Apache 2.0.
