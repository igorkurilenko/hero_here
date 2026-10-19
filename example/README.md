# hero_here examples

- `lib/main.dart`: the basic example, also on pub.dev's Example tab.
- `lib/basic_with_auto_switching/`: heroes that switch on a timer, with flights that chain or divert when they change course.
- `lib/chat_message_hero/`: a sent message flies from the input into the chat.
- `lib/show_details_hero/`: a grid of mountains whose photo, name and description fly into a details view and back.
- `lib/flip_card_hero/`: tap a photo in a grid, and its card flies to the middle on a bouncy spring, flipping over to show the mountain's name and description. Tap it again, or beside it, and it flies back. It's the effect of heroine's showcase, within one page.

Run one with `flutter run -t <file>`, such as `flutter run -t lib/show_details_hero/main.dart`.

## Measuring frame times on a device

`integration_test/perf_test.dart` runs the examples' flights for real and records how long each frame takes:
- **details:** opens K2's details and closes them, five times;
- **chat:** sends ten messages;
- **switches:** taps through the auto-switching example's heroes, every other tap mid-flight, so the flight changes course.

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
- **Compare runs on the same phone**, plugged in and at a similar temperature. The auto-switching example places its heroes at random, so its flights differ a little from run to run.
