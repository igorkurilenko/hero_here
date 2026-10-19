More advanced examples are in the repository's [example folder](https://github.com/igorkurilenko/hero_here/tree/main/example/lib).

Here’s a basic example of how to use hero_here:

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
                      flightShuttleBuilder: HeroHereShuttles.crossfade(),
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
                      flightShuttleBuilder: HeroHereShuttles.crossfade(),
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
                onPressed: () => curHeroType = HeroType.green,
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
        ],
      ),
    ),
  );
}
```
