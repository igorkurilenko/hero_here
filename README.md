# hero_here: Hero animations on the same page

Like Flutter's `Hero`, but with no `Navigator` and no routes.

hero_here is a Flutter package for a hero animation on the same page, or the same screen: a hero transition without navigation. Flutter's `Hero` widget flies a widget to its place on a new route, as the `Navigator` pushes or pops it. When the page you're on changes instead, such as when a tab is selected, a product goes into the cart, a grid item opens into its details in place, or a sent message joins the chat, the widget just jumps to its new place. hero_here makes it fly there: as with `Hero`, give its old and new places the same tag, then change state.

<p>
  <img src="https://github.com/igorkurilenko/hero_here/blob/main/assets/hero_here_add_to_cart.webp?raw=true"
    alt="A product's picture flies from its card into the cart, and back" width="180"/>
  &nbsp;
  <img src="https://github.com/igorkurilenko/hero_here/blob/main/assets/hero_here_navigation_bar.webp?raw=true"
    alt="A tap on a tab of a bottom navigation bar slides its indicator to it" width="180"/>
  &nbsp;
  <img src="https://github.com/igorkurilenko/hero_here/blob/main/assets/hero_here_segmented_control.webp?raw=true"
    alt="A segmented control's thumb slides to the tapped period as a chart's bars grow and shrink" width="180"/>
  &nbsp;
  <img src="https://github.com/igorkurilenko/hero_here/blob/main/assets/hero_here_splash_logo.webp?raw=true"
    alt="A splash screen's logo and name fly into the app bar once the app has loaded" width="180"/>
</p>

## Features

- Hero transitions within one page, with no `Navigator` or routes.
- `HeroHereSwitcher` and `HeroHere`, which work like `AnimatedSwitcher` and `Hero`.
- Custom hero animations: a flight's duration, curve, path and shuttle, and what drives it, such as a spring.
- Flights that change course mid-flight: landing on each hero in turn, turning toward the new one at the speed they had, or starting over toward it from where they are.
- Ready-made shuttles: a crossfade, a flip like a card's, and a scale that keeps text from reflowing in flight.
- Flights that follow their heroes as they move, such as on a scroll or a window resize.
- Android, iOS, web, macOS, Windows and Linux. Wasm-ready, with no dependencies beyond Flutter.

## Quick start

Add hero_here to your `pubspec.yaml`:

```yaml
dependencies:
  hero_here: ^2.3.1
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

The [Example tab](https://pub.dev/packages/hero_here/example) has a whole app, a Flutter hero animation example of an add to cart animation, and the repository's [example folder](https://github.com/igorkurilenko/hero_here/tree/main/example/lib) has the examples below. Each is a hero widget example of a pattern apps often need.

## Examples

### An add to cart animation

In the [add to cart example](https://github.com/igorkurilenko/hero_here/blob/main/example/lib/main.dart), also on the Example tab, an add to cart animation flies a product's picture from its card into the cart, where it lands on a soft spring. Take it out of the cart, and it flies back, as the products after it in the cart slide along. Each product's card and its place in the cart share the product's tag, with keys of their own.

### An animated bottom navigation bar with a sliding indicator

In the [navigation bar example](https://github.com/igorkurilenko/hero_here/tree/main/example/lib/navigation_bar_hero), an animated bottom navigation bar slides its indicator to the tapped tab: a bottom navigation bar animation with no offsets to compute. The indicator is a hero under the selected tab's icon, with the same tag on every tab and a key of its own on each. It flies under the icons, as in [Layout](#layout), and a tap mid-flight starts it over to the new tab from where it is, as in [Redirected flights](#redirected-flights).

### A sliding segmented control

In the [segmented control example](https://github.com/igorkurilenko/hero_here/tree/main/example/lib/segmented_control_hero), the thumb of a sliding segmented control flies to the tapped period, Day, Week or Month, as the chart's bars grow and shrink, and the steps count to the period's total. It works as an animated toggle switch does, for any number of options, and the switcher flies the thumb under the labels, as in [Layout](#layout).

### A splash screen logo that lands in the app bar

In the [splash screen example](https://github.com/igorkurilenko/hero_here/tree/main/example/lib/splash_logo_hero), the logo and the name fly from the middle of the splash screen into the app bar once the app has loaded, landing on a soft spring as the content fades in: a splash screen animation on the same page, rather than an animated splash screen on a route of its own. In this logo animation, `HeroHereShuttles.scale()` scales the name from one size to the other rather than lay it out anew.

### Grid to details on the same page (container transform without a route)

In the [details example](https://github.com/igorkurilenko/hero_here/tree/main/example/lib/show_details_hero), a tapped mountain in a grid opens into its details in place, as in a container transform or an open container animation, but with no route: its photo, name and description each fly to their places in the details. Pull the photo down, and they fly back as the details collapse into the grid. This card expand animation is a shared element transition: each is a hero of its own, whose tag the grid's cell and the details share.

<img src="https://github.com/igorkurilenko/hero_here/blob/main/assets/hero_here_show_details.webp?raw=true"
  alt="A mountain's photo flies from a grid into its details on the same screen, and back" width="180"/>

### A chat message that flies from the input into the list

In the [chat example](https://github.com/igorkurilenko/hero_here/tree/main/example/lib/chat_message_hero), a chat message animation flies a sent message from the text field up into the chat, where it lands on a soft spring. The field's hero and the list's share the message's tag, with keys of their own.

<img src="https://github.com/igorkurilenko/hero_here/blob/main/assets/hero_here_chat_message.webp?raw=true"
  alt="Sent chat messages fly from the input field up into the conversation" width="180"/>

### A card flip animation as a card flies open

In the [flip card example](https://github.com/igorkurilenko/hero_here/tree/main/example/lib/flip_card_hero), a tapped photo in a grid flies to the middle on a bouncy spring, flipping over to show the mountain's name and description: a flip card animation, or card flip animation, as the card flies. Tap it again, or beside it, and it flies back. `HeroHereShuttles.flip()` turns the card over in flight, and its heroes run their flights on a `SpringSimulation`.

<img src="https://github.com/igorkurilenko/hero_here/blob/main/assets/hero_here_flip_card.webp?raw=true"
  alt="A tapped photo flies to the middle on a bouncy spring, flipping over to show the mountain's name and description" width="180"/>

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
- To move one widget's position to wherever a rebuild lays it out, in a layout animation of one widget, local_hero and animated_to animate its position, with no second widget.
- hero_here flies between two widgets that share a tag, as `Hero` does, to animate between two widgets that may look different, such as a thumbnail and a full photo, and a shuttle, such as a crossfade or a flip, can blend them in flight.

## FAQ

### Why doesn't `Hero` animate when I call `setState`?

`Hero` flies only during a route's transition, when the `Navigator` pushes or pops a route, so on `setState`, a hero animation is not working by design: a rebuild of the page you're on shows the widget in its new place at once. To fly it there, wrap that part of the page in a `HeroHereSwitcher` and use `HeroHere` in place of `Hero`.

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

Yes, a shared element transition within one page. It's the idea behind SwiftUI's `matchedGeometryEffect`, Jetpack Compose's shared elements and Framer Motion's `layoutId`: two views share an id, and a change from one to the other animates.

## Redirected flights

When the switcher's child changes again while a hero flies, the hero's flight changes course, as the heroes' `flightRedirect` says:

| `HeroHereFlightRedirect` | The flight |
|---|---|
| `chain`, the default | Lands on the hero it was flying to, then flies on to the new one. |
| `divert` | Flies from where the shuttle is to the new hero, turning toward it at the speed the shuttle had. |
| `restart` | Flies from where the shuttle is to the new hero, setting off from rest, as a flight from a hero there would. |

```dart
HeroHere(
  key: ValueKey(slot),
  tag: 'avatar',
  flightRedirect: HeroHereFlightRedirect.divert,
  child: avatar,
)
```

A flight that diverts or restarts takes its whole duration to get to the new hero. Its shuttle's `fromHero` becomes a stand-in for the shuttle as it was, so a shuttle that fades `fromHero` into `toHero` fades from what it showed.

With `chain`, a flight sent back to the hero it left turns back from where it is. With `divert`, it swings around to that hero, as to any hero behind it. With `restart`, it sets off back to that hero from rest.

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

`HeroHereSwitcher` puts the layer its flights fly in, its sky, over its child in a `Stack`, in a transparent `Material`. The material gives them a default text style and a surface for ink, but paints no background, so what's behind the switcher shows through. For shuttles that fly under the child, such as a segmented control's thumb under its labels, set `layoutBuilder: HeroHereSwitcher.skyUnderLayoutBuilder`. It's the same as the default, but with the sky under the child.

To lay them out yourself, set `layoutBuilder` to a builder of your own. Lay the sky out after the child: after it in the stack, or positioned in it, since a stack lays out its positioned children last. Then on each frame, such as on a window resize, flights find their heroes where that frame's layout puts them.

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
