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

/// Shows [hero] where it was at a switch, as it last showed, while the switch
/// waits to fly its tag, if the hero went away. It shows the [look] kept from
/// before the switch, so the hero isn't built or drawn again. The flight then
/// starts where the stand-in is.
class _StandIn extends StatelessWidget {
  final _Switcher switcher;
  final _Hero hero;
  final _KeptLook? look;

  const _StandIn({
    super.key,
    required this.switcher,
    required this.hero,
    required this.look,
  });

  // Like a flight's, its place is worked out as it lays out, by the size the
  // switcher's child has on this frame.
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, _) => _ShuttleRect(
      rect: hero.placeholderRectIn(switcher) ?? Rect.zero,
      space: () => switcher.childBox,
      // A hero that stays shows itself. Whether it stays is known by the
      // time the frame paints, once the new child is built and laid out.
      child: _KeptLayer(look: look, shows: () => hero.wentAway),
    ),
  );
}

/// Shows [look] where it lays out, while [shows] says so when it paints.
class _KeptLayer extends LeafRenderObjectWidget {
  final _KeptLook? look;
  final bool Function() shows;

  const _KeptLayer({required this.look, required this.shows});

  @override
  _RenderKeptLayer createRenderObject(BuildContext context) =>
      _RenderKeptLayer(look, shows);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderKeptLayer renderObject,
  ) => renderObject
    ..look = look
    ..shows = shows;
}

class _RenderKeptLayer extends RenderBox {
  final _layer = LayerHandle<OffsetLayer>();
  _KeptLook? _look;
  bool Function() shows;

  _RenderKeptLayer(this._look, this.shows) {
    _layer.layer = _look?.layer;
  }

  set look(_KeptLook? value) {
    if (identical(_look, value)) return;
    _look = value;
    _layer.layer = value?.layer;
    markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => _layer.layer != null;

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      constraints.biggest;

  @override
  void paint(PaintingContext context, Offset offset) {
    final look = _look, layer = _layer.layer;
    if (look == null || layer == null || !shows()) return;
    context.addLayer(look.build(layer, at: offset));
  }

  @override
  void dispose() {
    _layer.layer = null;
    super.dispose();
  }
}

/// What a hero last showed, kept at a switch: the layer it last painted into,
/// and the layers its ancestors in the switcher's child put that layer in,
/// such as a clip that rounds its corners from outside it, or a fade.
class _KeptLook {
  /// Keeps the layer until [release].
  final _handle = LayerHandle<OffsetLayer>();

  /// Where the hero was in the switcher's child.
  final Offset _origin;

  /// Make the layers its ancestors put the layer in, innermost first, or
  /// null if it wasn't in the switcher's child, as a shuttle's isn't.
  final List<ContainerLayer Function()>? _wrappers;

  _KeptLook._(OffsetLayer layer, this._origin, this._wrappers) {
    _handle.layer = layer;
  }

  /// What [hero] last showed, if it painted, in [switcher]'s child, as the
  /// switcher switches.
  static _KeptLook? of(_Hero hero, _Switcher switcher) {
    final layer = hero.lastLayer;
    if (layer == null) return null;
    final childLayer = switcher.childLayer;
    final wrappers = <ContainerLayer Function()>[];
    for (var parent = layer.parent; parent != null; parent = parent.parent) {
      if (identical(parent, childLayer)) {
        final origin = hero.placeholderRectIn(switcher)?.topLeft ?? Offset.zero;
        return _KeptLook._(layer, origin, wrappers);
      }
      if (_wrapperLike(parent) case final wrapper?) wrappers.add(wrapper);
    }
    return _KeptLook._(layer, Offset.zero, null);
  }

  OffsetLayer? get layer => _handle.layer;

  void release() => _handle.layer = null;

  /// Puts [layer] back in the layers it was in, so the hero, as it showed,
  /// is [at] where its stand-in lays out. Adding the result takes [layer]
  /// out of where it was, if it's still there.
  Layer build(OffsetLayer layer, {required Offset at}) {
    final wrappers = _wrappers;
    if (wrappers == null) return layer..offset = at;
    // The layer keeps its offset in the layer it was in.
    layer.remove();
    Layer built = layer;
    for (final wrapper in wrappers) {
      built = wrapper()..append(built);
    }
    return OffsetLayer(offset: at - _origin)..append(built);
  }

  /// A function that makes a layer like [layer], with nothing in it, if it
  /// changes how what's in it shows.
  static ContainerLayer Function()? _wrapperLike(ContainerLayer layer) =>
      switch (layer) {
        ClipRectLayer(:final clipRect, :final clipBehavior) =>
          () => ClipRectLayer(clipRect: clipRect, clipBehavior: clipBehavior),
        ClipRRectLayer(:final clipRRect, :final clipBehavior) =>
          () =>
              ClipRRectLayer(clipRRect: clipRRect, clipBehavior: clipBehavior),
        ClipRSuperellipseLayer(:final clipRSuperellipse, :final clipBehavior) =>
          () => ClipRSuperellipseLayer(
            clipRSuperellipse: clipRSuperellipse,
            clipBehavior: clipBehavior,
          ),
        ClipPathLayer(:final clipPath, :final clipBehavior) =>
          () => ClipPathLayer(clipPath: clipPath, clipBehavior: clipBehavior),
        ColorFilterLayer(:final colorFilter) => () => ColorFilterLayer(
          colorFilter: colorFilter,
        ),
        ShaderMaskLayer(:final shader, :final maskRect, :final blendMode) =>
          () => ShaderMaskLayer(
            shader: shader,
            maskRect: maskRect,
            blendMode: blendMode,
          ),
        ImageFilterLayer(:final imageFilter, :final offset) =>
          () => ImageFilterLayer(imageFilter: imageFilter, offset: offset),
        TransformLayer(:final transform, :final offset) => () => TransformLayer(
          transform: transform,
          offset: offset,
        ),
        OpacityLayer(:final alpha, :final offset) => () => OpacityLayer(
          alpha: alpha,
          offset: offset,
        ),
        OffsetLayer(:final offset) => () => OffsetLayer(offset: offset),
        // A link has one leader at a time, so a leader comes back as the
        // offset it puts what's in it at.
        LeaderLayer(:final offset) => () => OffsetLayer(offset: offset),
        FollowerLayer() => switch (_lastTransformOf(layer)) {
          final transform => () => TransformLayer(transform: transform),
        },
        _ => null,
      };

  /// The transform [follower] put what's in it through as it last
  /// composited: to where its leader was, or else by its unlinked offset.
  static Matrix4 _lastTransformOf(FollowerLayer follower) {
    final offset = follower.unlinkedOffset ?? Offset.zero;
    final transform = Matrix4.translationValues(offset.dx, offset.dy, 0);
    if (follower.getLastTransform() case final last?) transform.multiply(last);
    return transform;
  }
}
