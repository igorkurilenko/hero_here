// Copyright 2024 Igor Kurilenko
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

import '../style/style.dart';
import 'shop.dart';

void main() => runApp(
  MaterialApp(
    title: 'HeroHere Add to Cart Example',
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
                      // Lifted off the page as it flies.
                      flightShuttleBuilder: liftedPicture,
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
                // Lifted off the page as it flies.
                flightShuttleBuilder: liftedPicture,
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
