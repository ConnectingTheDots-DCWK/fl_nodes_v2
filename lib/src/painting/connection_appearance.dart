import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../model/node_connection.dart';
import '../model/node_graph.dart';
import '../model/node_port.dart';
import '../theme/node_editor_theme.dart';

/// Asked how a wire should look, every time it is painted.
///
/// Handed the connection and the two ports it joins, so a wire can take the
/// colour of the type it carries. Null, or a null field, keeps the default.
typedef ConnectionAppearanceResolver =
    ConnectionAppearance? Function(
      NodeConnection connection,
      NodePort from,
      NodePort to,
    );

/// How one wire is drawn: its colour, its width and whether it is dashed.
///
/// Every field is optional and falls back on its own — [color] to the
/// connection's own `color` and then to [NodeEditorTheme.connectionColor],
/// [width] to [NodeEditorTheme.connectionWidth], and [dash] to a solid line.
/// The hover and selection colours are still the theme's: a highlight is the
/// editor saying something about the wire, not the host.
@immutable
class ConnectionAppearance {
  const ConnectionAppearance({this.color, this.width, this.dash});

  final Color? color;

  /// In the units of [NodeEditorTheme.connectionWidth].
  final double? width;

  final ConnectionDash? dash;

  @override
  bool operator ==(Object other) =>
      other is ConnectionAppearance &&
      other.color == color &&
      other.width == width &&
      other.dash == dash;

  @override
  int get hashCode => Object.hash(color, width, dash);
}

/// A dash pattern: alternating lengths drawn and skipped, in scene units.
///
/// Scene units rather than screen pixels so a dashed wire is dashed once,
/// when its curve is built, and not again on every zoom. Below
/// [ConnectionLabel.detailScaleThreshold] a dashed wire is drawn solid: its
/// dashes would be a pixel or two long, and the pass is not worth paying for
/// a line nobody can tell from a solid one.
@immutable
class ConnectionDash {
  /// [intervals] alternate drawn and skipped, starting with drawn. An odd
  /// count is repeated to make it even, as SVG's `stroke-dasharray` does.
  const ConnectionDash(this.intervals);

  static const ConnectionDash dashed = ConnectionDash(<double>[8, 6]);

  /// Short strokes the round cap turns into dots.
  static const ConnectionDash dotted = ConnectionDash(<double>[0.5, 6]);

  final List<double> intervals;

  /// [path] cut into this pattern.
  ///
  /// The pattern carries on across the path's contours, so a wire routed
  /// through waypoints is dashed as one line rather than restarting at each.
  Path apply(Path path) {
    final pattern = intervals.length.isOdd
        ? <double>[...intervals, ...intervals]
        : intervals;
    final total = pattern.fold<double>(0, (sum, length) => sum + length);
    if (pattern.isEmpty || total <= 0 || pattern.any((l) => l < 0)) {
      return path;
    }

    final dashed = Path();
    var index = 0;
    var remaining = pattern[0];
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final step = remaining < metric.length - distance
            ? remaining
            : metric.length - distance;
        if (index.isEven && step > 0) {
          dashed.addPath(
            metric.extractPath(distance, distance + step),
            Offset.zero,
          );
        }
        distance += step;
        remaining -= step;
        if (remaining <= 0) {
          index = (index + 1) % pattern.length;
          remaining = pattern[index];
        }
      }
    }
    return dashed;
  }

  @override
  bool operator ==(Object other) =>
      other is ConnectionDash && listEquals(other.intervals, intervals);

  @override
  int get hashCode => Object.hashAll(intervals);
}

/// The stroke a wire is painted with once the resolver and the defaults have
/// both had their say. Also the key the painters batch by, so it is a value.
typedef ConnectionStroke = ({Color color, double width, ConnectionDash? dash});

/// The one place a wire's stroke is decided, for [ConnectionsPainter] and for
/// [EmphasisPainter]'s redraw above the scrim — or a lifted wire would change
/// colour as the focus lands on it.
ConnectionStroke connectionStroke(
  NodeConnection connection,
  NodeGraph graph,
  NodeEditorTheme theme,
  ConnectionAppearanceResolver? resolve,
) {
  ConnectionAppearance? appearance;
  if (resolve != null) {
    final from = graph.nodes[connection.from.nodeId]?.portById(
      connection.from.portId,
    );
    final to = graph.nodes[connection.to.nodeId]?.portById(
      connection.to.portId,
    );
    if (from != null && to != null) appearance = resolve(connection, from, to);
  }
  return (
    color: appearance?.color ?? connection.color ?? theme.connectionColor,
    width: appearance?.width ?? theme.connectionWidth,
    dash: appearance?.dash,
  );
}
