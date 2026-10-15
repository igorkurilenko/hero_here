## Unreleased

### Example

* Run one switch per flight in the show details example, instead of a second one that snapshots the whole page after each flight lands.

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

