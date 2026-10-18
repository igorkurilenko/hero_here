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

part of 'hero_here.dart';

class _HeroHereSwitcherState extends State<HeroHereSwitcher>
    with TickerProviderStateMixin {
  final _childKey = GlobalKey();
  late final flights = _FlightRegistry(this);
  late _SwitchingState _switchingState;
  Widget? _child;

  /// The [HeroHereSwitcher.switchKey] that [_child] came with.
  Object? _switchKey;

  @override
  void dispose() {
    _switchingState.dispose();
    flights.dispose();
    super.dispose();
  }

  Set<_Hero> findHeroes() => _childKey.currentContext?.findHeroes() ?? const {};

  /// The switcher's child. Flights work out their rects in its space, so the
  /// rects don't depend on where the switcher is on the screen, which may not
  /// be known yet when they do, such as when a window resize lays the
  /// switcher out anew and moves it.
  RenderBox? get childBox => _childKey.currentContext?.findRenderBox();

  /// The layer the switcher's child last painted into.
  OffsetLayer? get childLayer => (childBox as _RenderBoundary?)?.lastLayer;

  /// The size of the switcher's child, which the rects kept from earlier
  /// frames move with, see [_KeptRect].
  Size? get childSize {
    final box = childBox;
    return box != null && box.hasSize ? box.size : null;
  }

  /// Whether [hero] hides for the switcher's state, as when the first child
  /// mounts, or while a switch waits to fly its tag.
  bool hides(_Hero hero) => _switchingState.hides(hero);

  /// Takes the widget's child, with its switch key, as the one to show.
  void takeChild() {
    _child = widget.child;
    _switchKey = widget.switchKey;
  }

  /// Whether the widget's child shows by a switch rather than in place of the
  /// current one, as it does unless its switch key is set and is the current
  /// child's.
  bool get switchesChild =>
      widget.switchKey == null || widget.switchKey != _switchKey;

  /// Moves to [state], the one way the switcher changes state.
  void enter(_SwitchingState state) {
    _switchingState = state;
    state.enter();
  }

  @override
  void initState() {
    super.initState();
    enter(_Mount(this));
  }

  @override
  Widget build(BuildContext context) {
    _switchingState.onBuild();

    final child = _HeroScope(
      switcher: this,
      child: _Boundary(key: _childKey, child: _child),
    );
    // A hero that a flight shows in the sky, such as a shuttle that is a
    // hero itself, is a copy, which belongs to no switcher.
    final sky = _HeroScope(
      switcher: null,
      child: ListenableBuilder(
        listenable: flights,
        builder: (context, _) => _buildSky(),
      ),
    );

    return widget.layoutBuilder(child, sky);
  }

  // Flights repaint on every frame. The boundary keeps those repaints off the
  // rest of the screen, whatever the layout builder puts around the sky.
  //
  // The sky takes the smallest size it may, with flights or without, so it
  // doesn't size the switcher: in a Center, an empty stack would fill the
  // screen until a flight starts. The relayout boundary also keeps the
  // flights' layouts on each frame inside the sky.
  Widget _buildSky() => RepaintBoundary(
    child: _RelayoutBoundary(
      child: Stack(
        children: [
          for (final hero in _switchingState.standIns)
            _StandIn(
              key: ValueKey((_StandIn, hero)),
              hero: hero,
              look: _switchingState.standInLook(hero),
            ),
          ...flights.all.map(
            (flight) =>
                _FlightWidget(key: ValueKey(flight.tag), flight: flight),
          ),
        ],
      ),
    ),
  );
}

/// Tells the heroes below it which switcher they're in: the one whose child
/// they're in, or none, in a switcher's sky.
class _HeroScope extends InheritedWidget {
  const _HeroScope({required this.switcher, required super.child});

  final _Switcher? switcher;

  /// The switcher of the hero with [context], if any.
  static _Switcher? of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_HeroScope>()?.switcher;

  @override
  bool updateShouldNotify(_HeroScope oldWidget) =>
      switcher != oldWidget.switcher;
}

/// A phase of the switcher's life. The switcher [enter]s a state once, then
/// tells it about each of its builds; a state moves the switcher on by
/// entering the next one. A build of the switcher runs a switch, unless its
/// switch key says its child shows in place: from [_Idle] it enters
/// [_Switch], which takes up the builds until it flies the heroes.
abstract class _SwitchingState {
  final _Switcher switcher;
  final Set<_Hero>? prevSwitchHeroes;

  _SwitchingState(this.switcher, {this.prevSwitchHeroes});

  /// Called once, when the switcher enters this state.
  void enter() {}

  /// Called on each build of the switcher, which may bring a new child.
  void onBuild() {}

  /// Whether [hero] hides for this state, whatever its own offstage.
  bool hides(_Hero hero) => false;

  /// The heroes the sky shows stand-ins of, where they were.
  Iterable<_Hero> get standIns => const [];

  /// What [hero] last showed, which its stand-in shows.
  _KeptLook? standInLook(_Hero hero) => null;

  /// Called when the switcher goes away.
  void dispose() {}

  /// Runs [work] after this frame, if the switcher is still mounted by then.
  void afterFrame(VoidCallback work) =>
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (switcher.mounted) work();
      });

  void notifyWillSwitch(Iterable<_Hero> heroes) {
    for (final hero in heroes) {
      hero.willSwitch();
    }
  }
}

/// Shows the first child as it is, with no flights. Of the heroes that share
/// a tag, only the last one shows, as after a switch.
class _Mount extends _SwitchingState {
  /// The heroes that a later hero with their tag hides. They are found when
  /// the first hero paints, once the whole child is built and laid out, so
  /// they hide from the first frame.
  late final Set<_Hero> hiddenHeroes = _findHiddenHeroes(switcher.findHeroes());

  _Mount(super.switcher);

  @override
  void enter() => afterFrame(_mount);

  @override
  void onBuild() => switcher.takeChild();

  @override
  bool hides(_Hero hero) => hiddenHeroes.contains(hero);

  void _mount() {
    final heroes = switcher.findHeroes();

    notifyWillSwitch(heroes);

    for (final hero in hiddenHeroes) {
      hero.offstage = true;
    }

    switcher.enter(_Idle(switcher, prevSwitchHeroes: heroes));
  }

  Set<_Hero> _findHiddenHeroes(Set<_Hero> heroes) {
    final lastHeroesByTag = {for (final hero in heroes) hero.tag: hero};
    return heroes.where((hero) => lastHeroesByTag[hero.tag] != hero).toSet();
  }
}

class _Idle extends _SwitchingState {
  _Idle(super.switcher, {super.prevSwitchHeroes});

  @override
  void onBuild() {
    if (!switcher.switchesChild) {
      switcher.takeChild();
      return;
    }

    // The heroes on the screen, found and kept where they are before the
    // new child replaces them, while their layout is the last frame's.
    final curHeroes = switcher.findHeroes();
    notifyWillSwitch(curHeroes);

    switcher.takeChild();
    switcher.enter(
      _Switch(
        switcher,
        prevSwitchHeroes: prevSwitchHeroes,
        curHeroes: curHeroes,
      ),
    );
  }
}

/// Shows the new child on the frame of the build that brought it, and flies
/// its heroes after that frame, once it is built and laid out, so with no
/// snapshot of the old child. On that frame, the new heroes of every tag that
/// may fly hide, those built later in the frame too, while the heroes that
/// stay show as they are. The sky shows a stand-in of each hero that was on
/// the screen and went away, where it was, so its flight starts where its
/// stand-in is. Builds while it waits need nothing: it takes the newest
/// child.
class _Switch extends _SwitchingState {
  final Set<_Hero> curHeroes;

  /// The heroes that were on the screen. Each stand-in shows only if its hero
  /// went away. The heroes of a flight under way are hidden, and a hero that
  /// mounts while its tag flies hides until a switch decides about it.
  @override
  final List<_Hero> standIns;

  /// The tags that may fly: those of [standIns].
  final Set<Object> _tags;

  /// [curHeroes] themselves, rather than heroes equal to them, which may have
  /// mounted anew.
  late final Set<_Hero> _stayed = Set.identity()..addAll(curHeroes);

  /// What [standIns] last showed, kept from before the switch. Their layers
  /// are kept until the stand-ins, which keep them while they show, have
  /// them.
  late final Map<_Hero, _KeptLook> _looks = Map.identity()
    ..addAll({
      for (final hero in standIns)
        hero: ?_KeptLook.of(hero, switcher.childLayer),
    });

  factory _Switch(
    _Switcher switcher, {
    Set<_Hero>? prevSwitchHeroes,
    required Set<_Hero> curHeroes,
  }) {
    final standIns = [
      for (final hero in curHeroes)
        if (hero.onstage) hero,
    ];
    return _Switch._(
      switcher,
      prevSwitchHeroes: prevSwitchHeroes,
      curHeroes: curHeroes,
      standIns: standIns,
      tags: {for (final hero in standIns) hero.tag},
    );
  }

  _Switch._(
    super.switcher, {
    super.prevSwitchHeroes,
    required this.curHeroes,
    required this.standIns,
    required this._tags,
  });

  // The layers are kept now, while the heroes and their last frame's layers
  // are as they were.
  @override
  void enter() {
    _looks;
    afterFrame(_switch);
  }

  @override
  void onBuild() => switcher.takeChild();

  @override
  bool hides(_Hero hero) => _tags.contains(hero.tag) && !_stayed.contains(hero);

  @override
  _KeptLook? standInLook(_Hero hero) => _looks[hero];

  @override
  void dispose() => _releaseLayers();

  void _releaseLayers() {
    for (final look in _looks.values) {
      look.release();
    }
  }

  void _switch() {
    final nextHeroes = switcher.findHeroes();
    final plan = _SwitchPlan(
      curHeroes: curHeroes,
      nextHeroes: nextHeroes,
      prevSwitchHeroes: prevSwitchHeroes,
      flying: {
        for (final flight in switcher.flights.all) flight.tag: flight.manifest,
      },
    );

    notifyWillSwitch(nextHeroes);

    for (final hero in plan.hiddenHeroes) {
      hero.offstage = true;
    }

    for (final tag in plan.stoppedTags) {
      switcher.flights[tag]!.abort();
    }

    for (final manifest in plan.flights.values) {
      final flight = switcher.flights[manifest.tag];
      if (flight != null) {
        flight.update(manifest);
      } else {
        _Flight.start(
          vsync: switcher,
          registry: switcher.flights,
          manifest: manifest,
        );
      }
    }

    switcher.enter(_Idle(switcher, prevSwitchHeroes: nextHeroes));

    // The heroes it hid while it waited show again, unless the plan hid
    // them, and the sky drops the stand-ins.
    _repaintHeroesOf(nextHeroes);
    switcher.flights.changed();
    _releaseLayers();
  }

  void _repaintHeroesOf(Iterable<_Hero> heroes) {
    for (final hero in heroes) {
      if (_tags.contains(hero.tag)) hero.hidingChanged();
    }
  }
}

/// What a switch does, worked out without changing any hero or flight.
class _SwitchPlan {
  /// The flight each tag needs to start or redirect, by tag.
  final Map<Object, _FlightManifest> flights;

  /// The tags whose flight under way stops.
  final Set<Object> stoppedTags;

  /// The next heroes that hide, since another hero with their tag shows.
  final Set<_Hero> hiddenHeroes;

  _SwitchPlan._(this.flights, this.stoppedTags, this.hiddenHeroes);

  /// Plans the switch from [curHeroes] to [nextHeroes], given the heroes of
  /// the last switch and the manifests of the flights [flying], by tag.
  ///
  /// Of the next heroes that share a tag, the last one is where its tag
  /// flies to. It flies from where its flight under way is, or else from the
  /// current hero with its tag that shows, preferring one of the last
  /// switch. With neither, nothing flies: the last one shows at once, as on
  /// mount.
  factory _SwitchPlan({
    required Set<_Hero> curHeroes,
    required Set<_Hero> nextHeroes,
    required Set<_Hero>? prevSwitchHeroes,
    required Map<Object, _FlightManifest> flying,
  }) {
    final manifests = <Object, _FlightManifest>{};

    for (final x in nextHeroes) {
      final manifest = manifests.putIfAbsent(
        x.tag,
        () => _FlightManifest(tag: x.tag, from: x, to: x),
      );
      manifest.to = x;
    }

    for (final manifest in manifests.values) {
      final flight = flying[manifest.tag];
      if (flight?.from == manifest.to) {
        manifest.from = flight!.to;
      } else if (flight != null) {
        manifest.from = flight.from;
      } else {
        manifest.from =
            curHeroes
                .where((x) => x.tag == manifest.tag)
                .where((x) => x.onstage)
                .where((x) => prevSwitchHeroes?.contains(x) ?? false)
                .firstOrNull ??
            curHeroes
                .where((x) => x.tag == manifest.tag)
                .where((x) => x.onstage)
                .firstOrNull ??
            manifest.to;
      }
    }

    // A flight under way goes on while a next hero has its tag, even when it
    // flies back to the hero it left, as a diverted flight may.
    return _SwitchPlan._(
      {
        for (final manifest in manifests.values)
          if (!manifest.isIdle || flying.containsKey(manifest.tag))
            manifest.tag: manifest,
      },
      {
        for (final tag in flying.keys)
          if (!manifests.containsKey(tag)) tag,
      },
      {
        for (final hero in nextHeroes)
          if (manifests[hero.tag]!.from != hero &&
              manifests[hero.tag]!.to != hero)
            hero,
      },
    );
  }
}
