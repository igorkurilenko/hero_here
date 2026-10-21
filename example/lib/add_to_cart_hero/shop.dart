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

// What the add to cart example looks like, apart from its heroes, which
// main.dart places.

import 'package:flutter/material.dart';

import '../style/style.dart';

typedef Product = ({String name, int price, String icon, Color color});

/// The products of the shop.
const List<Product> kProducts = [
  (
    name: 'Headphones',
    price: 59,
    icon: UniconData.headphones,
    color: Color(0xFFFFE6C7),
  ),
  (
    name: 'Camera',
    price: 249,
    icon: UniconData.camera,
    color: Color(0xFFD9EED9),
  ),
  (name: 'Watch', price: 199, icon: UniconData.watch, color: Color(0xFFD6E6F5)),
  (name: 'Phone', price: 699, icon: UniconData.phone, color: Color(0xFFF5DCE4)),
];

/// The size of a product's picture in the cart.
const kCartPictureExtent = S.s9;

/// The products, in a grid of as many columns as fit.
class ProductGrid extends StatelessWidget {
  const ProductGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => GridView.extent(
    padding: const EdgeInsets.all(S.s4),
    maxCrossAxisExtent: 200,
    mainAxisSpacing: S.s4,
    crossAxisSpacing: S.s4,
    childAspectRatio: .75,
    children: children,
  );
}

/// A product in the shop: [picture], or its place while there's none, its
/// name and price, and a button that adds it to the cart, or takes it out.
class ProductCard extends StatelessWidget {
  const ProductCard(
    this.product, {
    super.key,
    this.picture,
    required this.inCart,
    required this.onToggle,
  });

  final Product product;
  final Widget? picture;
  final bool inCart;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(S.s2),
              child: picture ?? const SizedBox.expand(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(S.s3, 0, S.s2, S.s2),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.name, style: theme.textTheme.titleSmall),
                      Text(
                        '\$${product.price}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: inCart ? 'Remove from cart' : 'Add to cart',
                  onPressed: onToggle,
                  // In the cart, the accent; out of it, a neutral tint.
                  style: IconButton.styleFrom(
                    backgroundColor: inCart
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: .1),
                    foregroundColor: inCart
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurface,
                  ),
                  icon: Unicon(inCart ? UniconData.added : UniconData.add),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The cart, at the bottom of the shop: [children], the pictures of the
/// products in it, their [total] and a checkout button.
class CartBar extends StatelessWidget {
  const CartBar({super.key, required this.total, required this.children});

  final int total;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(S.s4),
              child: Row(
                children: [
                  Unicon(UniconData.bag, color: theme.colorScheme.onSurface),
                  G.w12,
                  Expanded(
                    // As tall with pictures as without, so the cart keeps
                    // its height as products come and go.
                    child: SizedBox(
                      height: kCartPictureExtent,
                      child: children.isEmpty
                          ? Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(
                                'Your cart is empty',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            )
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(spacing: S.s2, children: children),
                            ),
                    ),
                  ),
                  G.w12,
                  Text('\$$total', style: theme.textTheme.titleMedium),
                  G.w12,
                  FilledButton(
                    onPressed: children.isEmpty ? null : () {},
                    child: const Text('Checkout'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A product in the cart: its [picture], which a tap takes out of the cart.
class CartItem extends StatelessWidget {
  const CartItem({super.key, required this.onTap, required this.picture});

  final VoidCallback onTap;
  final Widget picture;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: SizedBox.square(dimension: kCartPictureExtent, child: picture),
  );
}

/// A product's picture: its icon on its color, at any size, so it shrinks
/// and grows as it flies between its card and the cart.
class ProductPicture extends StatelessWidget {
  const ProductPicture(this.product, {super.key});

  final Product product;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: ShapeDecoration(color: product.color, shape: squircle(R.lg)),
    child: Center(
      child: FractionallySizedBox(
        widthFactor: .5,
        heightFactor: .5,
        child: FittedBox(
          child: Unicon(
            product.icon,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    ),
  );
}
