// Copyright 2026 Igor Kurilenko
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

part of 'shuttles.dart';

HeroHereFlightShuttleBuilder _scale(BoxFit fit, AlignmentGeometry alignment) =>
    (flightContext, animation, fromHero, toHero) =>
        _Scaled(fit: fit, alignment: alignment, child: toHero.child);

/// Lays [child] out at the size of the hero its flight flies to, and scales
/// it to its own size as [fit] and [alignment] say. While that size isn't
/// known, or is empty, it lays [child] out at its own size.
class _Scaled extends StatelessWidget {
  const _Scaled({
    required this.fit,
    required this.alignment,
    required this.child,
  });

  final BoxFit fit;
  final AlignmentGeometry alignment;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final size = HeroHere.toHeroSizeOf(context);
    return LayoutBuilder(
      builder: (context, constraints) => FittedBox(
        fit: fit,
        alignment: alignment,
        child: SizedBox.fromSize(
          size: size == null || size.isEmpty ? constraints.biggest : size,
          child: child,
        ),
      ),
    );
  }
}
