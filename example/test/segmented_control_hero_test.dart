import 'package:example/segmented_control_hero/activity.dart';
import 'package:example/segmented_control_hero/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'flight_helpers.dart';

void main() {
  testWidgets('flies the thumb to the tapped segment, as the chart\'s bars '
      'grow and shrink to its period\'s', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SegmentedControlExample()));
    final day = tester.getCenter(find.text('Day')).dx;
    final month = tester.getCenter(find.text('Month')).dx;
    expect(tester.getCenter(_thumb).dx, day);
    final firstBar = tester.getSize(_bars.first).height;

    await startFlight(tester, find.text('Month'));
    await tester.pump(midFlight);

    final halfway = tester.getCenter(_thumb).dx;
    expect(halfway, greaterThan(day + 50));
    expect(halfway, lessThan(month - 50));
    final counting = int.parse(
      tester.widget<Text>(_steps).data!.replaceAll(',', ''),
    );
    expect(counting, greaterThan(kPeriods.first.steps));
    expect(counting, lessThan(kPeriods.last.steps));
    final growing = tester.getSize(_bars.first).height;
    expect(growing, greaterThan(firstBar));
    expect(growing, lessThan(kChartHeight * kPeriods.last.bars.first.share));

    await tester.pumpAndSettle();
    expect(tester.getCenter(_thumb).dx, month);
    expect(
      tester.getSize(_bars.first).height,
      kChartHeight * kPeriods.last.bars.first.share,
    );
    expect(find.text('243,980'), findsOneWidget);
  });

  testWidgets('keeps the steps where they are as they change to another '
      'period\'s', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SegmentedControlExample()));
    final left = tester.getTopLeft(_steps).dx;

    for (final label in ['Week', 'Month', 'Day']) {
      await tester.tap(find.text(label));
      for (var i = 0; i < 30; i++) {
        await tester.pump(frame);
        for (final rect in rectsOf(tester, _steps)) {
          expect(rect.left, left, reason: 'On frame $i to $label');
        }
      }
    }
  });

  testWidgets('keeps the thumb on its way to its segment on the frame of a '
      'window resize', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SegmentedControlExample()));
    await startFlight(tester, find.text('Month'));
    await tester.pump(const Duration(milliseconds: 280));

    // A narrower window moves the segment the thumb flies to.
    tester.view.physicalSize = Size(
      tester.view.physicalSize.width / 2,
      tester.view.physicalSize.height,
    );
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pump(frame);

    // Placed by this frame's layout, though the sky lies under the segments,
    // rather than by the frame before's, when the segment was twice as far.
    expect(
      tester.getCenter(_thumb).dx,
      moreOrLessEquals(tester.getCenter(find.text('Month')).dx, epsilon: 1),
    );
  });
}

/// The thumb: under the selected segment's label, or in flight.
final _thumb = find.byType(SegmentThumb);

/// The chart's bars.
final _bars = find.byType(AnimatedContainer);

/// The steps walked in the selected period, or the steps of the period it
/// changes from or to.
final _steps = find.byWidgetPredicate(
  (widget) =>
      widget is Text &&
      RegExp(r'^[\d,]+$').hasMatch(widget.data ?? '') &&
      (widget.data ?? '').length > 2,
);
