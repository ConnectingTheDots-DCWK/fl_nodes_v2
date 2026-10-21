import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../model/graph_node.dart';
import 'node_sketch.dart';

/// How much of a line's box its glyphs cover, roughly. A bar is drawn at the
/// text's colour this transparent, so a line of text keeps its tone rather
/// than turning into a solid stripe.
const double sketchInk = 0.42;

/// The x-height band as a fraction of the font size: where most of a line's
/// ink is, and therefore where its bar goes.
const double _xHeight = 0.56;

/// A filled shape the painter draws, in the node's coordinates.
///
/// [ring] is the width of an outline drawn inside [rect], or zero for a
/// filled shape.
@immutable
class SketchShape {
  SketchShape(this.rect, this.color, this.radius, {this.ring = 0})
    : corner = math.max(
        math.max(radius.topLeft.x, radius.topRight.x),
        math.max(radius.bottomLeft.x, radius.bottomRight.x),
      );

  final Rect rect;
  final Color color;
  final BorderRadius radius;
  final double ring;

  /// The largest corner radius, which decides when the corners are squared.
  final double corner;

  /// The size the shape is judged by when deciding whether it is still
  /// worth drawing: a bar's height, a ring's width.
  double get extent => ring > 0 ? ring : rect.shortestSide;
}

/// A sketch reduced to what the painter draws: [shapes] in paint order, with
/// text already laid out into bars and the border as a ring after the parts.
@immutable
class ResolvedSketch {
  const ResolvedSketch._(this.sketch, this.size, this.shapes, this.flat);

  factory ResolvedSketch.of(NodeSketch sketch, Size size) {
    final body = Offset.zero & size;
    final shapes = <SketchShape>[SketchShape(body, sketch.fill, sketch.radius)];
    for (final part in sketch.parts) {
      switch (part) {
        case SketchBox(
          :final rect,
          :final color,
          :final radius,
          :final border,
          :final borderWidth,
        ):
          shapes.add(SketchShape(rect, color, radius));
          if (border != null && borderWidth > 0) {
            shapes.add(SketchShape(rect, border, radius, ring: borderWidth));
          }
        case SketchBar(:final rect, :final color):
          shapes.add(SketchShape(rect, color, BorderRadius.zero));
        case SketchText():
          _addTextBars(shapes, part);
      }
    }
    final border = sketch.border;
    if (border != null && sketch.borderWidth > 0) {
      shapes.add(
        SketchShape(body, border, sketch.radius, ring: sketch.borderWidth),
      );
    }
    return ResolvedSketch._(sketch, size, shapes, _flatColour(sketch, size));
  }

  final NodeSketch sketch;
  final Size size;
  final List<SketchShape> shapes;

  /// The one colour the node is drawn in once it is a dot: its fill with
  /// every box over it mixed in by area, so a coloured header band still
  /// tints the dot of a card whose band it was.
  final Color flat;

  static void _addTextBars(List<SketchShape> shapes, SketchText text) {
    if (text.text.isEmpty) return;
    final painter =
        TextPainter(
            text: TextSpan(text: text.text, style: text.style),
            textDirection: TextDirection.ltr,
            textAlign: text.align,
            maxLines: text.maxLines,
            ellipsis: text.maxLines == 1 ? '…' : null,
          )
          // At the box's full width, or an alignment has no room to act in.
          ..layout(minWidth: text.rect.width, maxWidth: text.rect.width);
    final top = text.maxLines == 1
        ? text.rect.center.dy - painter.height / 2
        : text.rect.top;
    final band = (text.style.fontSize ?? 14) * _xHeight;
    final colour = (text.style.color ?? const Color(0xFF000000)).withValues(
      alpha: (text.style.color?.a ?? 1) * sketchInk,
    );
    for (final line in painter.computeLineMetrics()) {
      final bar = Rect.fromLTWH(
        text.rect.left + line.left,
        top + line.baseline - band,
        line.width,
        band,
      );
      // A line the box cuts off is not drawn by the card either.
      if (bar.bottom > text.rect.bottom + 0.5) break;
      if (bar.width > 0) {
        shapes.add(SketchShape(bar, colour, BorderRadius.zero));
      }
    }
    painter.dispose();
  }

  static Color _flatColour(NodeSketch sketch, Size size) {
    final area = size.width * size.height;
    var colour = sketch.fill;
    if (area <= 0) return colour;
    for (final part in sketch.parts) {
      if (part case SketchBox(:final rect, :final color)) {
        final share = rect.intersect(Offset.zero & size);
        if (share.isEmpty) continue;
        final weight = math.min(1.0, share.width * share.height / area);
        colour = Color.lerp(colour, Color.alphaBlend(color, colour), weight)!;
      }
    }
    return colour;
  }
}

/// Every node's sketch, asked for once and kept until it could have changed.
///
/// An entry stands while its node is the identical instance, at the same
/// size, sketched by the same function — so a pan asks for nothing. When a
/// node does change, the host is asked again but the text is only laid out
/// again if the sketch it answers with is different: a node that only moved
/// keeps its bars.
class SketchCache {
  final Map<String, _Entry> _entries = <String, _Entry>{};
  Map<String, GraphNode>? _prunedAgainst;

  /// How many times a sketch has been laid out, for the tests that hold the
  /// cache to its promise.
  @visibleForTesting
  int debugResolveCount = 0;

  /// Whether [resolve] would answer without asking [sketcher] anything.
  bool isReady(GraphNode node, Size size, NodeSketcher sketcher) {
    final entry = _entries[node.id];
    return entry != null &&
        identical(entry.node, node) &&
        identical(entry.sketcher, sketcher) &&
        entry.resolved.size == size;
  }

  ResolvedSketch resolve(GraphNode node, Size size, NodeSketcher sketcher) {
    final entry = _entries[node.id];
    if (entry != null &&
        identical(entry.node, node) &&
        identical(entry.sketcher, sketcher) &&
        entry.resolved.size == size) {
      return entry.resolved;
    }
    final sketch = sketcher(node, size);
    if (entry != null &&
        entry.resolved.size == size &&
        entry.resolved.sketch == sketch) {
      entry
        ..node = node
        ..sketcher = sketcher;
      return entry.resolved;
    }
    debugResolveCount++;
    final resolved = ResolvedSketch.of(sketch, size);
    _entries[node.id] = _Entry(node, sketcher, resolved);
    return resolved;
  }

  /// Forgets every sketch, for when something outside the nodes moved.
  void clear() => _entries.clear();

  /// Drops the entries of nodes no longer in [nodes]. Cheap to call every
  /// frame: it only walks when the map is a different one from last time.
  void prune(Map<String, GraphNode> nodes) {
    if (identical(_prunedAgainst, nodes)) return;
    _prunedAgainst = nodes;
    _entries.removeWhere((id, _) => !nodes.containsKey(id));
  }

  @visibleForTesting
  int get length => _entries.length;
}

class _Entry {
  _Entry(this.node, this.sketcher, this.resolved);

  GraphNode node;
  NodeSketcher sketcher;
  final ResolvedSketch resolved;
}
