## Unreleased

### Fixes

* Show a hero that went away where it was on the frame of its switch when a `CompositedTransformTarget` or a `CompositedTransformFollower` placed it. The stand-in the switch shows for it left out the offset or the transform they put it at, so for that frame it showed elsewhere, such as at the follower's place before it followed.

## 2.1.1

### Fixes

* Keep showing a hero under a disabled `HeroMode` on the frame of a switch that flies its tag. Switches leave such a hero out, yet on the switch's frame, while it waits to fly the tag, the switcher hid every new hero of the tag, so the hero blinked out for a frame. Now it hides only the heroes the switch flies or hides.
* Show a hero again once a disabled `HeroMode` leaves it out of switches, if it had hidden: behind a later hero of its tag, or as the hero a flight flew to. It stayed hidden for good, since only switches and flights show a hero again, and both left it out. Now each switch shows the heroes it leaves out.
* Show a hero under a disabled `HeroMode` that mounts while a flight flies its tag. It hid until the flight ended, like a hero that takes part in switches, and for good if a switch came first.
* Keep showing a hero once a disabled `HeroMode` leaves it out mid-flight, when the flight lands on it and flies on to the next hero. The next leg hid it again, as the hero it leaves, for good.
* Start no flight from a hero whose `HeroMode` a switch disables as it brings another hero of its tag. The switch found the heroes that showed as they were before it, so it flew from the hero, which hid it for good. Now the other hero shows at once, as when its own hero mode is disabled.

### Docs

* Document that a hero under a disabled `HeroMode` takes no part in the switches that find it there, and shows as it is.
* Open the README with what the package is for, in the words people search for: a heading, why Flutter's `Hero` doesn't fly within a page and how hero_here does, and a quick start of about 20 lines in place of the whole example app, which the Example tab shows. Add a section for each example, a comparison with `Hero`, `AnimatedSwitcher`, heroine, local_hero and animated_to, and answers to common questions, such as why a hero moved with the same key doesn't fly.

## 2.1.0

### Features

* Add `HeroHereShuttles`, ready-made builders of what a flight shows as it flies, for `HeroHere.flightShuttleBuilder`. `HeroHereShuttles.crossfade()` fades the hero a flight leaves out over the hero it flies to. `HeroHereShuttles.flip()` turns the shuttle over like a card, about the vertical axis or, with `axis: Axis.horizontal`, the horizontal one. It shows the hero the flight leaves until it's edge on, then the hero it flies to, mirrored so it reads the right way round. Each follows the flight's animation itself, since a flight builds its shuttle once per leg rather than on each frame.

### Fixes

* Show a hero that equals one before it, with the same tag and key, again after a switch, with its semantics up to date. While a switch waits, it hides every hero of a tag that may fly, but it told only the heroes it plans flights for to show again. Such a hero then showed without the semantics tree knowing, which tripped an assertion with semantics on, as under a screen reader.

### Example

* Add an example whose photo cards flip over as they fly open on a bouncy spring, and back: `example/lib/flip_card_hero/`. Its heroes drive their flights with a `SpringSimulation` on an unbounded controller, so a card swings past its place and back, and a card closed mid-flight carries on a little before it turns back. They fly with `HeroHereShuttles.flip()`, which turns the card about its upright axis. The card's back is laid out at the open card's size and scaled to the shuttle's, so its words keep their lines as it grows and shrinks in flight. Each card dims its own faces while another card is open, rather than lie under a layer that dims the grid, which flights fly over, so a card on its way back to the grid dims along with it when another card opens meanwhile.
* Decode the details example's grid thumbnails for the cells the device's display shows, rather than for the grid's largest cells. On a phone held upright the cells are smaller, so the 14 thumbnails take about 55 MiB at 3× rather than 111 MiB, within the image cache's 100 MiB, and scrolling no longer evicts and decodes them again. The size follows the wider of the window and the display, so a window's resize still decodes nothing anew, and a phone on its side still gets sharp thumbnails.
* Sign the example apps with each checkout's own development team, which a `Signing.xcconfig` that git ignores sets, rather than with the team the iOS project carried. Without one, a checkout builds as it is, and macOS signs the app to run locally.
* Give each chat message an id of its own, by counting them. Its hero's tag came from 20 bits of the message's hash, so two messages could share a tag, with about even odds by 1,200 messages, and of heroes that share a tag only the last shows, so the earlier message vanished from the list.
* Stop the auto-switching example's timer when its page goes away. It kept switching, and set the state of a page that was gone.
* Slide the details example's grid all the way toward a tapped cell near the page's middle. It didn't slide at all for a cell nearer the middle than the margin its scale leaves, yet slid the whole margin for one just past it.
* Keep the details example's grid covering the page for a tapped cell far from the middle both across and down, such as one in the second row. Its slide kept within the margin its scale leaves on one axis only, so it could slide far past the other one and show the page's edge.

## 2.0.0

### Breaking changes

* Paint no background in `HeroHereSwitcher.defaultLayoutBuilder`. Its `Material` is now transparent, so what's behind the switcher shows through, such as a `Scaffold`'s background or an image, rather than the theme's canvas color covering it. The material still gives the child and the shuttles a default text style and a surface for ink, and the switcher still takes taps that land on its empty space. A switcher with nothing painted behind it now shows what's under it, such as black on a phone. To keep the old look, pass `layoutBuilder: (child, sky) => Material(child: Stack(children: [child, sky]))`.
* Remove the type names deprecated in 1.2.0. Use `HeroHereFlightAnimationControllerFactory` for `AnimationControllerFactory`, `HeroHereFlightAnimationFactory` for `AnimationFactory`, which only makes an `Animation<double>`, `HeroHereFlightAnimationStarter` for `StartAnimationCaller` and `HeroHereFlightRectTweenFactory` for `RectTweenFactory`.

### Docs

* Describe the package in the words people search for. Its description now says it's a hero animation within the same page, with no Navigator or routes, and it has the topics animation, hero, transition, widget and ui. The pubspec now gives the GitHub repository as its `repository` rather than its `homepage`.

## 1.5.7

### Fixes

* Treat a hero that a shuttle shows as a copy that belongs to no switcher, as when a shuttle builder returns `toHero` or `fromHero` itself rather than its child. The copy used to take over the hero's part in the flight, so the shuttle showed nothing, and a flight to that hero left it hidden for good once it landed. Heroes outside a switcher's child, such as ones its layout builder adds, belong to no switcher either.
* Fly from where a hero is once a global key moves it into another switcher, rather than from as far off as the two switchers are apart. A hero moved in while the switcher flies its tag hides until that flight lands, as a hero that mounts mid-flight does. A flight that the hero's old switcher has under way keeps flying to where the hero is.

### Performance

* Take a switch's heroes from a registry that they keep up to date as they mount, move and go, rather than walking the switcher's child twice on each switch. A switch no longer visits the child's other widgets, so its cost follows the number of heroes rather than the size of the child. Measured in debug mode with 15 heroes, finding them took about 80 µs rather than 650 µs in a child of 20,000 widgets, and about 75 µs rather than 30 µs with nothing else in the child.

### Example

* Add a benchmark of the examples' frame times on a device. `integration_test/perf_test.dart` opens and closes the details, sends chat messages and switches heroes mid-flight, and `test_driver/perf_driver.dart` prints the build and raster times of each. The example's README says how to run it.
* Move the chat example's input up with the keyboard. It was the scaffold's bottom bar, which stays behind the keyboard. Now it's below the list in the scaffold's body, which the scaffold shrinks above the keyboard, and the list keeps its newest message in view as the keyboard opens or closes, unless it's scrolled back to older ones.

## 1.5.6

### Performance

* Measure where the hero a flight leaves is once a frame rather than twice, and only on legs that start there: a measure walks the render tree from the hero up to the switcher.

### Example

* Fade the details' title and description by their color as they fly, rather than with `FadeTransition`. Each flying text took an opacity layer, which on the web paints offscreen on every frame, across the whole screen since flights fly unclipped. Their heroes carry their text as a payload that builds it at an opacity.
* Clip the details example's back button to its box. Its switcher's fade keeps it in an opacity layer while the details are open, which on the web paints offscreen on every frame as big as the clip around it, which was the whole app bar.

## 1.5.5

### Docs

* Document the rest of the public API: the library, `HeroHere`'s constructor, its tag, child, flight options, payload and defaults, `HeroHereSwitcher`'s constructor, the shuttle builder's type and the deprecated type names. Among other things, they say that a hero's key tells a switch whether it's a new hero, which flies, or the same one, which doesn't, and which of a flight's two heroes it takes each option from. The analyzer now flags public API without docs.

### Example

* Ship the basic example's page, `example/example.md`, so pub.dev shows it on the package's Example tab. `.pubignore` left out the whole example folder, so pub.dev found no example. Its code is now the same as the example app's `lib/main.dart`.

## 1.5.4

### Fixes

* Show the hero a flight left when the hero it lands on went away mid-flight with no switch since, such as a page a page view jumped away from. The flight showed the hero that was gone and left the other hidden, so neither showed until a later flight landed. This applies both ways: landing on a hero, and landing back on the one it left.

### Example

* Decode the details example's grid thumbnails no taller than a grid cell shows them, rather than at their full 2048 px, which took about 11 MB each and more than the image cache holds for the whole grid. The details show the cell's thumbnail, already decoded, until their full image is, so the flight that opens them never shows a gap.
* Dim the details example's grid with a scrim in the canvas color while the details are open, rather than with `AnimatedOpacity`, which kept the whole grid in an opacity layer even when opaque. On the web that painted the grid offscreen on every frame. The scrim gives the same colors, in one rectangle. The back button's switcher also has no child while the details are closed, rather than an empty one in a fade layer.

## 1.5.3

### Fixes

* Don't crash when a flight measures a hero that a sliver list has just moved to a new index, as a `PageView` or `ListView` with `findChildIndexCallback` does when an item before it goes. Until the sliver lays the hero out again, the flight takes the hero as nowhere, as it does an inactive one, and flies to where it was.

### Example

* Fade the details' title and description by their color as a drag closes them, rather than with `Opacity`. On the web an opacity layer paints offscreen even when opaque, so the open details took two offscreen passes on every frame. A drag now builds the two texts anew on each tick.

## 1.5.2

### Example

* Repaint only the auto-switching example's bottom bar when its buttons change, such as on each switch or after a tap, rather than the whole page with it.
* Show the chat example's sent messages as text in the field's decoration rather than as read-only text fields, so each takes 9 elements rather than 44 for a switch to walk. Sent messages can no longer be selected.
* Keep the chat example's input focused as messages are sent, however quickly. An Enter with nothing typed no longer leaves the field, and what is typed right after a send is no longer lost. The field now stays the same through every send, under the hero the message flies from, and shows the message until its flight does.

## 1.5.1

### Fixes

* Keep a diverted shuttle inside the switcher as it carries on or swings around near the switcher's edge, so it slides along the edge, instead of out of the switcher by as much as the speed it had takes it. A shuttle whose path is outside, such as from a hero scrolled away, carries on as before.

## 1.5.0

### Features

* Switch without a snapshot of the old child. A switch used to take one with `toImageSync`, show it while it laid the new child out offstage for a frame, and show the new child two frames after the rebuild. Now the new child shows on the frame of the rebuild, and its flights start a frame earlier. On that frame, the heroes of the tags that may fly hide, the heroes that stay show as they are, and each hero that went away shows where it was, as it last showed, with the clips, fades and transforms around it.
* Each `HeroHere` paints its child into a layer of its own, which a switch keeps to show a hero that went away. This changes the layer tree, such as what `debugDumpLayerTree` shows, but not what shows.

## 1.4.3

### Performance

* Repaint a flight's shuttle only when it changes, such as when it changes size, instead of on each frame it moves. In a flight between heroes of the same size, the shuttle now moves without repainting.

## 1.4.2

### Fixes

* Place a shuttle where its heroes are on the frame a window resize moves the switcher, such as one below a header whose height follows the window's width, instead of where the switcher was on the frame before.

## 1.4.1

### Fixes

* Start a flight's leg where its start would be after a window resize, rather than where it was on the screen, so after a fast shrink the shuttle no longer starts off the screen. A start kept from an earlier frame, such as where a hero that went away was, or where the shuttle diverted or turned around, moves as the switcher's child resizes: a start at an edge stays at that edge, one in between stays as far across in proportion, and one off the screen stays as far off it. A leg that starts on a hero that's still there starts wherever that hero is on each frame.

## 1.4.0

### Features

* Add `HeroHereSwitcher.switchKey`, which says which rebuilds of the switcher run a switch. Unset, every rebuild does, as before. Set, only a rebuild that changes it does. Any other rebuild shows its child at once, in place of the current one, with no snapshot, and nothing flies.

### Fixes

* Show the new child that a switch, or a rebuild below the switcher, gives a hero mid-flight in the flight's shuttle as soon as the hero has it, instead of the child the hero had when the shuttle was built.

### Docs

* Document `HeroHereSwitcher.layoutBuilder`, its type and its default, and add a Layout section to the README: keep the sky after the child, so flights follow each frame's layout, and give the sky the switcher's size to clip the flights to it.

### Example

* Run a switch in the auto-switching example only when its hero changes, by setting `switchKey`, rather than on each tap of its Chain, Divert, play or pause buttons.

## 1.3.1

### Fixes

* Keep showing a shuttle that lands while a switch shows its snapshot of the old child, until the switch runs, instead of showing nothing for a frame: the snapshot shows the hero the shuttle lands on hidden, and the new child isn't showing yet.
* Place a shuttle by where its heroes are on each frame, rather than where they were on the frame before, so while a window is resized the shuttle keeps up with the heroes instead of lagging a frame behind them.
* Keep a switcher whose parent lets it be smaller, such as a `Center`, at its child's size when no flight is under way, instead of filling the space it may, with the child at its top left, then jumping to the child's size for each flight.

## 1.3.0

### Features

* Add `HeroHere.flightRedirect`, which says what a flight does when the hero it flies to changes mid-flight. `HeroHereFlightRedirect.chain`, the default, lands on that hero, then flies on to the new one, as before. `HeroHereFlightRedirect.divert` flies from where the shuttle is to the new hero, over the flight's whole duration. The shuttle sets off at the speed it had, so it turns toward the new hero rather than stops, and swings around to a hero behind it, such as the hero it left, rather than doubling back. Its `fromHero` becomes a stand-in for the shuttle as it was, so the shuttle changes from what it showed.

### Fixes

* On the web, where a flight's landing runs after the rest of its frame, a switch on that frame that stops the flight no longer makes the landing fail with "A _Flight was used after being disposed".
* Turn a flight back toward where the hero it left is now, rather than where that hero was when the flight left it, so that after a window resize the shuttle lands on the hero instead of jumping to it.

### Example

* Add Chain and Divert tabs to the auto-switching example's top bar, which switch its flights' redirects, and place its heroes at random spots, so its flights go every way.

## 1.2.1

### Fixes

* Fly nothing when a switch brings two heroes with a tag that no hero showed before, instead of flying from the earlier of them to the later one. As on mount, the later one shows at once and the earlier one hides.

### Docs

* Say in `HeroHereSwitcher`'s docs and the README to read sizes below the switcher, since a `LayoutBuilder` or a `MediaQuery.sizeOf` read above it runs a switch on each frame of a window resize.

### Example

* Run no switch on each window resize in the show details example once its details have opened, by reading the page's size rather than the window's.

## 1.2.0

### Deprecations

* Name the flight option types after the package, like `HeroHereFlightShuttleBuilder`: `HeroHereFlightAnimationControllerFactory`, `HeroHereFlightAnimationFactory`, `HeroHereFlightAnimationStarter` and `HeroHereFlightRectTweenFactory`. The old names, `AnimationControllerFactory`, `AnimationFactory`, `StartAnimationCaller` and `RectTweenFactory`, still work but are deprecated, and will be removed in 2.0.0.

## 1.1.10

### Fixes

* Show a hero that mounts while a flight of its tag is under way, and has no part in it, once the flight ends, instead of keeping it hidden until the next switch. A switch during the flight still decides whether it shows.

## 1.1.9

### Fixes

* Fly on without an error when the switcher's sky mounts anew mid-flight, such as when a layout builder wraps it in another widget, instead of calling `setState()` on the flight's widget that went away when the flight goes on to its next hero.

## 1.1.8

### Fixes

* Show a hero that a flight goes on to next when it mounts anew, without a switch, before the flight gets to it, instead of keeping it hidden after the flight lands.

## 1.1.7

### Example

* Keep what is typed in the chat example's input when the page rebuilds, such as on a theme change, instead of losing it, and dispose the text controllers.

## 1.1.6

### Fixes

* Keep a hidden hero, such as the one a flight lands on, at the size it would show at, instead of the size it had when it hid, so after a window resize a flight lands on it without a jump.

## 1.1.5

### Example

* Run one switch per flight in the show details example, instead of a second one that snapshots the whole page after each flight lands.
* Keep the show details example's back button in place when the page rebuilds, such as on a window resize, instead of fading in a new one over it.
* Rebuild only the image, title and description wrappers on each frame of a drag on the show details example's details, instead of the whole details view.
* Close the show details example's details onto where the cell is, instead of where it was when it was tapped, which was wrong after a window resize.
* Show the show details example's scrollbars at the window's edge, instead of at the edge of the middle column, and scroll with the wheel anywhere in the window.

## 1.1.4

### Fixes

* Show the switcher's first child on the first frame with no flights, instead of two frames late and with a flight between any of its heroes that share a tag.

## 1.1.3

### Performance

* Repaint only the flights on each frame of a flight, instead of the whole screen.

## 1.1.2

### Performance

* Lay out only the shuttle on each frame of a flight between heroes of different sizes, instead of the whole screen.

## 1.1.1

### Fixes

* Fly a hero on from where its shuttle is when the child changes again mid-flight, instead of jumping back to where the flight started.
* Show the heroes of a child that arrives while a switch is still running, instead of keeping them hidden for good.
* Release each switch's snapshot of the old child when the switch ends, instead of keeping a full-screen image in memory until garbage collection.

## 1.1.0

### Fixes

* Fly heroes in place when `HeroHereSwitcher` is not at the screen origin, for example below an app bar, beside a sidebar or in a right-to-left layout.
* Use the device pixel ratio for the switch snapshot to avoid small layout shifts and low render quality when switching children ([#1](https://github.com/igorkurilenko/hero_here/pull/1), thanks [@andrei-bucurei](https://github.com/andrei-bucurei)).

### Documentation

* Explain what a `HeroHereSwitcher` rebuild costs.

### Maintenance

* Require Dart 3.13 and Flutter 3.47.
* Update the example to the current Flutter templates.

## 1.0.1

### Fixes

* Preserve the begin rect in RectTween when reversing the animation.

## 1.0.0

* Initial release of hero_here.
* Introduced `HeroHereSwitcher` and `HeroHere` widgets for hero transitions on the same screen.
* Example usage provided in the README.
* Added additional examples: send_message_hero, show_details_hero.

