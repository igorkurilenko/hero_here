<h1 align="center">Flutter hero animation example</h1>

<p align="center">This Flutter hero animation example is an add to cart animation on the same page. Tap a product's button, and its picture, a hero widget, flies into the cart without navigation, where it lands on a soft spring.<sup>1</sup> Tap it in the cart, and it flies back.</p>

<p align="center">
  <a href="#take-a-closer-look">See the add to cart code ›</a>&emsp;<a href="https://pub.dev/packages/hero_here/install">Install hero_here ›</a>
</p>

<p align="center">
  <img src="https://github.com/igorkurilenko/hero_here/blob/main/assets/hero_here_add_to_cart.webp?raw=true"
    alt="Flutter add to cart animation: a product's picture flies from its card into the cart, and back" width="300"/>
</p>

## Get the highlights.

- **No route.** The picture flies within the page, as the page changes its state. Nothing is pushed or popped.
- **Two places. One tag.** The picture is a `HeroHere` on its card and another in the cart, both tagged with the product's name.
- **Soft landing.** It lands on a soft spring, with a little bounce.
- **Room to move.** Take one out, and the pictures after it fly along to close the gap.
- **Back again.** Tap a picture in the cart, and it flies back to its card.

## Take a closer look.

Three steps, all in one `build` method:

1. **The switcher.** A `HeroHereSwitcher` wraps the page.
2. **The heroes.** Each product's picture is a `HeroHere`: on its card while the product is out of the cart, and in the cart while it's in. Both have the product's name as their tag, and each has a key of its own. A picture's position in the cart is part of its key, so when one leaves, the ones after it fly along.
3. **The change.** A tap adds the product to the cart, or takes it out, and the switcher flies each picture whose place changed.

```dart
import 'package:flutter/material.dart';
import 'package:hero_here/hero_here.dart';

import 'add_to_cart/shop.dart';
import 'style/style.dart';

void main() => runApp(
  MaterialApp(
    title: 'HeroHere Example',
    debugShowCheckedModeBanner: false,
    theme: exampleTheme,
    home: const AddToCartExample(),
  ),
);

/// A shop whose products' pictures fly into the cart, and back, within the
/// page:
///
/// 1. A [HeroHereSwitcher] wraps the page.
/// 2. Each product's picture is a [HeroHere], on its card or in the cart:
///    with the product's name as its tag, and a key of its own in each place.
/// 3. Adding a product to the cart, or taking it out, moves its hero, and
///    the switcher flies the picture there.
class AddToCartExample extends StatefulWidget {
  const AddToCartExample({super.key});

  @override
  State<AddToCartExample> createState() => _AddToCartExampleState();
}

class _AddToCartExampleState extends State<AddToCartExample> {
  final _cart = <Product>[];

  @override
  Widget build(BuildContext context) => HeroHereSwitcher(
    // 1. The switcher.
    child: Scaffold(
      appBar: AppBar(title: const Text('Shop')),
      body: ProductGrid(
        children: [
          for (final product in kProducts)
            ProductCard(
              product,
              inCart: _cart.contains(product),
              // 3. Adds the product to the cart, or takes it out.
              onToggle: () => _toggle(product),
              // 2. The product's picture on its card, while it's out of the
              // cart. In the cart, the card keeps its place, empty.
              picture: _cart.contains(product)
                  ? null
                  : HeroHere(
                      key: ValueKey('card-${product.name}'),
                      tag: product.name,
                      // Lands on a soft spring.
                      flightAnimationControllerFactory: softSpring.controller,
                      flightAnimationFactory: softSpring.animation,
                      forwardFlightAnimation: softSpring.forward,
                      reverseFlightAnimation: softSpring.reverse,
                      child: ProductPicture(product),
                    ),
            ),
        ],
      ),
      bottomNavigationBar: CartBar(
        total: _total,
        children: [
          for (final (position, product) in _cart.indexed)
            CartItem(
              // 3. A tap takes the product out of the cart.
              onTap: () => _toggle(product),
              // 2. The product's picture in the cart, while it's in: the same
              // tag as on its card, with another key. With its position in
              // the key, it flies along when one before it leaves the cart,
              // as a hero with a new key flies.
              picture: HeroHere(
                key: ValueKey('cart-${product.name}-$position'),
                tag: product.name,
                // Lands on a soft spring.
                flightAnimationControllerFactory: softSpring.controller,
                flightAnimationFactory: softSpring.animation,
                forwardFlightAnimation: softSpring.forward,
                reverseFlightAnimation: softSpring.reverse,
                child: ProductPicture(product),
              ),
            ),
        ],
      ),
    ),
  );

  int get _total => _cart.fold(0, (total, product) => total + product.price);

  void _toggle(Product product) => setState(
    () => _cart.contains(product) ? _cart.remove(product) : _cart.add(product),
  );
}
```

## Find the hero animation that suits you best.

Six more Flutter hero animation examples, each a widget that apps need, and each recorded as it runs.<sup>2</sup> Run one from the repository's [example folder](https://github.com/igorkurilenko/hero_here/tree/main/example/lib), such as with `flutter run -t lib/navigation_bar_hero/main.dart`. In each, `main.dart` places the heroes, and a file beside it draws the rest.

### Animated bottom navigation bar

An animated bottom navigation bar with a sliding indicator, in a bottom navigation bar animation with no offsets to compute. Tap a tab, and the indicator flies to it, under the icons, with `HeroHereSwitcher.skyUnderLayoutBuilder`. Tap another before it lands, and it starts over toward that one from where it is, with `HeroHereFlightRedirect.restart`. [See the navigation bar code ›](https://github.com/igorkurilenko/hero_here/tree/main/example/lib/navigation_bar_hero)

<p align="center">
  <img src="https://github.com/igorkurilenko/hero_here/blob/main/assets/hero_here_navigation_bar.webp?raw=true"
    alt="Animated bottom navigation bar: the sliding indicator flies to the tapped tab, and starts over toward Home mid-flight" width="240"/>
</p>

### Sliding segmented control

A sliding segmented control that works as an animated toggle switch with three options: Day, Week and Month. Tap one, and the thumb flies to it, under the labels, with `HeroHereSwitcher.skyUnderLayoutBuilder`, as the chart's bars grow and shrink and the steps count to the period's total. Tap another mid-flight, and it turns toward that one at the speed it had, with `HeroHereFlightRedirect.divert`. [See the segmented control code ›](https://github.com/igorkurilenko/hero_here/tree/main/example/lib/segmented_control_hero)

<p align="center">
  <img src="https://github.com/igorkurilenko/hero_here/blob/main/assets/hero_here_segmented_control.webp?raw=true"
    alt="Sliding segmented control: the thumb flies to the tapped period as the chart's bars grow and shrink" width="240"/>
</p>

### Splash screen animation

A splash screen animation on the same page, with no route of its own. Once the app has loaded, the logo and the name fly from the middle of the animated splash screen into the app bar, landing on a soft spring as the content fades in. In this logo animation, the name scales with `HeroHereShuttles.scale` rather than laying out anew, so its text doesn't reflow in flight. [See the splash screen code ›](https://github.com/igorkurilenko/hero_here/tree/main/example/lib/splash_logo_hero)

<p align="center">
  <img src="https://github.com/igorkurilenko/hero_here/blob/main/assets/hero_here_splash_logo.webp?raw=true"
    alt="Splash screen animation: the logo and the name fly into the app bar once the app has loaded" width="240"/>
</p>

### Chat message animation

A chat message animation: send a message, and it flies from the text field up into the chat, where it lands on a soft spring. The spring is set on the message's hero in the chat only, since a flight takes its options from the hero it flies to. [See the chat message code ›](https://github.com/igorkurilenko/hero_here/tree/main/example/lib/chat_message_hero)

<p align="center">
  <img src="https://github.com/igorkurilenko/hero_here/blob/main/assets/hero_here_chat_message.webp?raw=true"
    alt="Chat message animation: sent messages fly from the text field up into the chat" width="240"/>
</p>

### Shared element transition

A shared element transition from a grid to details, as in a container transform or an open container animation, with no route. Tap a mountain, and its photo, name and description fly from the grid into its details, in a card expand animation. Pull the photo down, and they fly back, the photo as fast as the pull let go. [See the grid to details code ›](https://github.com/igorkurilenko/hero_here/tree/main/example/lib/show_details_hero)

<p align="center">
  <img src="https://github.com/igorkurilenko/hero_here/blob/main/assets/hero_here_show_details.webp?raw=true"
    alt="Shared element transition: a mountain's photo flies from the grid into its details, and back on a pull" width="240"/>
</p>

### Flip card animation

A flip card animation: tap a photo, and its card flies to the middle on a bouncy spring, in a card flip animation with `HeroHereShuttles.flip` that shows the mountain's name and description on the back. Tap it again, or beside it, and it flies back. [See the flip card code ›](https://github.com/igorkurilenko/hero_here/tree/main/example/lib/flip_card_hero)

<p align="center">
  <img src="https://github.com/igorkurilenko/hero_here/blob/main/assets/hero_here_flip_card.webp?raw=true"
    alt="Flip card animation: a tapped photo flies to the middle on a bouncy spring and flips over to show the mountain's name and description" width="240"/>
</p>

## Compare all examples.

Each example shows a few of hero_here's options. For what they do, see [Redirected flights](https://pub.dev/packages/hero_here#redirected-flights), [Shuttles](https://pub.dev/packages/hero_here#shuttles) and [Layout](https://pub.dev/packages/hero_here#layout).

| Example | What flies | Lands on | A change mid-flight | Shuttle | Flies |
|---|---|---|---|---|---|
| [Add to cart](https://github.com/igorkurilenko/hero_here/blob/main/example/lib/main.dart) | The product's picture | A soft spring | `chain` | Default | Over the page |
| [Navigation bar](https://github.com/igorkurilenko/hero_here/tree/main/example/lib/navigation_bar_hero) | The indicator | `easeInOut`, 300 ms | `restart` | Default | Under the icons |
| [Segmented control](https://github.com/igorkurilenko/hero_here/tree/main/example/lib/segmented_control_hero) | The thumb | `easeInOut`, 300 ms | `divert` | Default | Under the labels |
| [Splash screen](https://github.com/igorkurilenko/hero_here/tree/main/example/lib/splash_logo_hero) | The logo and the name | A soft spring | `chain` | `scale`, for the name | Over the page |
| [Chat message](https://github.com/igorkurilenko/hero_here/tree/main/example/lib/chat_message_hero) | The sent message | A soft spring | `chain` | Default | Over the page |
| [Grid to details](https://github.com/igorkurilenko/hero_here/tree/main/example/lib/show_details_hero) | The photo, name and description | `easeInOut`, or the pull's fling | `chain` | Custom | Over the page |
| [Flip card](https://github.com/igorkurilenko/hero_here/tree/main/example/lib/flip_card_hero) | The card | A bouncy spring | `chain` | `flip` | Over the page |

## Questions? Answers.

<details>
<summary><b>How do I make an add to cart animation in Flutter?</b></summary>

Wrap the page in a `HeroHereSwitcher`, and show each product's picture as a `HeroHere` where it is: on its card, or in the cart. Give it the same tag in both places, and a key of its own in each. Then add the product to the cart in `setState`, and the picture flies from its card to the cart, as in [the code above](#take-a-closer-look).

</details>

<details>
<summary><b>Why doesn't my picture fly?</b></summary>

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

<p><small>1. The soft spring is <code>SpringDescription.withDurationAndBounce</code>, at 500 ms with a bounce of 0.25, in <code>lib/style/motion.dart</code>.<br>
2. Recorded from the examples frame by frame, at 60 fps, in an iPhone 15 frame.</small></p>
