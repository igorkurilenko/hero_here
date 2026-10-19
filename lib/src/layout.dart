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

/// Lays its child out with its own constraints and takes the smallest size
/// they allow, so a layout below it, such as a flight's on each frame, lays
/// out nothing above it.
class _RelayoutBoundary extends SingleChildRenderObjectWidget {
  const _RelayoutBoundary({super.child});

  @override
  _RenderRelayoutBoundary createRenderObject(BuildContext context) =>
      _RenderRelayoutBoundary();
}

class _RenderRelayoutBoundary extends RenderProxyBox {
  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      constraints.smallest;

  // Its size doesn't depend on its child, so it doesn't ask its child, which
  // a layout builder couldn't answer, such as in an IntrinsicHeight.
  @override
  double computeMinIntrinsicWidth(double height) => 0;

  @override
  double computeMaxIntrinsicWidth(double height) => 0;

  @override
  double computeMinIntrinsicHeight(double width) => 0;

  @override
  double computeMaxIntrinsicHeight(double width) => 0;

  @override
  double? computeDryBaseline(
    covariant BoxConstraints constraints,
    TextBaseline baseline,
  ) => null;

  @override
  void performLayout() {
    child?.layout(constraints);
  }
}

/// A rect in the switcher's child kept from an earlier frame, with the size
/// the child had then. When the child changes size, such as on a window
/// resize, the rect keeps its size, and its place in the room the child has
/// around it, as an [Align] keeps a child's: as far across that room, in
/// proportion. So a rect at an edge stays there, and one in the middle stays
/// in the middle. A rect outside that room, such as a hero's that was
/// scrolled away, keeps its distance from it, so it stays outside.
class _KeptRect {
  final Rect rect;

  /// The size of the switcher's child when the rect was kept.
  final Size? size;

  const _KeptRect(this.rect, this.size);

  /// The rect, with the switcher's child of size [now].
  Rect within(Size? now) {
    final then = size;
    if (then == null || now == null || now == then) return rect;
    return Rect.fromLTWH(
      _place(rect.left, then.width - rect.width, now.width - rect.width),
      _place(rect.top, then.height - rect.height, now.height - rect.height),
      rect.width,
      rect.height,
    );
  }

  /// Where a rect [offset] from the child's start goes along an axis, given
  /// the room the child had around it, [room], and has now, [nowRoom].
  static double _place(double offset, double room, double nowRoom) {
    if (offset <= 0) return offset;
    if (offset >= room) return nowRoom + (offset - room);
    return offset / room * nowRoom;
  }
}

/// Rects as the four numbers of their edges, such as the edges' speeds.
extension _RectEdges on Rect {
  Rect plus(Rect other) => Rect.fromLTRB(
    left + other.left,
    top + other.top,
    right + other.right,
    bottom + other.bottom,
  );

  Rect minus(Rect other) => plus(other.times(-1));

  Rect times(double factor) => Rect.fromLTRB(
    left * factor,
    top * factor,
    right * factor,
    bottom * factor,
  );
}

extension _Seconds on Duration {
  double get seconds => inMicroseconds / Duration.microsecondsPerSecond;
}

extension _RenderBox on RenderBox {
  /// Where this box is in [ancestor]'s space, or null while that isn't
  /// known: before the box's first layout, or while a sliver on the way has
  /// no offset for it, such as when a list moves it to a new index, until the
  /// sliver lays it out again.
  Rect? rectIn(RenderObject ancestor) {
    if (!hasSize) return null;
    RenderObject? node = this;
    while (node != null && node != ancestor) {
      final parent = node.parent;
      if (parent is RenderSliver && parent.childScrollOffset(node) == null) {
        return null;
      }
      node = parent;
    }
    return localToGlobal(Offset.zero, ancestor: ancestor) & size;
  }
}

/// [element] and its ancestors below [root], from the top down, or null if
/// a disabled [HeroMode] is among them, which leaves the hero at [element]
/// out of switches. An element that isn't below [root] gets all its
/// ancestors, since no hero mode below [root] leaves it out.
List<Element>? _pathBelow(Element root, Element element) {
  final path = [element];
  var leftOut = false, belowRoot = false;
  element.visitAncestorElements((ancestor) {
    if (identical(ancestor, root)) {
      belowRoot = true;
      return false;
    }
    final widget = ancestor.widget;
    if (widget is HeroMode && !widget.enabled) leftOut = true;
    path.add(ancestor);
    return true;
  });
  return leftOut && belowRoot ? null : path.reversed.toList();
}

/// [heroes] that no disabled [HeroMode] below [root] leaves out, in the
/// order a depth-first walk of the tree below [root] would meet them: a hero
/// before the heroes inside it, and children in their parent's order.
List<_Hero> _inTreeOrder(Iterable<_Hero> heroes, Element root) {
  // Where each child is among its parent's children, for each parent where
  // two paths part, worked out once, however many heroes are below it.
  final childIndexes = Map<Element, Map<Element, int>>.identity();
  int indexOf(Element parent, Element child) =>
      childIndexes.putIfAbsent(parent, () {
        final indexes = Map<Element, int>.identity();
        // Unlike visitChildElements, visitChildren may run while the tree
        // builds or lays out, such as from a layout callback.
        parent.visitChildren((child) => indexes[child] = indexes.length);
        return indexes;
      })[child] ??
      -1;

  int compare(List<Element> a, List<Element> b) {
    var i = 0;
    while (i < a.length && i < b.length && identical(a[i], b[i])) {
      i++;
    }
    if (i == a.length && i == b.length) return 0;
    // A walk meets a hero before the heroes inside it.
    if (i == a.length) return -1;
    if (i == b.length) return 1;
    final parent = i == 0 ? root : a[i - 1];
    return indexOf(parent, a[i]).compareTo(indexOf(parent, b[i]));
  }

  final paths = [
    for (final hero in heroes)
      if (_pathBelow(root, hero.context as Element) case final path?)
        (hero: hero, path: path),
  ]..sort((a, b) => compare(a.path, b.path));
  return [for (final entry in paths) entry.hero];
}

extension _BuildContext on BuildContext {
  RenderBox? findRenderBox() => findRenderObject() as RenderBox?;
}
