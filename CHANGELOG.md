## Unreleased

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

