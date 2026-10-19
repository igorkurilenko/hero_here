# hero_here: Hero animations on the same page

Like Flutter's `Hero`, but with no `Navigator` and no routes.

Flutter's `Hero` flies a widget to its place on a new route, as the `Navigator` pushes or pops it. When the page you're on changes instead, such as when a grid item opens into its details in place, or a sent message joins the chat, the widget just jumps to its new place. hero_here makes it fly there, without navigation: as with `Hero`, give its old and new places the same tag, then change state.

<p>
  <img src="https://github.com/igorkurilenko/hero_here/blob/main/assets/hero_here_basic.gif?raw=true"
    alt="A red circle flies across the screen and grows into a green one" width="180"/>
  &nbsp;
  <img src="https://github.com/igorkurilenko/hero_here/blob/main/assets/hero_here_chat_message.gif?raw=true"
   alt="Sent chat messages fly from the input field up into the conversation" width="180"/>
  &nbsp;
  <img src="https://github.com/igorkurilenko/hero_here/blob/main/assets/hero_here_show_details.gif?raw=true"
   alt="A mountain's photo flies from a grid into its details on the same screen, and back" width="180"/>
</p>

## Features

- Hero transitions within one page, with no `Navigator` or routes.
- `HeroHereSwitcher` and `HeroHere`, which work like `AnimatedSwitcher` and `Hero`.
- Customizable flights: their duration, curve, path and shuttle, and what drives them, such as a spring.
- Flights that change course mid-flight, either landing on each hero in turn or diverting straight to the new one.
- Ready-made shuttles: a crossfade, a flip like a card's, and a scale that keeps text from reflowing in flight.
- Flights that follow their heroes as they move, such as on a scroll or a window resize.
- Android, iOS, web, macOS, Windows and Linux. Wasm-ready, with no dependencies beyond Flutter.

## Quick start

Add hero_here to your `pubspec.yaml`:

```yaml
dependencies:
  hero_here: ^2.1.1
```

Wrap the part of the page whose widgets move in a `HeroHereSwitcher`. Put a `HeroHere` in each place the widget may be, with the same tag and a key of its own:

```dart
HeroHereSwitcher(
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      for (final side in ['left', 'right'])
        SizedBox.square(
          dimension: 64,
          child: side == _side
              ? HeroHere(
                  key: ValueKey(side), // Its own key in each place.
                  tag: 'ball', // The same tag in both places.
                  child: const CircleAvatar(),
                )
              : null,
        ),
    ],
  ),
)
```

Then change `_side`, a field of your `State`, and the ball flies there from where it was:

```dart
setState(() => _side = _side == 'left' ? 'right' : 'left');
```

A switch flies a tag when it brings a hero with that tag and another key. A hero with the same key is the same hero: it shows where it is now, and nothing flies.

The [Example tab](https://pub.dev/packages/hero_here/example) has a whole app, and the repository's [example folder](https://github.com/igorkurilenko/hero_here/tree/main/example/lib) has the examples below.

## Examples

### Grid to details on the same page (container transform without a route)

In the [details example](https://github.com/igorkurilenko/hero_here/tree/main/example/lib/show_details_hero), a tapped mountain in a grid opens into its details in place: its photo, name and description each fly to their places in the details, and back when they close. Each is a hero of its own, whose tag the grid's cell and the details share.

### A chat message that flies from the input into the list

In the [chat example](https://github.com/igorkurilenko/hero_here/tree/main/example/lib/chat_message_hero), a sent message flies from the text field up into the chat. The field's hero and the list's share the message's tag, with keys of their own.

### A card flip animation as a card flies open

In the [flip card example](https://github.com/igorkurilenko/hero_here/tree/main/example/lib/flip_card_hero), a tapped photo in a grid flies to the middle on a bouncy spring, flipping over to show the mountain's name and description. Tap it again, or beside it, and it flies back. `HeroHereShuttles.flip()` turns the card over in flight, and its heroes run their flights on a `SpringSimulation`.

### Heroes that change course mid-flight

In the [auto-switching example](https://github.com/igorkurilenko/hero_here/tree/main/example/lib/basic_with_auto_switching), heroes switch places on a timer, and a flight whose hero changes mid-flight chains or diverts to the new one. See [Redirected flights](#redirected-flights).

## hero_here, Hero, AnimatedSwitcher and similar packages

| | Animates when | Needs a route change | What flies |
|---|---|---|---|
| `Hero` | the `Navigator` pushes or pops a route | yes | from the widget with a tag on one route to the one with that tag on the other |
| `AnimatedSwitcher` | its child changes to one with another key or type | no | nothing: by default, it cross-fades from the old child to the new one, in the same place |
| [heroine](https://pub.dev/packages/heroine) | the `Navigator` pushes or pops a route, with a `HeroineController` among its observers | yes | as with `Hero`, on a spring |
| [local_hero](https://pub.dev/packages/local_hero) | a `LocalHero`'s position changes, under a `LocalHeroScope` | no | the widget, to its new position |
| [animated_to](https://pub.dev/packages/animated_to) | its child's position changes, such as on a rebuild; it takes a `GlobalKey` | no | the widget, to its new position |
| **hero_here** | a `HeroHereSwitcher`'s child changes and brings a hero with a tag and another key | no | from the hero with that tag that was there to the new one, as with `Hero` |

- To fly between routes, use `Hero`, or heroine for springs and drag to dismiss.
- To move one widget to wherever a rebuild lays it out, local_hero and animated_to follow its position, with no second widget.
- hero_here flies between two widgets that share a tag, as `Hero` does, so they may look different, such as a thumbnail and a full photo, and a shuttle, such as a crossfade or a flip, can blend them in flight.

## FAQ

### Why doesn't `Hero` animate when I call `setState`?

`Hero` flies only during a route's transition, when the `Navigator` pushes or pops a route. A rebuild of the page you're on shows the widget in its new place at once. To fly it there, wrap that part of the page in a `HeroHereSwitcher` and use `HeroHere` in place of `Hero`.

### I moved my widget and nothing flew. Why?

A hero's key tells a switch whether it's a new hero, which flies, or the same one, which doesn't. A hero with the same key shows where it is now, even when it moved. Give the hero in each place its own key, such as `ValueKey(place)`, as in the [quick start](#quick-start).

To slide one widget to wherever a rebuild lays it out instead, see local_hero or animated_to above.

### Can two heroes have the same tag?

Of the heroes with one tag in the switcher's child, only the last shows. The others hide, keeping their space. Give each item its own tag, such as its id.

### How do I change a flight's duration or curve?

Set them on the heroes. A flight takes each of its options from the hero it flies to, or else from the hero it leaves, or else the default: 300 ms on `Curves.easeInOut`.

```dart
HeroHere(
  key: ValueKey(side),
  tag: 'ball',
  flightAnimationDuration: const Duration(milliseconds: 600),
  flightAnimationFactory: (controller) =>
      CurvedAnimation(parent: controller, curve: Curves.easeOutBack),
  child: const CircleAvatar(),
)
```

For a spring, run the flight's controller on a `SpringSimulation` through `forwardFlightAnimation` and `reverseFlightAnimation`, as the [flip card example](https://github.com/igorkurilenko/hero_here/blob/main/example/lib/flip_card_hero/main.dart) does.

### Is it a shared element transition?

Yes, within one page. It's the idea behind SwiftUI's `matchedGeometryEffect`, Jetpack Compose's shared elements and Framer Motion's `layoutId`: two views share an id, and a change from one to the other animates.

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

## Shuttles

A flight shows a shuttle as it flies: by default, the child of the hero it flies to. `HeroHereShuttles` has ready-made ones for `flightShuttleBuilder`:

- `HeroHereShuttles.crossfade()` fades the hero a flight leaves out over the hero it flies to.
- `HeroHereShuttles.flip()` turns the shuttle over like a card, and shows the hero it flies to once it's edge on. Pass `axis: Axis.horizontal` to turn it top over bottom.
- `HeroHereShuttles.scale()` lays out the hero it flies to once, at that hero's size, and stretches it to the shuttle, so its text keeps its line breaks as the shuttle grows or shrinks. Pass `fit` and `alignment` to scale it another way.

```dart
HeroHere(
  key: ValueKey(side),
  tag: 'card',
  flightShuttleBuilder: HeroHereShuttles.flip(),
  child: card,
)
```

To build your own, wrap what changes in an `AnimatedBuilder` or a transition, such as a `FadeTransition`: a flight builds its shuttle once per leg, not on each frame.

## Layout

`HeroHereSwitcher` puts the layer its flights fly in, its sky, over its child in a `Stack`, in a transparent `Material`. The material gives them a default text style and a surface for ink, but paints no background, so what's behind the switcher shows through. To lay them out yourself, set `layoutBuilder`. Keep the sky after the child in the stack, so it paints over the child and lays out after it: then on each frame, such as on a window resize, flights find their heroes where that frame's layout puts them.

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
