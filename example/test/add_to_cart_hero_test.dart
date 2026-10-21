import 'dart:math' as math;

import 'package:example/add_to_cart_hero/main.dart';
import 'package:example/add_to_cart_hero/shop.dart';
import 'package:example/style/style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'flight_helpers.dart';

void main() {
  final headphones = kProducts[0];
  final camera = kProducts[1];
  final watch = kProducts[2];

  testWidgets('flies a product\'s picture from its card into the cart, and '
      'keeps the card\'s place for it', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AddToCartExample()));
    final productCard = find.widgetWithText(ProductCard, camera.name);
    final cardRect = tester.getRect(productCard);
    final card = tester.getRect(find.byKey(const ValueKey('card-Camera')));

    await startFlight(tester, _buttonOf(camera));
    await tester.pump(midFlight);

    // Only the picture in flight, on its way down: none on the card.
    final pictures = _pictures(tester, camera);
    expect(pictures, hasLength(1));
    expect(pictures.single.dy, greaterThan(card.center.dy + 50));

    await tester.pumpAndSettle();
    final inCart = find.byKey(const ValueKey('cart-Camera-0'));
    expect(tester.getSize(inCart), const Size.square(kCartPictureExtent));
    expect(_pictures(tester, camera), [tester.getCenter(inCart)]);
    // The card keeps its place, and its size.
    expect(tester.getRect(productCard), cardRect);
    // The card's price, and the cart's total.
    expect(find.text('\$${camera.price}'), findsNWidgets(2));
  });

  testWidgets('flies a product back to its card, and the ones after it along '
      'the cart', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AddToCartExample()));
    await tester.tap(_buttonOf(headphones));
    await tester.pumpAndSettle();
    await tester.tap(_buttonOf(watch));
    await tester.pumpAndSettle();
    final first = tester.getCenter(
      find.byKey(const ValueKey('cart-Headphones-0')),
    );
    final second = tester.getCenter(find.byKey(const ValueKey('cart-Watch-1')));

    await startFlight(tester, find.byKey(const ValueKey('cart-Headphones-0')));
    await tester.pump(midFlight);

    // The watch's picture slides along the cart, a place to the left.
    final sliding = _pictures(
      tester,
      watch,
    ).where((at) => (at.dy - second.dy).abs() < .5);
    expect(sliding, hasLength(1));
    expect(sliding.single.dx, lessThan(second.dx - 10));
    expect(sliding.single.dx, greaterThan(first.dx + 10));

    await tester.pumpAndSettle();
    expect(tester.getCenter(find.byKey(const ValueKey('cart-Watch-0'))), first);
    expect(find.byKey(const ValueKey('card-Headphones')), findsOneWidget);
  });

  testWidgets('keeps the cart\'s height as products come and go', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: exampleTheme, home: const AddToCartExample()),
    );
    final empty = tester.getRect(find.byType(CartBar));

    await tester.tap(_buttonOf(camera));
    await tester.pumpAndSettle();

    expect(tester.getRect(find.byType(CartBar)), empty);
  });

  testWidgets('lands a product\'s picture in the cart on a soft spring, a '
      'little past its place and back', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AddToCartExample()));
    await startFlight(tester, _buttonOf(camera));

    // How low the picture goes, on each frame.
    final lows = await pumpFrames(
      tester,
      60,
      () => _pictures(tester, camera).map((at) => at.dy).reduce(math.max),
    );

    final landed = tester.getCenter(
      find.byKey(const ValueKey('cart-Camera-0')),
    );
    expect(lows.reduce(math.max), greaterThan(landed.dy + 1));
  });
}

/// The add, or remove, button on [product]'s card.
Finder _buttonOf(Product product) => find.descendant(
  of: find.ancestor(of: find.text(product.name), matching: find.byType(Card)),
  matching: find.byType(IconButton),
);

/// Where [product]'s pictures show: on its card, in the cart or in flight.
List<Offset> _pictures(WidgetTester tester, Product product) => [
  for (final rect in rectsOf(
    tester,
    find.byWidgetPredicate(
      (widget) => widget is Unicon && widget.data == product.icon,
    ),
  ))
    rect.center,
];
