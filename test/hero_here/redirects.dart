part of '../hero_here_test.dart';

/// Flights that change course: chained, turned back, diverted, restarted,
/// and on the frame they land, as on the web.
void _redirectsTests() {
  testWidgets('flies a redirected hero on from where its shuttle is', (
    tester,
  ) async {
    final slot = ValueNotifier(0);
    addTearDown(slot.dispose);

    await tester.pumpWidget(_SlotSwitcher(slot: slot));
    await tester.pumpAndSettle();

    slot.value = 1;
    await _pumpSwitch(tester);
    await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 2);

    // Redirect the flight to the third slot while it is between the first
    // two.
    slot.value = 2;
    await _pumpSwitch(tester);

    // Record the shuttle's left edge on each frame of the rest of the flight.
    final shuttle = find.byKey(_shuttleKey);
    final lefts = <double>[];
    for (var frame = 0; frame < 40; frame++) {
      if (tester.any(shuttle)) lefts.add(tester.getRect(shuttle).left);
      await tester.pump(_frame);
    }

    // The slots run left to right, so the shuttle only ever moves right: it
    // lands on the second slot, then flies on from there to the third.
    for (var i = 1; i < lefts.length; i++) {
      expect(lefts[i], greaterThanOrEqualTo(lefts[i - 1]), reason: '$lefts');
    }
    expect(shuttle, findsNothing);
    expect(find.byKey(const ValueKey('box2')), findsOneWidget);
  });

  testWidgets('flies on when its sky mounts anew mid-flight', (tester) async {
    final slot = ValueNotifier(0);
    addTearDown(slot.dispose);
    final wrapped = ValueNotifier(false);
    addTearDown(wrapped.dispose);

    await tester.pumpWidget(
      _SlotSwitcher(
        slot: slot,
        // Wrapping the sky in one more widget mounts it anew.
        layoutBuilder: (child, sky) => Stack(
          children: [
            child,
            ValueListenableBuilder(
              valueListenable: wrapped,
              builder: (context, wrapped, _) =>
                  wrapped ? KeyedSubtree(child: sky) : sky,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    slot.value = 1;
    await _pumpSwitch(tester);
    await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 4);

    wrapped.value = true;
    await tester.pump();

    // The flight lands on the second slot, then flies on to the third.
    slot.value = 2;
    await _pumpSwitch(tester);
    final shuttle = find.byKey(_shuttleKey);
    for (var frame = 0; frame < 40 && tester.any(shuttle); frame++) {
      await tester.pump(_frame);
    }

    expect(shuttle, findsNothing);
    expect(find.byKey(const ValueKey('box2')), findsOneWidget);
  });

  testWidgets('flies a hero back when its child changes back mid-flight', (
    tester,
  ) async {
    final slot = ValueNotifier(0);
    addTearDown(slot.dispose);

    await tester.pumpWidget(_SlotSwitcher(slot: slot));
    await tester.pumpAndSettle();

    slot.value = 1;
    await _pumpSwitch(tester);
    await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 2);

    slot.value = 0;
    await _pumpSwitch(tester);

    // A switch while it turns back, with the same child, changes nothing.
    tester.element(find.byType(HeroHereSwitcher)).markNeedsBuild();
    await _pumpSwitch(tester);

    // The shuttle turns back from where it is, so it only ever moves left.
    final shuttle = find.byKey(_shuttleKey);
    final lefts = <double>[];
    for (var frame = 0; frame < 40; frame++) {
      if (tester.any(shuttle)) lefts.add(tester.getRect(shuttle).left);
      await tester.pump(_frame);
    }

    expect(lefts, isNotEmpty);
    for (var i = 1; i < lefts.length; i++) {
      expect(lefts[i], lessThanOrEqualTo(lefts[i - 1]), reason: '$lefts');
    }
    // It takes as long as it flew, not a whole flight.
    expect(
      lefts.length * _frame.inMilliseconds,
      lessThan(HeroHere.defaultFlightAnimationDuration.inMilliseconds * 3 / 4),
    );
    expect(shuttle, findsNothing);
    expect(find.byKey(const ValueKey('box0')), findsOneWidget);
  });

  testWidgets('swings a diverted hero around to the hero it left', (
    tester,
  ) async {
    final slot = ValueNotifier(0);
    addTearDown(slot.dispose);

    await tester.pumpWidget(
      _SlotSwitcher(slot: slot, redirect: HeroHereFlightRedirect.divert),
    );
    await tester.pumpAndSettle();

    slot.value = 2;
    await _pumpSwitch(tester);
    await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 2);

    final shuttle = find.byKey(_shuttleKey);
    final leftBefore = tester.getRect(shuttle).left;
    await tester.pump(_frame);
    final rectAtTurn = tester.getRect(shuttle);
    final stepBefore = rectAtTurn.left - leftBefore;

    // Back to the first slot, straight behind the shuttle.
    slot.value = 0;
    await _pumpSwitch(tester);

    final rects = <Rect>[];
    for (var i = 0; i < 40 && tester.any(shuttle); i++) {
      await tester.pump(_frame);
      if (tester.any(shuttle)) rects.add(tester.getRect(shuttle));
    }

    // It carries on at the speed it had, swings out to the side and comes
    // around to the first slot, rather than doubling back on its path.
    expect(
      rects.first.left - rectAtTurn.left,
      closeTo(stepBefore, stepBefore / 4),
    );
    final swing = rects
        .map((rect) => (rect.center.dy - rectAtTurn.center.dy).abs())
        .reduce((a, b) => a > b ? a : b);
    expect(swing, greaterThan(20));
    expect(rects.last.left, closeTo(_slotRects[0].left, 1));
    expect(shuttle, findsNothing);
    expect(find.byKey(const ValueKey('box0')), findsOneWidget);
  });

  for (final again in [false, true]) {
    testWidgets('turns a hero ${again ? 'around again' : 'back'} where its '
        'shuttle is, to where the hero it heads for moved before it turned', (
      tester,
    ) async {
      final slot = ValueNotifier(0);
      final shift = ValueNotifier(0.0);
      addTearDown(slot.dispose);
      addTearDown(shift.dispose);

      await tester.pumpWidget(
        _SlotSwitcher(slot: slot, layoutBuilder: _shiftedLayoutBuilder(shift)),
      );
      await tester.pumpAndSettle();

      slot.value = 2;
      await _pumpSwitch(tester);
      await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 2);

      // The heroes move, as on a window resize, then the flight turns back,
      // and then on again.
      shift.value = 100;
      await tester.pump(_frame);
      await tester.pump(_frame);
      if (again) {
        slot.value = 0;
        await _pumpSwitch(tester);
        await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 4);
      }
      final shuttle = find.byKey(_shuttleKey);
      final leftAtTurn = tester.getRect(shuttle).left;
      final heading = again ? 2 : 0;
      slot.value = heading;
      await _pumpSwitch(tester);

      final lefts = <double>[];
      for (var i = 0; i < 40 && tester.any(shuttle); i++) {
        lefts.add(tester.getRect(shuttle).left);
        await tester.pump(_frame);
      }

      // It turns where it is and lands where the hero it heads for is now.
      final box = find.byKey(ValueKey('box$heading'));
      expect(lefts.first, leftAtTurn);
      expect(lefts.last, closeTo(tester.getRect(box).left, 1));
      expect(tester.getRect(box).left, _slotRects[heading].left + 100);
    });
  }

  for (final again in [false, true]) {
    testWidgets('turns a hero ${again ? 'around again' : 'back'} to where the '
        'hero it heads for moves once it turned', (tester) async {
      final slot = ValueNotifier(0);
      final nudge = ValueNotifier(0.0);
      addTearDown(slot.dispose);
      addTearDown(nudge.dispose);

      await tester.pumpWidget(_SlotSwitcher(slot: slot, nudge: nudge));
      await tester.pumpAndSettle();

      slot.value = 2;
      await _pumpSwitch(tester);
      await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 2);
      slot.value = 0;
      await _pumpSwitch(tester);
      if (again) {
        await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 4);
        slot.value = 2;
        await _pumpSwitch(tester);
      }

      // The hero it heads for moves within the switcher, after it turned.
      nudge.value = 100;
      final shuttle = find.byKey(_shuttleKey);
      final lefts = <double>[];
      for (var i = 0; i < 40 && tester.any(shuttle); i++) {
        await tester.pump(_frame);
        if (tester.any(shuttle)) lefts.add(tester.getRect(shuttle).left);
      }

      // It lands where that hero is now.
      final box = find.byKey(ValueKey('box${again ? 2 : 0}'));
      expect(tester.getRect(box).left, _slotRects[again ? 2 : 0].left + 100);
      expect(lefts, isNotEmpty);
      expect(lefts.last, closeTo(tester.getRect(box).left, 1));
    });
  }

  testWidgets('diverts a redirected hero straight from where its shuttle is', (
    tester,
  ) async {
    final slot = ValueNotifier(0);
    addTearDown(slot.dispose);

    await tester.pumpWidget(
      _SlotSwitcher(slot: slot, redirect: HeroHereFlightRedirect.divert),
    );
    await tester.pumpAndSettle();

    slot.value = 2;
    await _pumpSwitch(tester);
    await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 4);

    // Redirect the flight to the middle slot while it is near the first.
    final shuttle = find.byKey(_shuttleKey);
    final leftAtDivert = tester.getRect(shuttle).left;
    slot.value = 1;
    await _pumpSwitch(tester);

    final lefts = <double>[];
    final tops = <double>[];
    for (var frame = 0; frame < 40 && tester.any(shuttle); frame++) {
      lefts.add(tester.getRect(shuttle).left);
      tops.add(tester.getRect(shuttle).top);
      await tester.pump(_frame);
    }

    // It goes on from where it was, never toward the third slot, and takes
    // the full duration to get to the middle one. The middle slot is ahead
    // of it, so it doesn't swing out to the side.
    expect(lefts.first, closeTo(leftAtDivert, 1));
    for (var i = 1; i < lefts.length; i++) {
      expect(lefts[i], greaterThanOrEqualTo(lefts[i - 1]), reason: '$lefts');
    }
    expect(lefts.last, closeTo(_slotRects[1].left, 1));
    expect(tops, everyElement(closeTo(_slotRects[1].top, 1)));
    expect(
      lefts.length * _frame.inMilliseconds,
      greaterThanOrEqualTo(
        HeroHere.defaultFlightAnimationDuration.inMilliseconds,
      ),
    );
    expect(shuttle, findsNothing);
    expect(find.byKey(const ValueKey('box1')), findsOneWidget);
  });

  for (final (redirect, how) in [
    (HeroHereFlightRedirect.divert, 'diverts'),
    (HeroHereFlightRedirect.restart, 'restarts'),
  ]) {
    testWidgets('$how a flight on the frame it lands, as on the web', (
      tester,
    ) async {
      final slot = ValueNotifier(0);
      addTearDown(slot.dispose);

      await tester.pumpWidget(_SlotSwitcher(slot: slot, redirect: redirect));
      await tester.pumpAndSettle();

      slot.value = 2;
      await _pumpSwitch(tester);
      await tester.pump(HeroHere.defaultFlightAnimationDuration - _frame);

      // Redirect the flight to the middle slot on the frame it lands.
      slot.value = 1;
      await _pumpWebFrame(tester, _frame * 2);

      // It flies on to the middle slot rather than landing on it at once.
      final shuttle = find.byKey(_shuttleKey);
      expect(shuttle, findsOneWidget);
      expect(find.byKey(const ValueKey('box1')), findsNothing);
      await tester.pumpAndSettle();
      expect(shuttle, findsNothing);
      expect(find.byKey(const ValueKey('box1')), findsOneWidget);
    });
  }

  testWidgets('stops a flight on the frame it lands, as on the web', (
    tester,
  ) async {
    final slot = ValueNotifier(0);
    addTearDown(slot.dispose);

    await tester.pumpWidget(_SlotSwitcher(slot: slot));
    await tester.pumpAndSettle();

    // A flight to the middle slot, then on to the third.
    slot.value = 1;
    await _pumpSwitch(tester);
    slot.value = 2;
    await _pumpSwitch(tester);
    await tester.pump(HeroHere.defaultFlightAnimationDuration - _frame);

    // Take the hero away on the frame it lands on the middle slot.
    slot.value = _noSlot;
    await _pumpWebFrame(tester, _frame * 2);

    expect(find.byKey(_shuttleKey), findsNothing);
    await tester.pumpAndSettle();
    expect(find.byKey(_shuttleKey), findsNothing);
  });

  for (final web in [false, true]) {
    testWidgets('shows a shuttle that lands on a hero a switch took away, and '
        'flies it on${web ? ', as on the web' : ''}', (tester) async {
      final slot = ValueNotifier(0);
      addTearDown(slot.dispose);

      await tester.pumpWidget(_SlotSwitcher(slot: slot));
      await tester.pumpAndSettle();

      slot.value = 2;
      await _pumpSwitch(tester);
      await tester.pump(HeroHere.defaultFlightAnimationDuration - _frame);

      // As the flight is about to land, a switch moves the hero to the middle
      // slot, so the flight lands where the hero was and flies on from there.
      slot.value = 1;
      if (web) {
        // The switch runs on the frame the flight lands, and the landing
        // comes after it, as on the web.
        await _pumpWebFrame(tester, _frame * 2);
      } else {
        // The switch runs a frame before the flight lands.
        await tester.pump();
        await tester.pump(_frame * 2);
      }

      final shuttle = find.byKey(_shuttleKey);
      expect(shuttle, findsOneWidget);
      expect(tester.getRect(shuttle), _slotRects[2]);
      await tester.pumpAndSettle();
      expect(shuttle, findsNothing);
      expect(find.byKey(const ValueKey('box1')), findsOneWidget);
    });
  }

  testWidgets('shows a shuttle that lands back on a hero a switch took away, '
      'and flies it on', (tester) async {
    final slot = ValueNotifier(0);
    addTearDown(slot.dispose);

    await tester.pumpWidget(_SlotSwitcher(slot: slot));
    await tester.pumpAndSettle();

    slot.value = 1;
    await _pumpSwitch(tester);
    await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 2);

    // Back to the first slot, which takes as long as it flew.
    slot.value = 0;
    await _pumpSwitch(tester);
    await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 2 - _frame);

    // A frame before the flight lands back, a switch moves the hero to the
    // third slot, so the flight lands back where the hero was and flies on
    // from there.
    slot.value = 2;
    await tester.pump();
    await tester.pump(_frame * 2);

    final shuttle = find.byKey(_shuttleKey);
    expect(shuttle, findsOneWidget);
    expect(tester.getRect(shuttle), _slotRects[0]);
    await tester.pumpAndSettle();
    expect(shuttle, findsNothing);
    expect(find.byKey(const ValueKey('box2')), findsOneWidget);
  });

  testWidgets('turns a flight around on the frame it lands back, as on the '
      'web', (tester) async {
    final slot = ValueNotifier(0);
    addTearDown(slot.dispose);

    await tester.pumpWidget(_SlotSwitcher(slot: slot));
    await tester.pumpAndSettle();

    slot.value = 1;
    await _pumpSwitch(tester);
    await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 2);

    // Back to the first slot, which takes as long as it flew.
    slot.value = 0;
    await _pumpSwitch(tester);
    await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 2 - _frame);

    // On to the middle slot again on the frame it lands back.
    slot.value = 1;
    await _pumpWebFrame(tester, _frame * 2);

    final shuttle = find.byKey(_shuttleKey);
    expect(shuttle, findsOneWidget);
    expect(find.byKey(const ValueKey('box1')), findsNothing);
    await tester.pumpAndSettle();
    expect(shuttle, findsNothing);
    expect(find.byKey(const ValueKey('box1')), findsOneWidget);
  });

  testWidgets('carries a diverted hero on at the speed its shuttle had', (
    tester,
  ) async {
    final slot = ValueNotifier(0);
    addTearDown(slot.dispose);

    await tester.pumpWidget(
      _SlotSwitcher(slot: slot, redirect: HeroHereFlightRedirect.divert),
    );
    await tester.pumpAndSettle();

    slot.value = 2;
    await _pumpSwitch(tester);
    await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 2);

    // At full speed past the middle slot, redirect the flight to it.
    final shuttle = find.byKey(_shuttleKey);
    final leftBefore = tester.getRect(shuttle).left;
    await tester.pump(_frame);
    final left = tester.getRect(shuttle).left;
    final stepBefore = left - leftBefore;
    expect(stepBefore, greaterThan(10));

    slot.value = 1;
    await _pumpSwitch(tester);
    expect(tester.getRect(shuttle).left, left);
    await tester.pump(_frame);

    // It goes on at about the speed it had rather than stopping, then turns
    // back and lands on the middle slot.
    final stepAfter = tester.getRect(shuttle).left - left;
    expect(stepAfter, closeTo(stepBefore, stepBefore / 4));
    await tester.pumpAndSettle();
    expect(shuttle, findsNothing);
    expect(find.byKey(const ValueKey('box1')), findsOneWidget);
  });

  testWidgets('carries a diverted hero on at its own speed as heroes move', (
    tester,
  ) async {
    final slot = ValueNotifier(0);
    final shift = ValueNotifier(0.0);
    addTearDown(slot.dispose);
    addTearDown(shift.dispose);

    await tester.pumpWidget(
      _SlotSwitcher(
        slot: slot,
        redirect: HeroHereFlightRedirect.divert,
        layoutBuilder: _shiftedLayoutBuilder(shift),
      ),
    );
    await tester.pumpAndSettle();

    slot.value = 2;
    await _pumpSwitch(tester);
    await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 2);

    final shuttle = find.byKey(_shuttleKey);
    final leftBefore = tester.getRect(shuttle).left;
    await tester.pump(_frame);
    final stepBefore = tester.getRect(shuttle).left - leftBefore;

    // The hero it flies to jumps right, and the shuttle with it, just before
    // the flight diverts.
    shift.value = 200;
    await tester.pump(_frame);
    await tester.pump(_frame);
    final left = tester.getRect(shuttle).left;

    slot.value = 1;
    await _pumpSwitch(tester);
    await tester.pump(_frame);

    // It goes on at about the speed it flew at, not at the jump's.
    final stepAfter = tester.getRect(shuttle).left - left;
    expect(stepAfter, inExclusiveRange(stepBefore / 2, stepBefore * 2));
  });

  for (final (edge, flipped) in [('bottom', false), ('right', true)]) {
    testWidgets('keeps a diverted shuttle inside the switcher as it swings '
        'toward its $edge edge', (tester) async {
      _setUpView(tester);
      final slot = ValueNotifier(0);
      addTearDown(slot.dispose);
      const size = Size(60, 60);

      // Heroes near the edge. The flight along it diverts to a hero behind it
      // and a bit nearer the edge, so it swings toward the edge.
      Alignment along(double x, double y) =>
          flipped ? Alignment(y, x) : Alignment(x, y);
      await tester.pumpWidget(
        _AlignSwitcher(
          slot: slot,
          redirect: HeroHereFlightRedirect.divert,
          spots: [
            (alignment: along(-0.7, 0.93), size: size),
            (alignment: along(0.7, 0.93), size: size),
            (alignment: along(-0.9, 1), size: size),
          ],
        ),
      );
      await tester.pumpAndSettle();

      slot.value = 1;
      await _pumpSwitch(tester);
      await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 2);
      slot.value = 2;
      await _pumpSwitch(tester);

      final shuttle = find.byKey(_shuttleKey);
      var farthest = 0.0;
      while (tester.any(shuttle)) {
        final rect = tester.getRect(shuttle);
        farthest = max(farthest, flipped ? rect.right : rect.bottom);
        await tester.pump(const Duration(milliseconds: 8));
      }
      expect(farthest, lessThanOrEqualTo(flipped ? 800 : 600));
    });
  }

  testWidgets('flies a diverted hero back straight from where its shuttle is', (
    tester,
  ) async {
    final slot = ValueNotifier(0);
    addTearDown(slot.dispose);

    await tester.pumpWidget(
      _SlotSwitcher(slot: slot, redirect: HeroHereFlightRedirect.divert),
    );
    await tester.pumpAndSettle();

    slot.value = 2;
    await _pumpSwitch(tester);
    await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 4);
    slot.value = 1;
    await _pumpSwitch(tester);
    await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 2);

    // Back to the first slot: the diverted leg didn't start there, so the
    // shuttle can't get there by turning back.
    slot.value = 0;
    await _pumpSwitch(tester);

    // A switch on the way, with the same child, changes nothing.
    final shuttle = find.byKey(_shuttleKey);
    final leftBeforeSwitch = tester.getRect(shuttle).left;
    tester.element(find.byType(HeroHereSwitcher)).markNeedsBuild();
    await _pumpSwitch(tester);

    expect(tester.getRect(shuttle).left, leftBeforeSwitch);
    final lefts = <double>[];
    for (var frame = 0; frame < 40 && tester.any(shuttle); frame++) {
      lefts.add(tester.getRect(shuttle).left);
      await tester.pump(_frame);
    }

    // It carries on toward the middle slot a little at the speed it had,
    // short of it, then turns once and flies to the first slot.
    final farthest = lefts.reduce((a, b) => a > b ? a : b);
    final turn = lefts.indexOf(farthest);
    expect(farthest, lessThan(_slotRects[1].left));
    for (var i = 1; i < lefts.length; i++) {
      expect(
        lefts[i],
        i <= turn
            ? greaterThanOrEqualTo(lefts[i - 1])
            : lessThanOrEqualTo(lefts[i - 1]),
        reason: '$lefts',
      );
    }
    expect(lefts.last, closeTo(_slotRects[0].left, 1));
    expect(shuttle, findsNothing);
    expect(find.byKey(const ValueKey('box0')), findsOneWidget);
  });

  for (final back in [false, true]) {
    testWidgets(
      'restarts a hero sent ${back ? 'back to the hero it left' : 'on'} '
      'from rest where its shuttle is',
      (tester) async {
        final slot = ValueNotifier(0);
        addTearDown(slot.dispose);

        await tester.pumpWidget(
          _SlotSwitcher(slot: slot, redirect: HeroHereFlightRedirect.restart),
        );
        await tester.pumpAndSettle();

        slot.value = 2;
        await _pumpSwitch(tester);
        await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 2);

        // At full speed past the middle slot, send the flight to a slot behind
        // it.
        final shuttle = find.byKey(_shuttleKey);
        final leftBefore = tester.getRect(shuttle).left;
        await tester.pump(_frame);
        final leftAtRestart = tester.getRect(shuttle).left;
        expect(leftAtRestart - leftBefore, greaterThan(10));
        expect(leftAtRestart, greaterThan(_slotRects[1].left));
        final heading = back ? 0 : 1;
        slot.value = heading;
        await _pumpSwitch(tester);

        final rects = <Rect>[];
        for (var frame = 0; frame < 40 && tester.any(shuttle); frame++) {
          rects.add(tester.getRect(shuttle));
          await tester.pump(_frame);
        }

        // It starts over from where it was, toward that slot only: it neither
        // carries on at the speed it had nor swings out to the side. It takes
        // the full duration, as a flight from a hero there would, rather than
        // turning back over the way it came.
        final lefts = [for (final rect in rects) rect.left];
        expect(lefts.first, closeTo(leftAtRestart, 1));
        for (var i = 1; i < lefts.length; i++) {
          expect(lefts[i], lessThanOrEqualTo(lefts[i - 1]), reason: '$lefts');
        }
        expect([
          for (final rect in rects) rect.top,
        ], everyElement(closeTo(_slotRects[heading].top, 1)));
        expect(lefts.last, closeTo(_slotRects[heading].left, 1));
        expect(
          lefts.length * _frame.inMilliseconds,
          greaterThanOrEqualTo(
            HeroHere.defaultFlightAnimationDuration.inMilliseconds,
          ),
        );
        expect(shuttle, findsNothing);
        expect(find.byKey(ValueKey('box$heading')), findsOneWidget);
      },
    );
  }

  for (final (redirect, how) in [
    (HeroHereFlightRedirect.divert, 'diverts'),
    (HeroHereFlightRedirect.restart, 'restarts'),
  ]) {
    testWidgets('shuttles what its shuttle showed when it $how', (
      tester,
    ) async {
      final slot = ValueNotifier(0);
      addTearDown(slot.dispose);
      final fromHeroes = <HeroHere>[];

      await tester.pumpWidget(
        _SlotSwitcher(
          slot: slot,
          redirect: redirect,
          // Fades the hero the flight leaves out into the one it lands on.
          shuttleBuilder: (_, animation, fromHero, toHero) {
            fromHeroes.add(fromHero);
            return Stack(
              fit: StackFit.expand,
              children: [
                toHero.child,
                FadeTransition(
                  opacity: ReverseAnimation(animation),
                  child: fromHero.child,
                ),
              ],
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      slot.value = 2;
      await _pumpSwitch(tester);
      await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 4);

      final box0 = find.byKey(const ValueKey('box0'));
      final box2 = find.byKey(const ValueKey('box2'));
      final box0Opacity = _opacityOf(tester, box0);
      expect(box0Opacity, inExclusiveRange(0, 1));

      slot.value = 1;
      await _pumpSwitch(tester);

      // The new leg starts from the shuttle as it was: the hero it left half
      // faded out over the one it flew to, then fades that out.
      expect(_opacityOf(tester, box0), closeTo(box0Opacity, 0.001));
      expect(_opacityOf(tester, box2), 1);
      expect(fromHeroes.last.tag, 'hero');
      expect(fromHeroes.last.key, const ValueKey(0));

      // Back to the first slot, so the hero it leaves is the one it lands on.
      // The new leg starts from the shuttle as it was again.
      await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 4);
      final box1 = find.byKey(const ValueKey('box1'));
      final box2Opacity = _opacityOf(tester, box2);
      expect(box2Opacity, inExclusiveRange(0, 1));
      expect(_opacityOf(tester, box1), 1);

      slot.value = 0;
      await _pumpSwitch(tester);

      expect(_opacityOf(tester, box2), closeTo(box2Opacity, 0.001));
      expect(_opacityOf(tester, box1), 1);
      expect(fromHeroes.last.key, const ValueKey(0));

      await tester.pumpAndSettle();
      expect(box1, findsNothing);
      expect(box2, findsNothing);
      expect(box0, findsOneWidget);
    });
  }

  testWidgets('flies back, then on to where its child changes next', (
    tester,
  ) async {
    final slot = ValueNotifier(0);
    addTearDown(slot.dispose);

    await tester.pumpWidget(_SlotSwitcher(slot: slot));
    await tester.pumpAndSettle();

    slot.value = 1;
    await _pumpSwitch(tester);
    await tester.pump(HeroHere.defaultFlightAnimationDuration ~/ 2);

    slot.value = 0;
    await _pumpSwitch(tester);

    // Send the hero to the third slot while it flies back to the first.
    slot.value = 2;
    await _pumpSwitch(tester);

    final shuttle = find.byKey(_shuttleKey);
    final lefts = <double>[];
    for (var frame = 0; frame < 60 && tester.any(shuttle); frame++) {
      lefts.add(tester.getRect(shuttle).left);
      await tester.pump(_frame);
    }

    // It lands back on the first slot before it flies on.
    expect(lefts.reduce((a, b) => a < b ? a : b), _slotRects[0].left);
    expect(lefts.last, greaterThan(_slotRects[1].left));
    expect(shuttle, findsNothing);
    expect(find.byKey(const ValueKey('box2')), findsOneWidget);
  });
}

/// How opaque the widget [finder] finds shows, through the fades above it.
double _opacityOf(WidgetTester tester, Finder finder) {
  var opacity = 1.0;
  tester.element(finder).visitAncestorElements((element) {
    final widget = element.widget;
    if (widget is FadeTransition) opacity *= widget.opacity.value;
    return true;
  });
  return opacity;
}

/// Runs a frame [after] the last one as the web does: the microtasks that its
/// start schedules, such as a flight's landing, run after the whole frame,
/// so after a switch in it, rather than before its build.
Future<void> _pumpWebFrame(WidgetTester tester, Duration after) async {
  final binding = tester.binding;
  await binding.delayed(after);
  binding.handleBeginFrame(
    Duration(microseconds: binding.clock.now().microsecondsSinceEpoch),
  );
  binding.handleDrawFrame();
  await tester.pump();
}
