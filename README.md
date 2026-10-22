<h1 align="center">hero_here: Hero animations on the same page</h1>

<p align="center">Like Flutter's <code>Hero</code>, but with no <code>Navigator</code> and no routes.</p>

<p align="center">
  <a href="#quick-start">Get started ›</a>&emsp;<a href="https://pub.dev/packages/hero_here/example">See the examples ›</a>
</p>

hero_here is a Flutter package for a hero animation on the same page, or the same screen: a hero transition without navigation. Flutter's `Hero` widget flies a widget to its place on a new route, as the `Navigator` pushes or pops it. When the page you're on changes instead, such as when a tab is selected, a product goes into the cart, a grid item opens into its details in place, or a sent message joins the chat, the widget just jumps to its new place. hero_here makes it fly there: as with `Hero`, give its old and new places the same tag, then change state.

## Flutter hero animation examples

<table>
  <tr>
    <td align="center" valign="top" width="50%">
      <img src="https://github.com/igorkurilenko/hero_here/blob/main/assets/hero_here_flip_card.webp?raw=true"
        alt="Flip card animation: a tapped card flies to the middle on a bouncy spring and flips over to show its back" width="220"/>
      <p><b>Flip card animation</b></p>
      <p>Tap a card in a grid, and it flies to the middle of the screen on a bouncy spring, turning over in a card flip animation to show its back, like a flash card. Tap it again, and it flies back to the grid. <a href="https://github.com/igorkurilenko/hero_here/tree/main/example/lib/flip_card_hero">See the code ›</a></p>
    </td>
    <td align="center" valign="top" width="50%">
      <img src="https://github.com/igorkurilenko/hero_here/blob/main/assets/hero_here_show_details.webp?raw=true"
        alt="Pinterest-style shared element transition on the same screen: a tapped image opens into its details, and back on a pull" width="220"/>
      <p><b>Pinterest-style image details</b></p>
      <p>A shared element transition from a Pinterest-style grid: tap an image, and it opens into its details, with its title and description flying along, as in a container transform or an open container animation, but with no route. Pull the image down, and this card expand animation runs back into the grid. <a href="https://github.com/igorkurilenko/hero_here/tree/main/example/lib/show_details_hero">See the code ›</a></p>
    </td>
  </tr>
  <tr>
    <td align="center" valign="top" width="50%">
      <img src="https://github.com/igorkurilenko/hero_here/blob/main/assets/hero_here_add_to_cart.webp?raw=true"
        alt="Flutter add to cart animation: a product's image flies from its card into the cart, and back" width="220"/>
      <p><b>Add to cart animation</b></p>
      <p>Tap add to cart, and the product's image lifts off its card and flies into the cart, landing on a soft spring, as in an e-commerce app. Remove it, and it flies back, as the items after it in the cart slide along. <a href="https://github.com/igorkurilenko/hero_here/tree/main/example/lib/add_to_cart_hero">See the code ›</a></p>
    </td>
    <td align="center" valign="top" width="50%">
      <img src="https://github.com/igorkurilenko/hero_here/blob/main/assets/hero_here_splash_logo.webp?raw=true"
        alt="Splash screen logo animation: the logo and the app name fly into the app bar once the app has loaded" width="220"/>
      <p><b>Splash screen animation</b></p>
      <p>Once the app has loaded, the logo and the app name fly from the middle of the splash screen into the app bar, landing on a soft spring: an animated splash screen with a logo animation, on the same page as the content, with no route of its own. <a href="https://github.com/igorkurilenko/hero_here/tree/main/example/lib/splash_logo_hero">See the code ›</a></p>
    </td>
  </tr>
  <tr>
    <td align="center" valign="top" width="50%">
      <img src="https://github.com/igorkurilenko/hero_here/blob/main/assets/hero_here_navigation_bar.webp?raw=true"
        alt="Animated bottom navigation bar: the sliding indicator flies to the tapped tab" width="220"/>
      <p><b>Animated bottom navigation bar</b></p>
      <p>Tap a tab, and its sliding indicator flies there under the icons, in a bottom navigation bar animation with no offsets to compute. Tap another before it lands, and it starts over toward that one from where it is. <a href="https://github.com/igorkurilenko/hero_here/tree/main/example/lib/navigation_bar_hero">See the code ›</a></p>
    </td>
    <td align="center" valign="top" width="50%">
      <img src="https://github.com/igorkurilenko/hero_here/blob/main/assets/hero_here_segmented_control.webp?raw=true"
        alt="Sliding segmented control: the thumb slides under the labels to the tapped segment" width="220"/>
      <p><b>Sliding segmented control</b></p>
      <p>A sliding segmented control, or animated toggle switch, for any number of options: the thumb slides under the labels to the tapped segment, as in the Cupertino sliding segmented control, but built from your own widgets. <a href="https://github.com/igorkurilenko/hero_here/tree/main/example/lib/segmented_control_hero">See the code ›</a></p>
    </td>
  </tr>
  <tr>
    <td align="center" valign="top" colspan="2">
      <img src="https://github.com/igorkurilenko/hero_here/blob/main/assets/hero_here_chat_message.webp?raw=true"
        alt="Chat message animation: sent messages fly from the text field up into the conversation" width="220"/>
      <p><b>Chat message animation</b></p>
      <p>Send a message, and it flies from the text field up into the conversation, landing on a soft spring, as in messaging apps: a chat message animation for any chat UI. <a href="https://github.com/igorkurilenko/hero_here/tree/main/example/lib/chat_message_hero">See the code ›</a></p>
    </td>
  </tr>
</table>

## Get the highlights.

- **Same page.** Hero transitions within one page, with no `Navigator` or routes.
- **Two widgets.** `HeroHereSwitcher` and `HeroHere` work like `AnimatedSwitcher` and `Hero`.
- **Custom flights.** Custom hero animations: a flight's duration, curve, path and shuttle, and what drives it, such as a spring.
- **Changes of course.** A flight whose hero changes mid-flight lands on each hero in turn, turns toward the new one at the speed it had, or starts over toward it from where it is.
- **Ready-made shuttles.** A crossfade, a flip like a card's, and a scale that keeps text from reflowing in flight.
- **Moving heroes.** Flights follow their heroes as they move, such as on a scroll or a window resize.
- **Every platform.** Android, iOS, web, macOS, Windows and Linux. Wasm-ready, with no dependencies beyond Flutter.

## Quick start

**1. Install.** Add hero_here to your `pubspec.yaml`:

```yaml
dependencies:
  hero_here: ^2.3.5
```

**2. Tag the places.** Wrap the part of the page whose widgets move in a `HeroHereSwitcher`. Put a `HeroHere` in each place the widget may be, with the same tag and a key of its own. Here it's the flippers photo from Flutter's [hero animations guide](https://docs.flutter.dev/ui/animations/hero-animations), in the middle of the page or in its corner:

```dart
HeroHereSwitcher(
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
)
```

**3. Change state.** Change `_inCorner`, a field of your `State`, such as on a tap, and the photo flies there from where it was, on the same page, with no `Navigator.push`:

```dart
setState(() => _inCorner = !_inCorner);
```

A switch flies a tag when it brings a hero with that tag and another key. A hero with the same key is the same hero: it shows where it is now, and nothing flies.

The [Example tab](https://pub.dev/packages/hero_here/example) has this Flutter hero animation example as a whole app, and the repository's [example folder](https://github.com/igorkurilenko/hero_here/tree/main/example/lib) has the [examples above](#flutter-hero-animation-examples). Each is a hero widget example of a pattern apps often need.

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

## Questions? Answers.

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
  key: const ValueKey('corner'),
  tag: 'flippers',
  flightAnimationDuration: const Duration(milliseconds: 600),
  flightAnimationFactory: (controller) =>
      CurvedAnimation(parent: controller, curve: Curves.easeOutBack),
  child: Image.asset('images/flippers.png'),
)
```

For a spring, run the flight's controller on a `SpringSimulation` through `forwardFlightAnimation` and `reverseFlightAnimation`, as the examples' [`FlightSpring`](https://github.com/igorkurilenko/hero_here/blob/main/example/lib/style/motion.dart) does: its `softSpring` and `bouncySpring` each give a hero all four options it needs.

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
  key: ValueKey(place),
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

## Contributing

Contributions are welcome! Feel free to submit pull requests on [GitHub](https://github.com/igorkurilenko/hero_here) to help improve **hero_here**.
