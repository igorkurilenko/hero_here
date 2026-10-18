// Measures how long the frames of the examples' flights take on a device.
// See README.md for how to run it.

import 'package:example/basic_with_auto_switching/main.dart' as auto;
import 'package:example/chat_message_hero/main.dart' as chat;
import 'package:example/show_details_hero/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // The engine draws the frames, as in an app.
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets(
    'frame times',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ShowDetailsExample()));
      await _wait(1500);
      // Decodes the photo the details show before measuring.
      await _openAndCloseDetails(tester);
      await _measure(binding, tester, 'details', () async {
        for (var i = 0; i < 5; i++) {
          await _openAndCloseDetails(tester);
        }
      });

      await tester.pumpWidget(const MaterialApp(home: chat.HeroHereExample()));
      await _wait(1000);
      await _measure(binding, tester, 'chat', () async {
        for (var i = 0; i < 10; i++) {
          await tester.enterText(find.byType(TextField), 'Message $i');
          await tester.testTextInput.receiveAction(TextInputAction.done);
          await _wait(600);
        }
      });

      await tester.pumpWidget(const MaterialApp(home: auto.HeroHereExample()));
      await _wait(1000);
      // The play button, then a button for each hero.
      final buttons = find.descendant(
        of: find.byType(BottomAppBar),
        matching: find.byType(IconButton),
      );
      await _measure(binding, tester, 'switches', () async {
        for (var i = 0; i < 12; i++) {
          await tester.tap(buttons.at(1 + (i + 1) % 3));
          // Every other tap comes mid-flight, so the flight changes course.
          await _wait(i.isEven ? 150 : 600);
        }
      });
    },
    // Semantics run only under an assistive technology, which most users
    // don't have on. --dart-define=SEMANTICS=true measures as under one.
    semanticsEnabled: const bool.fromEnvironment('SEMANTICS'),
  );
}

/// Records the frame times of [action] as [scenario], and fails it if
/// anything threw.
Future<void> _measure(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
  String scenario,
  Future<void> Function() action,
) async {
  await binding.watchPerformance(action, reportKey: scenario);
  expect(tester.takeException(), isNull, reason: scenario);
}

/// Opens K2's details, then closes them with the back button once they've
/// flown open.
Future<void> _openAndCloseDetails(WidgetTester tester) async {
  await tester.tap(find.text('K2').first);
  await _wait(900);
  await tester.tap(find.byIcon(Icons.chevron_left));
  await _wait(900);
}

Future<void> _wait(int milliseconds) =>
    Future<void>.delayed(Duration(milliseconds: milliseconds));
