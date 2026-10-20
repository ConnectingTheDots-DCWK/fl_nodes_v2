import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../model/graph_node.dart';
import '../theme/node_editor_theme.dart';
import 'sketch_cache.dart';

/// Below this many screen pixels on its short side a node is one flat box.
const double sketchFlatBelow = 3;

/// Below this many screen pixels a box or a bar is not drawn.
const double sketchPartBelow = 0.3;

/// Below this many screen pixels a box or a bar is drawn this thick instead,
/// and fainter by as much as it was thinner.
///
/// Its tone is what is left of a line of text at that size, and dropping it
/// at a pixel and a half took the text off a card at the very zoom the card
/// stopped being built — the one step this is meant not to have. Drawn at
/// its own thickness it would not do either: triangles are not
/// anti-aliased, so a bar under a pixel lights a row or none depending on
/// where it falls, and flickers as the canvas pans.
const double sketchThinBelow = 1;

/// Below this many screen pixels a border is not drawn.
const double sketchBorderBelow = 0.5;

/// Below this many screen pixels a corner is drawn square.
const double sketchCornerBelow = 1;

/// Segments per quarter circle, by how many pixels the corner spans. A
/// sketch's corners are a few pixels across, so four is already more than
/// the eye can count, and a two-pixel corner is a chamfer however it is
/// drawn.
int _segmentsFor(double pixels) => pixels < 2.5
    ? 1
    : pixels < 5
    ? 2
    : 4;

/// Hands [draw] what of [sketch] is still worth drawing at [scale], in paint
/// order and in the node's coordinates: shapes too small to see left out,
/// corners too small to see squared, and the whole node one flat box once it
/// is a dot.
///
/// A visitor rather than a list, because it runs for every shape of every
/// node on screen on every frame of a pan.
void visitSketchAt(
  ResolvedSketch sketch,
  double scale,
  void Function(Rect rect, BorderRadius radius, double ring, Color color) draw,
) {
  if (sketch.size.shortestSide * scale < sketchFlatBelow) {
    draw(Offset.zero & sketch.size, BorderRadius.zero, 0, sketch.flat);
    return;
  }
  for (final shape in sketch.shapes) {
    final pixels = shape.extent * scale;
    final radius = shape.corner * scale < sketchCornerBelow
        ? BorderRadius.zero
        : shape.radius;
    if (shape.ring > 0) {
      if (pixels >= sketchBorderBelow) {
        draw(shape.rect, radius, shape.ring, shape.color);
      }
      continue;
    }
    if (pixels < sketchPartBelow) continue;
    if (pixels >= sketchThinBelow) {
      draw(shape.rect, radius, 0, shape.color);
      continue;
    }
    final rect = shape.rect;
    final thick = sketchThinBelow / scale;
    draw(
      rect.height <= rect.width
          ? Rect.fromCenter(
              center: rect.center,
              width: rect.width,
              height: thick,
            )
          : Rect.fromCenter(
              center: rect.center,
              width: thick,
              height: rect.height,
            ),
      BorderRadius.zero,
      0,
      shape.color.withValues(alpha: shape.color.a * pixels / sketchThinBelow),
    );
  }
}

/// [visitSketchAt]'s answer as a list, for tests.
List<SketchShape> sketchShapesAt(ResolvedSketch sketch, double scale) {
  final shapes = <SketchShape>[];
  visitSketchAt(
    sketch,
    scale,
    (rect, radius, ring, color) =>
        shapes.add(SketchShape(rect, color, radius, ring: ring)),
  );
  return shapes;
}

/// Every sketched node, drawn in one pass.
///
/// It paints inside the node layer's scaled stack, as `EmphasisPainter`
/// does, so its coordinates are scene coordinates offset by [origin] and
/// [scale] only decides what is still big enough to draw.
///
/// **One `drawVertices` call for every node, in paint order.** Batching by
/// colour into a path each would be fewer triangles but would draw every
/// node's bars over every node's body — a card on top of another would show
/// the text of the card beneath it. Triangles in a single list keep the order
/// exactly, and the GPU sees one draw.
///
/// What is too small to see drops out on its own, part by part: a border
/// thinner than half a pixel, a corner under a pixel, a box or a line of text
/// that has faded out under a third of one, and finally the node itself under
/// three, which leaves one box in a colour mixed from the card. There is no second look
/// to switch to, so there is no second threshold.
class SketchPainter extends CustomPainter {
  SketchPainter({
    required this.nodes,
    required this.sketchOf,
    required this.origin,
    required this.scale,
    required this.theme,
    required this.revision,
    required this.selectionRevision,
    this.selected = const <String>{},
    this.target,
  });

  /// In paint order, bottom first.
  final List<GraphNode> nodes;
  final ResolvedSketch Function(GraphNode node) sketchOf;
  final Offset origin;
  final double scale;
  final NodeEditorTheme theme;

  /// The graph's revision and the selection's: [nodes] and [selected] are
  /// the editor's live collections, so comparing them tells nothing.
  final int revision;
  final int selectionRevision;
  final Set<String> selected;

  /// The node a wire being dragged would land on.
  final String? target;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..translate(-origin.dx, -origin.dy);

    final triangles = _Triangles.shared..clear();
    final outlined = <(GraphNode, ResolvedSketch)>[];
    for (final node in nodes) {
      final sketch = sketchOf(node);
      final dx = node.position.dx;
      final dy = node.position.dy;
      visitSketchAt(sketch, scale, (rect, radius, ring, color) {
        final at = rect.translate(dx, dy);
        if (ring > 0) {
          triangles.ring(at, radius, ring, color, scale);
        } else {
          triangles.shape(at, radius, color, scale);
        }
      });
      if (sketch.sketch.halo != null ||
          selected.contains(node.id) ||
          node.id == target) {
        outlined.add((node, sketch));
      }
    }
    triangles.draw(canvas);

    // Rings, stroked and anti-aliased over everything: there are few of them,
    // and each has to stay visible however far out the canvas is.
    for (final (node, sketch) in outlined) {
      final box = node.position & sketch.size;
      if (sketch.sketch.halo case final Color halo) {
        _ring(canvas, box, halo, gap: 2, width: 3);
      }
      if (selected.contains(node.id)) {
        _ring(
          canvas,
          box,
          theme.selectionColor,
          gap: theme.selectionInset,
          width: theme.selectionWidth,
        );
      } else if (node.id == target) {
        _ring(
          canvas,
          box,
          theme.pendingConnectionColor,
          gap: theme.selectionInset,
          width: theme.selectionWidth,
        );
      }
    }

    canvas.restore();
  }

  /// [gap] and [width] are scene units with a floor in screen pixels, so a
  /// ring keeps its shape up close and stays a ring far out.
  void _ring(
    Canvas canvas,
    Rect box,
    Color color, {
    required double gap,
    required double width,
  }) {
    final stroke = math.max(width, 1.5 / scale);
    final out = math.max(gap, 1.5 / scale) + stroke / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(box.inflate(out), theme.selectionRadius),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
  }

  @override
  bool shouldRepaint(SketchPainter oldDelegate) =>
      oldDelegate.revision != revision ||
      oldDelegate.selectionRevision != selectionRevision ||
      oldDelegate.origin != origin ||
      oldDelegate.scale != scale ||
      oldDelegate.target != target ||
      !identical(oldDelegate.theme, theme) ||
      !identical(oldDelegate.sketchOf, sketchOf) ||
      oldDelegate.nodes.length != nodes.length;
}

/// Coloured triangles, gathered in paint order and drawn in one call.
///
/// One instance is kept and refilled: a frame of a pan at 2592 nodes is tens
/// of thousands of triangles, and growing a fresh buffer to that size every
/// frame was a copy per doubling for nothing.
class _Triangles {
  _Triangles._();

  static final _Triangles shared = _Triangles._();

  /// Most points an outline can have: four arcs of four segments.
  static const int _maxPoints = 4 * 5;

  /// Unit offsets round the four corners, clockwise from the top left, x then
  /// y, `segments + 1` points a corner — one table per segment count.
  static final Map<int, Float32List> _units = <int, Float32List>{
    for (final segments in const <int>[1, 2, 4]) segments: _unitFor(segments),
  };

  static Float32List _unitFor(int segments) {
    final unit = Float32List(4 * (segments + 1) * 2);
    var k = 0;
    for (final start in <double>[math.pi, math.pi * 1.5, 0, math.pi * 0.5]) {
      for (var s = 0; s <= segments; s++) {
        final angle = start + (math.pi / 2) * s / segments;
        unit[k++] = math.cos(angle);
        unit[k++] = math.sin(angle);
      }
    }
    return unit;
  }

  Float32List _positions = Float32List(1 << 16);
  Int32List _colors = Int32List(1 << 15);
  int _vertices = 0;

  final Float32List _outer = Float32List(_maxPoints * 2);
  final Float32List _inner = Float32List(_maxPoints * 2);

  void clear() => _vertices = 0;

  void _reserve(int vertices) {
    final needed = _vertices + vertices;
    if (needed <= _colors.length) return;
    var capacity = _colors.length * 2;
    while (capacity < needed) {
      capacity *= 2;
    }
    _positions = Float32List(capacity * 2)
      ..setRange(0, _vertices * 2, _positions);
    _colors = Int32List(capacity)..setRange(0, _vertices, _colors);
  }

  void _vertex(double x, double y, int color) {
    final i = _vertices++;
    _positions[i * 2] = x;
    _positions[i * 2 + 1] = y;
    _colors[i] = color;
  }

  void rect(Rect r, Color color) {
    _reserve(6);
    final c = color.toARGB32();
    _vertex(r.left, r.top, c);
    _vertex(r.right, r.top, c);
    _vertex(r.right, r.bottom, c);
    _vertex(r.left, r.top, c);
    _vertex(r.right, r.bottom, c);
    _vertex(r.left, r.bottom, c);
  }

  void shape(Rect r, BorderRadius radius, Color color, double scale) {
    if (radius == BorderRadius.zero) return rect(r, color);
    final n = _outline(_outer, r, radius, 0, scale);
    final c = color.toARGB32();
    final cx = r.center.dx;
    final cy = r.center.dy;
    _reserve(n * 3);
    // A fan from the centre: the outline of a rounded rectangle is convex.
    for (var i = 0; i < n; i++) {
      final j = (i + 1) % n;
      _vertex(cx, cy, c);
      _vertex(_outer[i * 2], _outer[i * 2 + 1], c);
      _vertex(_outer[j * 2], _outer[j * 2 + 1], c);
    }
  }

  /// A border [width] wide inside [r]: the strip between its outline and the
  /// outline of the box inset by [width], point matched to point.
  void ring(
    Rect r,
    BorderRadius radius,
    double width,
    Color color,
    double scale,
  ) {
    final inner = r.deflate(width);
    if (inner.isEmpty) return shape(r, radius, color, scale);
    final c = color.toARGB32();
    if (radius == BorderRadius.zero) {
      // Four bands, the top and bottom full width and the sides between them.
      rect(Rect.fromLTRB(r.left, r.top, r.right, inner.top), color);
      rect(Rect.fromLTRB(r.left, inner.bottom, r.right, r.bottom), color);
      rect(Rect.fromLTRB(r.left, inner.top, inner.left, inner.bottom), color);
      rect(Rect.fromLTRB(inner.right, inner.top, r.right, inner.bottom), color);
      return;
    }
    // The inner outline takes the outer's segment count, or the two would
    // not stitch point to point.
    final n = _outline(_outer, r, radius, 0, scale);
    _outline(_inner, inner, radius, width, scale, segments: n ~/ 4 - 1);
    _reserve(n * 6);
    for (var i = 0; i < n; i++) {
      final j = (i + 1) % n;
      final ox = _outer[i * 2], oy = _outer[i * 2 + 1];
      final px = _outer[j * 2], py = _outer[j * 2 + 1];
      final ix = _inner[i * 2], iy = _inner[i * 2 + 1];
      final qx = _inner[j * 2], qy = _inner[j * 2 + 1];
      _vertex(ox, oy, c);
      _vertex(px, py, c);
      _vertex(qx, qy, c);
      _vertex(ox, oy, c);
      _vertex(qx, qy, c);
      _vertex(ix, iy, c);
    }
  }

  /// [r]'s outline into [into]: each corner's arc, clockwise from the top
  /// left, with every radius less [less]. Returns how many points it wrote,
  /// the same whatever the radii for one segment count, so two outlines can
  /// be stitched point to point.
  static int _outline(
    Float32List into,
    Rect r,
    BorderRadius radius,
    double less,
    double scale, {
    int? segments,
  }) {
    final half = r.shortestSide / 2;
    double clamp(Radius corner) =>
        math.min(math.max(0, math.max(corner.x, corner.y) - less), half);
    final tl = clamp(radius.topLeft);
    final tr = clamp(radius.topRight);
    final br = clamp(radius.bottomRight);
    final bl = clamp(radius.bottomLeft);
    final count =
        segments ??
        _segmentsFor(math.max(math.max(tl, tr), math.max(br, bl)) * scale);
    final unit = _units[count]!;
    var k = 0;
    void arc(double x, double y, double rad) {
      for (var s = 0; s <= count; s++) {
        into[k] = x + unit[k] * rad;
        into[k + 1] = y + unit[k + 1] * rad;
        k += 2;
      }
    }

    arc(r.left + tl, r.top + tl, tl);
    arc(r.right - tr, r.top + tr, tr);
    arc(r.right - br, r.bottom - br, br);
    arc(r.left + bl, r.bottom - bl, bl);
    return k ~/ 2;
  }

  void draw(Canvas canvas) {
    if (_vertices == 0) return;
    canvas.drawVertices(
      ui.Vertices.raw(
        VertexMode.triangles,
        Float32List.sublistView(_positions, 0, _vertices * 2),
        colors: Int32List.sublistView(_colors, 0, _vertices),
      ),
      // The vertex colours alone: `dst` keeps them and ignores the paint.
      BlendMode.dst,
      Paint(),
    );
  }
}
