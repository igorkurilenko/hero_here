# hero_here examples

- `lib/main.dart`: the flippers photo from Flutter's hero animations guide flies from the middle of the page into its corner, and back, on a tap, with no route. It's also on pub.dev's Example tab. The photo, `images/flippers.png`, comes from the guide, under the license in `images/LICENSE`.
- `lib/add_to_cart_hero/`: a shop whose products' pictures fly from their cards into the cart, landing on a soft spring, and back once they're taken out, as the products after them in the cart slide along.
- `lib/navigation_bar_hero/`: a bottom navigation bar whose indicator flies to the tapped tab, under the icons, and starts over to a tab tapped mid-flight, from where it is.
- `lib/segmented_control_hero/`: a segmented control whose thumb flies to the tapped period, under the labels, as a chart's bars grow and shrink, and the steps count to the period's total.
- `lib/splash_logo_hero/`: once the app has loaded, the splash screen's logo and name fly into the app bar. Tap them to see the splash screen again.
- `lib/chat_message_hero/`: a sent message flies from the input into the chat.
- `lib/show_details_hero/`: a Pinterest-style grid whose image, title and description fly into a details view, and back as a pull on the image collapses it.
- `lib/flip_card_hero/`: tap a card in a grid, and it flies to the middle on a bouncy spring, flipping over to show its back. Tap it again, or beside it, and it flies back. It's the effect of heroine's showcase, within one page.
- `lib/style/`: the new examples' look, as rose_app's, kept apart from what they show: the theme, its tokens, Geist (in `assets/fonts/`, under the SIL Open Font License) and [Unicons](https://iconscout.com/unicons) 4.0.0 line icons (under the Apache License 2.0), painted from their SVG paths. Each new example's `main.dart` places its heroes, with numbered steps, and a file beside it draws the rest.

Run one with `flutter run -t <file>`, such as `flutter run -t lib/show_details_hero/main.dart`.

## Measuring frame times on a device

`integration_test/perf_test.dart` runs the examples' flights for real and records how long each frame takes:
- **details:** opens K2's details and closes them, five times;
- **chat:** sends ten messages;
- **cart:** adds the four products to the cart, then takes them out, the first in the cart each time, so the others slide along;
- **tabs:** taps through the navigation bar's tabs, every other tap mid-flight, so the indicator starts over to the newly tapped tab.

```sh
flutter drive --profile --no-dds -d <device id> \
  --driver=test_driver/perf_driver.dart \
  --target=integration_test/perf_test.dart
```

The driver prints the average, 90th and 99th percentile and worst UI-thread (build) and raster time of each scenario. It also prints how many frames went over 8.3 ms (120 Hz) and 16.7 ms (60 Hz). It saves the frame times to `build/perf_run.json`; set `PERF_LABEL` to name the file after the run instead.

- **Find the device id** with `flutter devices`. A simulator can't run profile mode.
- **Connect a phone with a cable.** Over Wi‑Fi, the Mac can find the app but may fail to connect to it. An iPhone asks on the first launch to find devices on the local network: allow it. Keep the phone unlocked while it runs.
- **Keep `--no-dds`.** Without it the app can't connect to its own VM service, which it needs to record frames.
- **Semantics are off**, as for most users, who don't run an assistive technology. Add `--dart-define=SEMANTICS=true` to measure as under a screen reader such as VoiceOver or TalkBack.
- **Compare runs on the same phone**, plugged in and at a similar temperature.

## Signing

The example's Xcode projects carry no development team, so a checkout builds as it is, and macOS signs the app to run locally. To run it on an iPhone, put your team ID in a file that git ignores:
```
echo 'DEVELOPMENT_TEAM = <your team ID>' > ios/Flutter/Signing.xcconfig
```
`macos/Runner/Configs/Signing.xcconfig` does the same for macOS. Set the team there rather than in Xcode's Signing & Capabilities tab, which writes it into the project for everyone.
