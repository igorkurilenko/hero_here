// Copyright 2024 Igor Kurilenko
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

/// Hero animations within the same page, with no Navigator or routes.
///
/// Wrap the part of the page whose widgets move in a [HeroHereSwitcher], and
/// put a [HeroHere] in each place a widget may be: with the same tag in every
/// place, and a key of its own in each. When the page changes its state and
/// a hero shows up in another place, the switcher flies it there from where
/// it was.
///
/// [HeroHereShuttles] has ready-made shuttles for flights: a crossfade, a
/// flip like a card's, and a scale that keeps text from reflowing.
library;

export 'src/hero_here.dart';
export 'src/shuttles/shuttles.dart';
