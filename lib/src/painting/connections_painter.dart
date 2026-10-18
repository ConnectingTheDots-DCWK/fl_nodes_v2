import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../geometry/viewport_transform.dart';
import '../model/node_connection.dart';
import '../model/node_graph.dart';
import '../definition/node_definition_registry.dart';
import '../theme/node_editor_theme.dart';
import 'connection_appearance.dart';
import 'connection_label.dart';
import 'connection_layout.dart';

/// Draws every connection curve beneath the node layer.
///
/// Two things keep this cheap on a dense graph. Paths come from
/// [ConnectionLayout], so nothing is recomputed while panning. And curves
/// sharing a stroke — a colour, a width and a dash pattern — are merged into
/// one [Path] and stroked in a single call, rather than paying per-connection
/// draw overhead: stroking a path with many subpaths gives the same result as
/// stroking each on its own. A graph that styles nothing is one batch.
class ConnectionsPainter extends CustomPainter {
  const ConnectionsPainter({
    required this.layout,
    required this.graph,
    required this.viewport,
    required this.theme,
    required this.selectedIds,
    required this.revision,
    required this.selectionRevision,
    this.hoveredId,
    this.hoveredWaypoint,
    this.labelStyle,
    this.definitions,
    this.appearance,
  });

  final ConnectionLayout layout;
  final NodeGraph graph;
  final ViewportTransform viewport;
  final NodeEditorTheme theme;
  final Set<String> selectedIds;

  /// [ConnectionLayout]'s invalidation key, used to decide repaints.
  final int revision;

  /// [NodeEditorSelection.revision], so a selection change repaints
  /// without comparing the sets themselves.
  final int selectionRevision;

  final String? hoveredId;

  /// The waypoint handle under the pointer, drawn like a hovered port.
  final WaypointRef? hoveredWaypoint;

  final TextStyle? labelStyle;

  /// Decides which links are captionable, so those without a caption yet still
  /// draw something to aim at.
  final NodeDefinitionRegistry? definitions;

  /// [NodeEditor.connectionAppearance], asked for every wire on screen.
  final ConnectionAppearanceResolver? appearance;

  /// Below this zoom, arrowheads and labels stop being readable and are
  /// skipped along with their layout cost.
  static const double _detailScaleThreshold =
      ConnectionLabel.detailScaleThreshold;

  @override
  void paint(Canvas canvas, Size size) {
    final visible = viewport.visibleSceneRect(size);
    final drawDetail = viewport.scale >= _detailScaleThreshold;

    // Curves painted in scene space under the viewport transform; stroke
    // widths are divided by the scale so they stay constant on screen.
    final normal = <ConnectionStroke, Path>{};
    final arrows = <Color, Path>{};
    final highlighted = <_Layer>[];

    for (final entry in layout.entriesIn(visible)) {
      final geometry = entry.value;
      final connection = graph.connections[entry.key];
      if (connection == null) continue;

      final stroke = connectionStroke(connection, graph, theme, appearance);
      final priority = _priority(entry.key);
      if (priority == 0) {
        (normal[stroke] ??= Path()).addPath(
          _pathOf(geometry, stroke, drawDetail),
          Offset.zero,
        );
        if (drawDetail) {
          (arrows[stroke.color] ??= Path()).addPath(
            _arrowheads(geometry, connection),
            Offset.zero,
          );
        }
      } else {
        highlighted.add(
          _Layer(priority, entry.key, geometry, connection, stroke),
        );
      }
    }

    canvas
      ..save()
      ..transform(viewport.toMatrix4().storage);

    normal.forEach((stroke, path) {
      canvas.drawPath(path, _strokePaint(stroke.color, stroke.width));
    });
    arrows.forEach((color, path) {
      canvas.drawPath(path, Paint()..color = color);
    });

    // Hovered, then selected, so they read on top of the batches.
    highlighted.sort((a, b) => a.priority - b.priority);
    for (final layer in highlighted) {
      final color = layer.priority == 2
          ? theme.selectedConnectionColor
          : theme.hoveredConnectionColor;
      // A selected wire is never drawn thinner than the host made it.
      final width = layer.priority == 2
          ? math.max(layer.stroke.width, theme.selectedConnectionWidth)
          : layer.stroke.width;
      canvas.drawPath(
        _pathOf(layer.geometry, layer.stroke, drawDetail),
        _strokePaint(color, width),
      );
      if (drawDetail) {
        canvas.drawPath(
          _arrowheads(layer.geometry, layer.connection),
          Paint()..color = color,
        );
      }
    }

    if (drawDetail) _paintWaypoints(canvas, visible);

    canvas.restore();

    if (drawDetail) _paintLabels(canvas, visible);
  }

  /// The handles of every routed wire on screen, in scene space.
  ///
  /// Batched by fill colour the way the curves are, with one border pass in
  /// the canvas colour so a handle reads over its own wire. Drawn only at
  /// the detail zoom, and [NodeEditorState] hits them under the same gate —
  /// the port rule: a dot too small to see must not be grabbable.
  void _paintWaypoints(Canvas canvas, Rect visible) {
    final radius = theme.waypointRadius / math.min(viewport.scale, 1.5);
    final fills = <Color, Path>{};
    final borders = Path();

    for (final entry in layout.entriesIn(visible)) {
      final connection = graph.connections[entry.key];
      if (connection == null || connection.waypoints.isEmpty) continue;
      final priority = _priority(entry.key);
      final wireColor = switch (priority) {
        2 => theme.selectedConnectionColor,
        1 => theme.hoveredConnectionColor,
        _ => connectionStroke(connection, graph, theme, appearance).color,
      };
      for (final (index, point) in connection.waypoints.indexed) {
        if (!visible.contains(point)) continue;
        final hovered =
            hoveredWaypoint != null &&
            hoveredWaypoint!.connectionId == entry.key &&
            hoveredWaypoint!.index == index;
        final color = hovered ? theme.portHoverColor : wireColor;
        final r = hovered ? radius * 1.3 : radius;
        final rect = Rect.fromCircle(center: point, radius: r);
        (fills[color] ??= Path()).addOval(rect);
        borders.addOval(rect);
      }
    }

    if (fills.isEmpty) return;
    fills.forEach((color, path) {
      canvas.drawPath(path, Paint()..color = color);
    });
    canvas.drawPath(
      borders,
      Paint()
        ..color = theme.background
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 / viewport.scale,
    );
  }

  /// The curve as [stroke] draws it: cut into dashes from the cache, or whole
  /// below the detail zoom, where a dash would be a pixel long.
  static Path _pathOf(
    ConnectionGeometry geometry,
    ConnectionStroke stroke,
    bool drawDetail,
  ) {
    final dash = stroke.dash;
    return dash == null || !drawDetail
        ? geometry.path
        : geometry.dashedPath(dash);
  }

  int _priority(String id) {
    if (selectedIds.contains(id)) return 2;
    if (id == hoveredId) return 1;
    return 0;
  }

  Paint _strokePaint(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth =
        math.max(1, width * math.min(viewport.scale, 1.5)) / viewport.scale
    ..strokeCap = StrokeCap.round;

  /// Filled triangles along the curve, in scene units.
  ///
  /// One per marker cached on the geometry, angled to the curve's own slope
  /// there and pointing from the emitting port towards the receiving one. Any
  /// that would land under a caption are dropped: the caption sits at the
  /// midpoint, which is exactly where an odd-numbered run puts one.
  Path _arrowheads(ConnectionGeometry geometry, NodeConnection connection) {
    final caption = ConnectionLabel.captionFor(
      text: geometry.caption,
      anchor: geometry.labelAnchor,
      editable: definitions?.allowsLabelEditing(connection) ?? false,
      viewport: viewport,
      style: labelStyle,
    );
    final avoid = caption?.rect.inflate(2);

    return arrowheadsPath(
      geometry.arrows,
      arrowheadSize(viewport.scale),
      skip: avoid == null
          ? null
          : (position) => avoid.contains(viewport.toScreen(position)),
    );
  }

  /// Labels are drawn in screen space so they keep a constant size, unlike
  /// the curves they sit on.
  void _paintLabels(Canvas canvas, Rect visible) {
    for (final entry in layout.entriesIn(visible)) {
      final anchor = entry.value.labelAnchor;
      if (anchor == null || !visible.contains(anchor)) continue;
      final connection = graph.connections[entry.key];
      if (connection == null) continue;

      final caption = ConnectionLabel.captionFor(
        text: entry.value.caption,
        anchor: anchor,
        editable: definitions?.allowsLabelEditing(connection) ?? false,
        viewport: viewport,
        style: labelStyle,
      );
      if (caption == null) continue;

      canvas.drawRRect(
        RRect.fromRectAndRadius(caption.rect, const Radius.circular(4)),
        Paint()..color = theme.background.withValues(alpha: 0.92),
      );
      ConnectionLabel.layout(
        caption.text,
        caption.style,
        viewport.scale,
      ).paint(canvas, caption.textOrigin);
    }
  }

  @override
  bool shouldRepaint(ConnectionsPainter oldDelegate) =>
      oldDelegate.revision != revision ||
      oldDelegate.viewport != viewport ||
      oldDelegate.theme != theme ||
      oldDelegate.hoveredId != hoveredId ||
      oldDelegate.hoveredWaypoint != hoveredWaypoint ||
      oldDelegate.selectionRevision != selectionRevision ||
      !identical(oldDelegate.definitions, definitions) ||
      !identical(oldDelegate.appearance, appearance);
}

class _Layer {
  const _Layer(
    this.priority,
    this.id,
    this.geometry,
    this.connection,
    this.stroke,
  );

  final int priority;
  final String id;
  final ConnectionGeometry geometry;
  final NodeConnection connection;
  final ConnectionStroke stroke;
}
