import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:fl_nodes_v2/fl_nodes_v2.dart';

import 'workflow_node.dart';

/// The pieces `bench.dart` prices level of detail with: a card whose features
/// can be switched off one at a time, and three ways of drawing every visible
/// node from a single painter instead of a widget each.
///
/// None of this is a design. The painters draw what a tier *would* draw, at
/// about the cost it would take, so the sweep can say what each is worth.

const Color _surface = Color(0xFF232733);
const Color _border = Color(0xFF32384A);
const Color _accent = Color(0xFF6E97F0);
const Color _titleInk = Color(0xFFE6E9F0);
const Color _bodyInk = Color(0xFF98A0B4);

/// The stress graph's card — `WorkflowNodeCard` for an action node — rebuilt
/// with each feature behind a switch, to price them one at a time.
class BenchCard extends StatelessWidget {
  const BenchCard({
    super.key,
    required this.node,
    this.text = true,
    this.border = true,
    this.round = true,
    this.shadow = true,
  });

  final GraphNode node;
  final bool text;
  final bool border;
  final bool round;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final radius = round ? 8.0 : 0.0;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(radius),
        border: border
            ? Border.all(color: _border, width: CardMetrics.borderWidth)
            : null,
        boxShadow: shadow
            ? const <BoxShadow>[
                BoxShadow(
                  color: Color(0x2E000000),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            height: CardMetrics.headerHeight,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(round ? 7 : 0),
              ),
            ),
            child: Row(
              children: <Widget>[
                if (text)
                  const Icon(Icons.play_arrow_rounded, size: 15, color: _accent)
                else
                  const SizedBox(width: 15),
                const SizedBox(width: 7),
                if (text)
                  Expanded(
                    child: Text(
                      node.title,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _titleInk,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: text
                ? Text(
                    node.subtitle ?? '',
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.35,
                      color: _bodyInk,
                    ),
                  )
                : const SizedBox(height: 15.5),
          ),
        ],
      ),
    );
  }
}

/// [BenchCard] as a sketch, part for part, for `SKETCH=on`.
NodeSketch benchSketch(GraphNode node, Size size) => NodeSketch(
  fill: _surface,
  radius: const BorderRadius.all(Radius.circular(8)),
  border: _border,
  borderWidth: CardMetrics.borderWidth,
  parts: <SketchPart>[
    SketchBox(
      Rect.fromLTWH(0, 0, size.width, CardMetrics.headerHeight),
      _accent.withValues(alpha: 0.16),
      radius: const BorderRadius.vertical(top: Radius.circular(7)),
    ),
    SketchBox(
      Rect.fromLTWH(10, (CardMetrics.headerHeight - 11) / 2, 11, 11),
      _accent,
      radius: const BorderRadius.all(Radius.circular(2)),
    ),
    SketchText(
      Rect.fromLTWH(32, 0, size.width - 42, CardMetrics.headerHeight),
      node.title,
      const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: _titleInk,
      ),
    ),
    SketchText(
      Rect.fromLTRB(
        10,
        CardMetrics.headerHeight + 8,
        size.width - 10,
        size.height - 10,
      ),
      node.subtitle ?? '',
      const TextStyle(fontSize: 11.5, height: 1.35, color: _bodyInk),
      maxLines: null,
    ),
  ],
);

/// Which painter tier [TierPainter] draws.
enum Tier { atlas, card, blocks }

/// Every visible node drawn by one painter, as a tier below full detail would.
class TierPainter extends CustomPainter {
  TierPainter({required this.controller, required this.tier, this.atlas})
    : super(repaint: controller);

  final NodeEditorController controller;
  final Tier tier;
  final SnapshotAtlas? atlas;

  @override
  void paint(Canvas canvas, Size size) {
    final viewport = controller.camera.viewport;
    final nodes = controller.layout.nodesIn(viewport.visibleSceneRect(size));
    switch (tier) {
      case Tier.atlas:
        atlas!.paint(canvas, nodes, viewport);
      case Tier.card:
        _paintCards(canvas, nodes, viewport);
      case Tier.blocks:
        _paintBlocks(canvas, nodes, viewport);
    }
  }

  Rect _screenRect(GraphNode node, ViewportTransform viewport) {
    final origin = viewport.toScreen(node.position);
    return origin & Size(node.width, node.height ?? 74) * viewport.scale;
  }

  /// A card from its summary: rounded box, accent header, bars for text. The
  /// radius and border are scene sizes, so they shrink away on their own.
  void _paintCards(
    Canvas canvas,
    List<GraphNode> nodes,
    ViewportTransform viewport,
  ) {
    final scale = viewport.scale;
    final radius = 8 * scale;
    final drawBorder = CardMetrics.borderWidth * scale >= 0.5;
    final fill = Paint()..color = _surface;
    final header = Paint()
      ..color = Color.alphaBlend(_accent.withValues(alpha: 0.16), _surface);
    final edge = Paint()
      ..color = _border
      ..style = PaintingStyle.stroke
      ..strokeWidth = CardMetrics.borderWidth * scale;
    final bars = _Quads();
    for (final node in nodes) {
      final box = _screenRect(node, viewport);
      final headerBox = Rect.fromLTWH(
        box.left,
        box.top,
        box.width,
        CardMetrics.headerHeight * scale,
      );
      if (radius >= 1) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(box, Radius.circular(radius)),
          fill,
        );
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            headerBox,
            topLeft: Radius.circular(radius),
            topRight: Radius.circular(radius),
          ),
          header,
        );
        if (drawBorder) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(box, Radius.circular(radius)),
            edge,
          );
        }
      } else {
        canvas.drawRect(box, fill);
        canvas.drawRect(headerBox, header);
      }
      _textBars(bars, node, box, scale);
    }
    bars.draw(canvas);
  }

  /// Flat boxes in the card's average colour, and bars, in one call.
  void _paintBlocks(
    Canvas canvas,
    List<GraphNode> nodes,
    ViewportTransform viewport,
  ) {
    final average = Color.lerp(
      _surface,
      Color.alphaBlend(_accent.withValues(alpha: 0.16), _surface),
      CardMetrics.headerHeight / 74,
    )!;
    final quads = _Quads();
    for (final node in nodes) {
      final box = _screenRect(node, viewport);
      quads.add(box, average);
      _textBars(quads, node, box, viewport.scale);
    }
    quads.draw(canvas);
  }

  /// Where the card's lines of text are, at the ink's average tone.
  static void _textBars(_Quads quads, GraphNode node, Rect box, double s) {
    final title = node.title.length * 7.4;
    quads.add(
      Rect.fromLTWH(box.left + 32 * s, box.top + 15 * s, title * s, 7 * s),
      _titleInk.withValues(alpha: 0.45),
    );
    final body = (node.subtitle ?? '').length * 5.6;
    quads.add(
      Rect.fromLTWH(box.left + 10 * s, box.top + 50 * s, body * s, 6 * s),
      _bodyInk.withValues(alpha: 0.45),
    );
  }

  @override
  bool shouldRepaint(TierPainter oldDelegate) =>
      oldDelegate.tier != tier || oldDelegate.atlas != atlas;
}

/// Coloured rectangles, batched into one `drawVertices`.
class _Quads {
  final List<double> _positions = <double>[];
  final List<int> _colors = <int>[];

  void add(Rect r, Color color) {
    _positions.addAll(<double>[
      r.left, r.top, r.right, r.top, r.right, r.bottom, //
      r.left, r.top, r.right, r.bottom, r.left, r.bottom,
    ]);
    final argb = color.toARGB32();
    for (var i = 0; i < 6; i++) {
      _colors.add(argb);
    }
  }

  void draw(Canvas canvas) {
    if (_colors.isEmpty) return;
    canvas.drawVertices(
      ui.Vertices.raw(
        VertexMode.triangles,
        Float32List.fromList(_positions),
        colors: Int32List.fromList(_colors),
      ),
      BlendMode.dst,
      Paint(),
    );
  }
}

/// Snapshots of the card packed into texture pages, drawn with `drawAtlas`.
///
/// A real one would hold a snapshot per node on or near the screen; this one
/// holds [cells] distinct snapshots and hands node `n` cell `n % cells`, which
/// samples the same number of pages a real cache would at this density.
class SnapshotAtlas {
  SnapshotAtlas._(this.pages, this.cellSize, this.perPage, this.ratio);

  final List<ui.Image> pages;
  final Size cellSize;
  final int perPage;

  /// Image pixels per scene unit: the capture zoom times the device ratio.
  final double ratio;

  int get cells => pages.length * perPage;

  static const int _pageSize = 2048;

  /// Draws [count] cards at [captureScale] into as many pages as they need.
  static SnapshotAtlas build({
    required int count,
    required double captureScale,
    required double devicePixelRatio,
  }) {
    final ratio = captureScale * devicePixelRatio;
    final cell = Size(
      (CardMetrics.width * ratio).ceilToDouble(),
      (74 * ratio).ceilToDouble(),
    );
    final columns = _pageSize ~/ cell.width;
    final perPage = columns * (_pageSize ~/ cell.height);
    final pages = <ui.Image>[];
    for (var first = 0; first < count; first += perPage) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      for (var i = first; i < count && i < first + perPage; i++) {
        final slot = i - first;
        canvas
          ..save()
          ..translate(
            (slot % columns) * cell.width,
            (slot ~/ columns) * cell.height,
          )
          ..scale(ratio);
        _drawCard(canvas, 'Step $i');
        canvas.restore();
      }
      pages.add(recorder.endRecording().toImageSync(_pageSize, _pageSize));
    }
    return SnapshotAtlas._(pages, cell, perPage, ratio);
  }

  static void _drawCard(Canvas canvas, String title) {
    final box = Offset.zero & const Size(CardMetrics.width, 74);
    final rrect = RRect.fromRectAndRadius(box, const Radius.circular(8));
    canvas
      ..drawRRect(rrect, Paint()..color = _surface)
      ..drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(0, 0, CardMetrics.width, CardMetrics.headerHeight),
          topLeft: const Radius.circular(8),
          topRight: const Radius.circular(8),
        ),
        Paint()..color = _accent.withValues(alpha: 0.16),
      )
      ..drawRRect(
        rrect.deflate(0.5),
        Paint()
          ..color = _border
          ..style = PaintingStyle.stroke,
      );
    void text(String value, double size, Color ink, Offset at) {
      final builder =
          ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: size, maxLines: 1))
            ..pushStyle(ui.TextStyle(color: ink, fontSize: size))
            ..addText(value);
      final paragraph = builder.build()
        ..layout(const ui.ParagraphConstraints(width: 180));
      canvas.drawParagraph(paragraph, at);
      paragraph.dispose();
    }

    text(title, 13, _titleInk, const Offset(32, 11));
    text('Generated node.', 11.5, _bodyInk, const Offset(10, 46));
  }

  void paint(Canvas canvas, List<GraphNode> nodes, ViewportTransform viewport) {
    final columns = 2048 ~/ cellSize.width;
    final transforms = List<List<RSTransform>>.generate(
      pages.length,
      (_) => <RSTransform>[],
    );
    final rects = List<List<Rect>>.generate(pages.length, (_) => <Rect>[]);
    final factor = viewport.scale / ratio;
    for (final node in nodes) {
      final index = (int.tryParse(node.id.substring(1)) ?? 0) % cells;
      final page = index ~/ perPage;
      final slot = index % perPage;
      final origin = viewport.toScreen(node.position);
      transforms[page].add(
        RSTransform.fromComponents(
          rotation: 0,
          scale: factor,
          anchorX: 0,
          anchorY: 0,
          translateX: origin.dx,
          translateY: origin.dy,
        ),
      );
      rects[page].add(
        Offset(
              (slot % columns) * cellSize.width,
              (slot ~/ columns) * cellSize.height,
            ) &
            cellSize,
      );
    }
    final paint = Paint()..filterQuality = FilterQuality.medium;
    for (var p = 0; p < pages.length; p++) {
      if (rects[p].isEmpty) continue;
      canvas.drawAtlas(
        pages[p],
        transforms[p],
        rects[p],
        null,
        null,
        null,
        paint,
      );
    }
  }
}
