import 'dart:ui' as ui;

import 'package:example/show_details_hero/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('switches once to open the details', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ShowDetailsExample()));
    await tester.pumpAndSettle();

    // Each switch takes one snapshot of the page.
    final snapshots = _countNewImages();
    await tester.tap(find.text('K2'));
    await tester.pump();

    // The back button waits for the flight.
    final back = find.widgetWithIcon(IconButton, Icons.chevron_left);
    expect(tester.widget<IconButton>(back).onPressed, isNull);

    await tester.pumpAndSettle();

    expect(snapshots(), 1);
    expect(tester.widget<IconButton>(back).onPressed, isNotNull);
  });
}

/// Counts the `ui.Image`s created from now until the end of the test, leaving
/// out clones of them.
int Function() _countNewImages() {
  final images = <ui.Image>[];
  final onCreate = ui.Image.onCreate;
  ui.Image.onCreate = (image) {
    if (!images.any(image.isCloneOf)) images.add(image);
    onCreate?.call(image);
  };
  addTearDown(() => ui.Image.onCreate = onCreate);
  return () => images.length;
}
