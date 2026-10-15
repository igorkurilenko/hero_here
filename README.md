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

## Getting Started

Add the following line to your `pubspec.yaml` file:

```yaml
dependencies:
  hero_here: ^1.1.7
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

More advanced examples can be found in the `example` folder or by following [this link](https://github.com/igorkurilenko/hero_here/tree/main/example/lib).


## Performance

Every rebuild of `HeroHereSwitcher` runs a switch: it takes a snapshot of the current child and lays the new child out offstage for a frame to find its heroes. Keep frequently changing state, such as timers, streams or text being typed, below the switcher, so it rebuilds only when heroes may move.

## Support and Contact

For any questions or issues related to **hero_here**, please contact me via email at [mail@igorkurilenko.dev](mailto:mail@igorkurilenko.dev).


## Contributing

Contributions are welcome! Feel free to submit pull requests on [GitHub](https://github.com/igorkurilenko/hero_here) to help improve **hero_here**.

## Author and License

**hero_here** was created by Igor Kurilenko and is licensed under Apache 2.0.
