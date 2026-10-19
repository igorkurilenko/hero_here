import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hero_here/hero_here.dart';

part 'hero_here/flights.dart';
part 'hero_here/heroes.dart';
part 'hero_here/redirects.dart';
part 'hero_here/mid_flight.dart';
part 'hero_here/switches.dart';
part 'hero_here/stand_ins.dart';
part 'hero_here/layout.dart';
part 'hero_here/performance.dart';
part 'hero_here/support.dart';

void main() {
  _flightsTests();
  _heroesTests();
  _redirectsTests();
  _midFlightTests();
  _switchesTests();
  _standInsTests();
  _layoutTests();
  _performanceTests();
}
