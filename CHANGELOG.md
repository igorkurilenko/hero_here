## Unreleased

### Example

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

