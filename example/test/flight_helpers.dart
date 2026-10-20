// What the examples' flight tests share: a frame, a moment mid-flight, a
// tap that starts a flight, and where widgets are, frame after frame.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// A frame, at 60 frames a second.
const frame = Duration(milliseconds: 16);

/// A moment mid-flight: halfway through a flight of the default duration,
/// and partway through one on a spring.
const midFlight = Duration(milliseconds: 150);

/// Taps [target] and pumps until the flight it starts shows, from the frame
/// after the switch.
Future<void> startFlight(WidgetTester tester, Finder target) async {
  await tester.tap(target);
  await tester.pump();
  await tester.pump();
}

/// Where each widget [finder] finds is, such as a hero's child in its place
/// and its shuttle's in flight.
List<Rect> rectsOf(WidgetTester tester, Finder finder) => [
  for (final element in finder.evaluate())
    tester.getRect(find.byElementPredicate((each) => each == element)),
];

/// Pumps [count] frames, and returns what [measure] gives after each.
Future<List<T>> pumpFrames<T>(
  WidgetTester tester,
  int count,
  T Function() measure,
) async {
  final measures = <T>[];
  for (var i = 0; i < count; i++) {
    await tester.pump(frame);
    measures.add(measure());
  }
  return measures;
}
