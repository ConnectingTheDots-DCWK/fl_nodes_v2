import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../model/graph_node.dart';

/// Describes [node] as it should look zoomed out, laid out at [size].
///
/// Asked once per node and cached: again when the node changes, when the
/// function itself changes, and when [NodeSketches.refresh] fires. So it may
/// lay a card out from scratch, but it should read only the node and what
/// [NodeSketches.refresh] announces — anything else it reads goes stale.
typedef NodeSketcher = NodeSketch Function(GraphNode node, Size size);

/// Level of detail: zoomed out past [below], nodes are drawn from the host's
/// sketch by one painter instead of being built as widgets.
///
/// **The host describes, the package draws.** A sketch is plain data — boxes,
/// bars and text in the node's own coordinates — so the package can draw a
/// screenful of nodes in one pass and still know nothing about what they
/// are. Text is handed over as text and turned into bars here, one per line
/// it would wrap to, so a sketch lines up with the card it stands in for
/// without the host measuring anything.
///
/// There is one switch. Past it, each part of a sketch drops out by itself
/// once it is too small to see, so a card thins down to a flat block as the
/// zoom falls rather than stepping through a second look.
@immutable
class NodeSketches {
  const NodeSketches({
    required this.sketch,
    this.below = 0.25,
    this.refresh,
    this.mountsPerFrame = 48,
  });

  /// Pass the same function on every build: sketches are cached against it,
  /// and a new one redraws every sketch — which is also the way to say that
  /// all of them are stale.
  final NodeSketcher sketch;

  /// The zoom under which nodes are sketched. The switch is made a little
  /// either side of it, so a zoom that settles on the line cannot flicker
  /// between the two.
  final double below;

  /// Fires when something a sketch reads, other than its node, has changed —
  /// a passage the card previews, a status it shows. Every cached sketch is
  /// dropped and asked for again as it is next drawn.
  final Listenable? refresh;

  /// How many nodes may be built in one frame while their sketches stand in
  /// for the rest — nearest the middle of the view first.
  ///
  /// Zooming back in past [below] would otherwise build every node on screen
  /// in the same frame, and that is hundreds of them; so would panning fast
  /// into a crowded part of the board. Lower it for a node that is expensive
  /// to build, raise it for one that is cheap.
  final int mountsPerFrame;

  @override
  bool operator ==(Object other) =>
      other is NodeSketches &&
      other.sketch == sketch &&
      other.below == below &&
      other.refresh == refresh &&
      other.mountsPerFrame == mountsPerFrame;

  @override
  int get hashCode => Object.hash(sketch, below, refresh, mountsPerFrame);
}

/// One node, zoomed out: a filled box with an optional border and [parts]
/// drawn over it, in the node's coordinates.
///
/// Selection and the connection-target ring are the editor's, as they are on
/// a built node, and are not part of a sketch.
@immutable
class NodeSketch {
  const NodeSketch({
    required this.fill,
    this.radius = BorderRadius.zero,
    this.border,
    this.borderWidth = 1,
    this.halo,
    this.parts = const <SketchPart>[],
  });

  final Color fill;
  final BorderRadius radius;

  /// Drawn inside the node's box, as a [BoxDecoration]'s border is.
  final Color? border;
  final double borderWidth;

  /// A ring around the node that stays visible however far out the canvas
  /// is zoomed — for a mark that has to be found from a distance.
  final Color? halo;

  /// Painted in order over [fill].
  final List<SketchPart> parts;

  @override
  bool operator ==(Object other) =>
      other is NodeSketch &&
      other.fill == fill &&
      other.radius == radius &&
      other.border == border &&
      other.borderWidth == borderWidth &&
      other.halo == halo &&
      listEquals(other.parts, parts);

  @override
  int get hashCode => Object.hash(
    fill,
    radius,
    border,
    borderWidth,
    halo,
    Object.hashAll(parts),
  );
}

/// Something drawn over a [NodeSketch]'s fill.
sealed class SketchPart {
  const SketchPart();
}

/// A filled box: a header band, a field, a swatch.
final class SketchBox extends SketchPart {
  const SketchBox(this.rect, this.color, {this.radius = BorderRadius.zero});

  final Rect rect;
  final Color color;
  final BorderRadius radius;

  @override
  bool operator ==(Object other) =>
      other is SketchBox &&
      other.rect == rect &&
      other.color == color &&
      other.radius == radius;

  @override
  int get hashCode => Object.hash(rect, color, radius);
}

/// A bar where something the host already measured would be, drawn as it is
/// given. For text, [SketchText] does the measuring.
final class SketchBar extends SketchPart {
  const SketchBar(this.rect, this.color);

  final Rect rect;
  final Color color;

  @override
  bool operator ==(Object other) =>
      other is SketchBar && other.rect == rect && other.color == color;

  @override
  int get hashCode => Object.hash(rect, color);
}

/// Text inside [rect], drawn as one bar per line it lays out to.
///
/// Laid out with [style] the way a `Text` with the same [maxLines] and
/// [align] would be, so each bar is as long as its line and sits where the
/// line's lowercase letters would. One line is centred in [rect] vertically,
/// as a label in a row is; more start at its top, as a paragraph does.
/// Lines that would fall below [rect] are not drawn.
final class SketchText extends SketchPart {
  const SketchText(
    this.rect,
    this.text,
    this.style, {
    this.maxLines = 1,
    this.align = TextAlign.start,
  });

  final Rect rect;
  final String text;
  final TextStyle style;

  /// Null for as many as the text wraps to.
  final int? maxLines;
  final TextAlign align;

  @override
  bool operator ==(Object other) =>
      other is SketchText &&
      other.rect == rect &&
      other.text == text &&
      other.style == style &&
      other.maxLines == maxLines &&
      other.align == align;

  @override
  int get hashCode => Object.hash(rect, text, style, maxLines, align);
}
