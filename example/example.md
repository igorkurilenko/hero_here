<h1 align="center">Flutter hero animation example</h1>

<p align="center">This Flutter hero animation example is the flippers example from Flutter's <a href="https://docs.flutter.dev/ui/animations/hero-animations">hero animations guide</a>, on the same page: tap the photo, and it flies from the middle of the page into its corner, without navigation, as a hero widget flies between routes.<sup>1</sup> Tap it again, and it flies back.</p>

<p align="center">
  <a href="#take-a-closer-look">See the flippers code ›</a>&emsp;<a href="https://pub.dev/packages/hero_here/install">Install hero_here ›</a>
</p>

<p align="center">
  <img src="https://github.com/igorkurilenko/hero_here/blob/main/assets/hero_here_flippers.webp?raw=true"
    alt="Flutter hero animation example: the flippers photo flies from the middle of the page into its corner, and back, without navigation" width="300"/>
</p>

## Get the highlights.

- **No route.** The photo flies within the page, as the page changes its state. Nothing is pushed or popped.
- **Two places. One tag.** The photo is a `HeroHere` in the middle of the page and another in its corner, both tagged `'flippers'`.
- **Back again.** Tap the photo in the corner, and it flies back to the middle.
- **As in the guide.** The same photo and sizes as in Flutter's hero animations guide, without its second route.

## Take a closer look.

Three steps, all in one `build` method:

1. **The switcher.** A `HeroHereSwitcher` wraps the page's body.
2. **The heroes.** The photo is a `HeroHere`: 300 wide in the middle of the page, or 100 wide in its corner. Both have the tag `'flippers'`, and each has a key of its own.
3. **The change.** A tap moves the photo to the other place, and the switcher flies it there.

```dart
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
```

## More ways to use hero_here.

Seven more Flutter hero animation examples, each a pattern apps often need, built with a `HeroHereSwitcher` and its heroes, and each recorded as it runs.<sup>2</sup> They're code to learn from and copy, not widgets to import. Run one from the repository's [example folder](https://github.com/igorkurilenko/hero_here/tree/main/example/lib), such as with `flutter run -t lib/add_to_cart_hero/main.dart`. In each, `main.dart` places the heroes, and a file beside it draws the rest.

### Flip card animation

Tap a card in a grid, and it flies to the middle of the screen on a bouncy spring, turning over in a card flip animation to show its back, like a flash card. `HeroHereShuttles.flip` turns it over in flight. Tap it again, or beside it, and it flies back to the grid. [See the flip card code ›](https://github.com/igorkurilenko/hero_here/tree/main/example/lib/flip_card_hero)

<p align="center">
  <img src="https://github.com/igorkurilenko/hero_here/blob/main/assets/hero_here_flip_card.webp?raw=true"
    alt="Flip card animation: a tapped card flies to the middle on a bouncy spring and flips over to show its back" width="240"/>
</p>

### Pinterest-style image details

A shared element transition from a Pinterest-style grid: tap an image, and it opens into its details, with its title and description flying along, as in a container transform or an open container animation, but with no route. Pull the image down, and this card expand animation runs back into the grid, the image as fast as the pull let go. [See the image details code ›](https://github.com/igorkurilenko/hero_here/tree/main/example/lib/show_details_hero)

<p align="center">
  <img src="https://github.com/igorkurilenko/hero_here/blob/main/assets/hero_here_show_details.webp?raw=true"
    alt="Pinterest-style shared element transition: a tapped image opens into its details, and back on a pull" width="240"/>
</p>

### Add to cart animation

Tap add to cart, and the product's image flies from its card into the cart, landing on a soft spring,<sup>3</sup> as in an e-commerce app. Remove it, and it flies back, as the items after it in the cart slide along. Each product's image is a `HeroHere` on its card or in the cart, with the product's name as its tag in both places. Its position in the cart is part of its key there, so when one item leaves, the ones after it fly along. [See the add to cart code ›](https://github.com/igorkurilenko/hero_here/tree/main/example/lib/add_to_cart_hero)

<p align="center">
  <img src="https://github.com/igorkurilenko/hero_here/blob/main/assets/hero_here_add_to_cart.webp?raw=true"
    alt="Flutter add to cart animation: a product's image flies from its card into the cart, and back" width="240"/>
</p>

### Splash screen animation

Once the app has loaded, the logo and the app name fly from the middle of the splash screen into the app bar, landing on a soft spring: an animated splash screen with a logo animation, on the same page as the content, with no route of its own. The name scales with `HeroHereShuttles.scale` rather than laying out anew, so its text doesn't reflow in flight. [See the splash screen code ›](https://github.com/igorkurilenko/hero_here/tree/main/example/lib/splash_logo_hero)

<p align="center">
  <img src="https://github.com/igorkurilenko/hero_here/blob/main/assets/hero_here_splash_logo.webp?raw=true"
    alt="Splash screen logo animation: the logo and the app name fly into the app bar once the app has loaded" width="240"/>
</p>

### Animated bottom navigation bar

An animated bottom navigation bar: tap a tab, and its sliding indicator flies there under the icons, in a bottom navigation bar animation with no offsets to compute. The indicator is a `HeroHere` on the selected tab, and `HeroHereSwitcher.skyUnderLayoutBuilder` flies it under the icons. Tap another tab before it lands, and it starts over toward that one from where it is, with `HeroHereFlightRedirect.restart`. [See the navigation bar code ›](https://github.com/igorkurilenko/hero_here/tree/main/example/lib/navigation_bar_hero)

<p align="center">
  <img src="https://github.com/igorkurilenko/hero_here/blob/main/assets/hero_here_navigation_bar.webp?raw=true"
    alt="Animated bottom navigation bar: the sliding indicator flies to the tapped tab, and starts over toward another tab tapped mid-flight" width="240"/>
</p>

### Sliding segmented control

A sliding segmented control, or animated toggle switch, for any number of options: the thumb slides under the labels to the tapped segment, as in the Cupertino sliding segmented control, but built from your own widgets. The thumb is a `HeroHere` in the selected segment, which `HeroHereSwitcher.skyUnderLayoutBuilder` flies under the labels. A tap mid-flight starts it over from where it is, with `HeroHereFlightRedirect.restart`. [See the segmented control code ›](https://github.com/igorkurilenko/hero_here/tree/main/example/lib/segmented_control_hero)

<p align="center">
  <img src="https://github.com/igorkurilenko/hero_here/blob/main/assets/hero_here_segmented_control.webp?raw=true"
    alt="Sliding segmented control: the thumb slides under the labels to the tapped segment" width="240"/>
</p>

### Chat message animation

Send a message, and it flies from the text field up into the conversation, landing on a soft spring, as in messaging apps: a chat message animation for any chat UI. The spring is set on the message's hero in the conversation only, since a flight takes its options from the hero it flies to. [See the chat message code ›](https://github.com/igorkurilenko/hero_here/tree/main/example/lib/chat_message_hero)

<p align="center">
  <img src="https://github.com/igorkurilenko/hero_here/blob/main/assets/hero_here_chat_message.webp?raw=true"
    alt="Chat message animation: sent messages fly from the text field up into the conversation" width="240"/>
</p>

## Questions? Answers.

<details>
<summary><b>How do I make an add to cart animation in Flutter?</b></summary>

Wrap the page in a `HeroHereSwitcher`, and show each product's picture as a `HeroHere` where it is: on its card, or in the cart. Give it the same tag in both places, and a key of its own in each. Then add the product to the cart in `setState`, and the picture flies from its card to the cart, as in the [add to cart example](https://github.com/igorkurilenko/hero_here/tree/main/example/lib/add_to_cart_hero).

</details>

<details>
<summary><b>Why doesn't my widget fly?</b></summary>

When a hero animation is not working, check two things. Its old and its new place both need a `HeroHere` with the same tag, in the same `HeroHereSwitcher`. And each needs a key of its own: a hero with the same key is the same hero, which shows where it is now rather than flying there.

</details>

<details>
<summary><b>What if the user taps again mid-flight?</b></summary>

The flight changes course, as its heroes' `flightRedirect` says. With `chain`, the default, it lands first, then flies on. With `divert`, it turns toward the new place at the speed it had. With `restart`, it starts over toward it from where it is, as the navigation bar's indicator does.

</details>

<details>
<summary><b>Can a hero fly under other widgets?</b></summary>

Yes. Set the switcher's `layoutBuilder` to `HeroHereSwitcher.skyUnderLayoutBuilder`, and its heroes fly under its child, as the segmented control's thumb flies under the labels.

</details>

<p><small>1. The flippers photo is from Flutter's hero animations guide, in the flutter/website repository, used under its license.<br>
2. Recorded from the examples frame by frame, at 60 fps, in an iPhone 15 frame.<br>
3. The soft spring is <code>SpringDescription.withDurationAndBounce</code>, at 500 ms with a bounce of 0.25, in <code>lib/style/motion.dart</code>.</small></p>
