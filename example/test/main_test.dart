import 'dart:io';
import 'dart:math' as math;

import 'package:example/add_to_cart/shop.dart';
import 'package:example/main.dart';
import 'package:example/style/style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

    await _startFlight(tester, _buttonOf(camera));
    await tester.pump(const Duration(milliseconds: 150));

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

    await _startFlight(tester, find.byKey(const ValueKey('cart-Headphones-0')));
    await tester.pump(const Duration(milliseconds: 150));

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
    await _startFlight(tester, _buttonOf(camera));

    var lowest = 0.0;
    for (var frame = 0; frame < 60; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      for (final at in _pictures(tester, camera)) {
        lowest = math.max(lowest, at.dy);
      }
    }

    final landed = tester.getCenter(
      find.byKey(const ValueKey('cart-Camera-0')),
    );
    expect(lowest, greaterThan(landed.dy + 1));
  });

  test('shows the code of lib/main.dart on its pub.dev page', () {
    // pub.dev shows example.md on the package's Example tab.
    final page = File('example.md').readAsStringSync();
    final code = RegExp(
      r'```dart\n(.*?)```',
      dotAll: true,
    ).firstMatch(page)?.group(1);
    final main = File('lib/main.dart').readAsStringSync();

    expect(code, main.substring(main.indexOf('import ')));
  });
}

/// The add, or remove, button on [product]'s card.
Finder _buttonOf(Product product) => find.descendant(
  of: find.ancestor(of: find.text(product.name), matching: find.byType(Card)),
  matching: find.byType(IconButton),
);

/// Where [product]'s pictures show: on its card, in the cart or in flight.
List<Offset> _pictures(WidgetTester tester, Product product) => [
  for (final element
      in find
          .byWidgetPredicate(
            (widget) => widget is Unicon && widget.data == product.icon,
          )
          .evaluate())
    tester.getCenter(find.byElementPredicate((each) => each == element)),
];

/// Taps [target] and pumps until the flight it starts shows, from the frame
/// after the switch.
Future<void> _startFlight(WidgetTester tester, Finder target) async {
  await tester.tap(target);
  await tester.pump();
  await tester.pump();
}
