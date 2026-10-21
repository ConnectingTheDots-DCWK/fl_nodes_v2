import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_nodes_v2/fl_nodes_v2.dart';
import 'package:fl_nodes_v2/src/painting/sketch_cache.dart';
import 'package:fl_nodes_v2/src/painting/sketch_painter.dart';
import 'package:fl_nodes_v2/src/widgets/comment_view.dart';

void main() {
  const size = Size(200, 120);
  const ink = Color(0xFFE8EAEF);
  const style = TextStyle(fontSize: 12, height: 1.4, color: ink);

  GraphNode node(String id, {Offset position = Offset.zero, String? title}) =>
      GraphNode(
        id: id,
        position: position,
        width: size.width,
        height: size.height,
        data: <String, Object?>{'title': title ?? id},
      );

  NodeSketch card(GraphNode node, Size size) => NodeSketch(
    fill: const Color(0xFF21242B),
    radius: const BorderRadius.all(Radius.circular(12)),
    border: const Color(0xFF262A32),
    parts: <SketchPart>[
      SketchBox(
        Rect.fromLTWH(0, 0, size.width, 36),
        const Color(0xFF4A3B1A),
        radius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      SketchText(
        Rect.fromLTWH(12, 0, size.width - 24, 36),
        node.data['title']! as String,
        style,
      ),
    ],
  );

  // Everything over the fill that is not the border: in these sketches, the
  // text's bars and nothing else.
  List<SketchShape> bars(ResolvedSketch sketch) => <SketchShape>[
    for (final shape in sketch.shapes.skip(1))
      if (shape.ring == 0 && shape.color.a < 1) shape,
  ];

  group('text becomes bars', () {
    test('one bar per line, inside the text box, at the ink alpha', () {
      final box = const Rect.fromLTWH(10, 40, 120, 60);
      final sketch = ResolvedSketch.of(
        NodeSketch(
          fill: const Color(0xFF000000),
          parts: <SketchPart>[
            SketchText(
              box,
              'A line long enough that it has to wrap at least once or '
              'twice inside a box this narrow',
              style,
              maxLines: null,
            ),
          ],
        ),
        size,
      );

      final lines = bars(sketch);
      expect(lines.length, greaterThan(1));
      for (final line in lines) {
        expect(box.contains(line.rect.topLeft), isTrue);
        expect(line.rect.right, lessThanOrEqualTo(box.right + 0.01));
        expect(line.rect.height, closeTo(12 * 0.56, 0.01));
        expect(line.color.a, closeTo(sketchInk, 0.01));
      }
      expect(
        lines.last.rect.bottom,
        lessThanOrEqualTo(box.bottom + 0.5),
        reason: 'a line the box cuts off is not drawn by the card either',
      );
    });

    test('lines past the bottom of the box are left out', () {
      final sketch = ResolvedSketch.of(
        NodeSketch(
          fill: const Color(0xFF000000),
          parts: <SketchPart>[
            SketchText(
              const Rect.fromLTWH(0, 0, 60, 20),
              'one two three four five six seven eight nine ten',
              style,
              maxLines: null,
            ),
          ],
        ),
        size,
      );
      expect(bars(sketch), hasLength(1));
    });

    test('one line is centred in its row, and right-aligned text ends at '
        'the right of its box', () {
      final row = const Rect.fromLTWH(0, 40, 180, 30);
      final sketch = ResolvedSketch.of(
        NodeSketch(
          fill: const Color(0xFF000000),
          parts: <SketchPart>[
            SketchText(row, 'Out', style, align: TextAlign.right),
          ],
        ),
        size,
      );
      final bar = bars(sketch).single.rect;
      expect(bar.right, closeTo(row.right, 0.5));
      expect(bar.center.dy, closeTo(row.center.dy, 4));
    });

    test('no text, no bar', () {
      final sketch = ResolvedSketch.of(
        const NodeSketch(
          fill: Color(0xFF000000),
          parts: <SketchPart>[
            SketchText(Rect.fromLTWH(0, 0, 100, 20), '', style),
          ],
        ),
        size,
      );
      expect(sketch.shapes, hasLength(1));
    });
  });

  group('what drops out with the zoom', () {
    final sketch = ResolvedSketch.of(card(node('n'), size), size);

    test('everything is drawn up close, the border last', () {
      final shapes = sketchShapesAt(sketch, 1).toList();
      expect(shapes, hasLength(sketch.shapes.length));
      expect(shapes.last.ring, 1);
    });

    test('a border under half a pixel goes', () {
      expect(sketchShapesAt(sketch, 0.51).any((s) => s.ring > 0), isTrue);
      expect(sketchShapesAt(sketch, 0.49).any((s) => s.ring > 0), isFalse);
    });

    test('a corner under a pixel is squared', () {
      // 12 scene units of radius is a pixel at 1/12.
      expect(
        sketchShapesAt(sketch, 0.09).first.radius,
        isNot(BorderRadius.zero),
      );
      expect(sketchShapesAt(sketch, 0.08).first.radius, BorderRadius.zero);
    });

    test('a bar under a pixel is drawn a pixel thick and fainter, and '
        'under a third of one it goes', () {
      // A 12px font's bar is 6.72 tall: a pixel at about 0.149.
      List<SketchShape> barsAt(double scale) => <SketchShape>[
        for (final shape in sketchShapesAt(sketch, scale))
          if (shape.color.a < 1) shape,
      ];
      final full = barsAt(0.15).single;
      expect(full.rect.height, closeTo(6.72, 0.01));
      expect(full.color.a, closeTo(sketchInk, 0.01));

      final thin = barsAt(0.1).single;
      expect(thin.rect.height * 0.1, closeTo(1, 0.001));
      expect(thin.color.a, closeTo(sketchInk * 0.672, 0.01));

      expect(barsAt(0.045), hasLength(1));
      expect(barsAt(0.044), isEmpty);
    });

    test('a node under three pixels is one box, tinted by its header', () {
      // 120 tall: three pixels at 0.025.
      expect(
        sketchShapesAt(sketch, 0.026).first.color,
        const Color(0xFF21242B),
        reason: 'the body itself, with what is too small dropped',
      );
      final dot = sketchShapesAt(sketch, 0.024).single;
      expect(dot.rect, Offset.zero & size);
      expect(dot.color, sketch.flat);
      expect(
        sketch.flat,
        isNot(const Color(0xFF21242B)),
        reason: 'the header band is part of how a card is told apart',
      );
    });
  });

  group('the cache', () {
    test('asks once while the node is the same instance', () {
      final cache = SketchCache();
      var asked = 0;
      NodeSketch counting(GraphNode n, Size s) {
        asked++;
        return card(n, s);
      }

      final n = node('a');
      final first = cache.resolve(n, size, counting);
      expect(identical(cache.resolve(n, size, counting), first), isTrue);
      expect(asked, 1);
    });

    test('a node that only moved keeps its bars', () {
      final cache = SketchCache();
      final n = node('a');
      final first = cache.resolve(n, size, card);
      final moved = n.copyWith(position: const Offset(500, 500));
      expect(identical(cache.resolve(moved, size, card), first), isTrue);
      expect(cache.debugResolveCount, 1);
    });

    test('a changed node, a new size, or a new function lays it out again', () {
      final cache = SketchCache();
      final n = node('a', title: 'Before');
      cache.resolve(n, size, card);

      cache.resolve(node('a', title: 'After'), size, card);
      expect(cache.debugResolveCount, 2);

      cache.resolve(node('a', title: 'After'), const Size(200, 160), card);
      expect(cache.debugResolveCount, 3);

      NodeSketch other(GraphNode n, Size s) =>
          const NodeSketch(fill: Color(0xFFFFFFFF));
      cache.resolve(node('a', title: 'After'), const Size(200, 160), other);
      expect(cache.debugResolveCount, 4);
    });

    test('clear forgets everything, prune forgets the departed', () {
      final cache = SketchCache();
      final a = node('a');
      final b = node('b');
      cache
        ..resolve(a, size, card)
        ..resolve(b, size, card)
        ..prune(<String, GraphNode>{'a': a});
      expect(cache.length, 1);

      cache
        ..clear()
        ..resolve(a, size, card);
      expect(cache.debugResolveCount, 3);
    });
  });

  group('the painter', () {
    SketchPainter painter(
      List<GraphNode> nodes, {
      double scale = 0.2,
      Set<String> selected = const <String>{},
    }) {
      final cache = SketchCache();
      return SketchPainter(
        nodes: nodes,
        sketchOf: (n) => cache.resolve(n, size, card),
        origin: Offset.zero,
        scale: scale,
        theme: NodeEditorTheme.dark(),
        revision: 0,
        selectionRevision: 0,
        selected: selected,
      );
    }

    List<RecordedInvocation> record(SketchPainter painter) {
      final canvas = TestRecordingCanvas();
      painter.paint(canvas, const Size(800, 600));
      return canvas.invocations;
    }

    int calls(List<RecordedInvocation> invocations, Symbol name) =>
        invocations.where((i) => i.invocation.memberName == name).length;

    test('every node in one draw, whatever its colours', () {
      final nodes = <GraphNode>[
        for (var i = 0; i < 50; i++)
          node('n$i', position: Offset(i * 220.0, 0)),
      ];
      final invocations = record(painter(nodes, scale: 0.4));
      expect(calls(invocations, #drawVertices), 1);
      expect(calls(invocations, #drawRRect), 0);
      expect(calls(invocations, #drawPath), 0);
    });

    test('a selected node is ringed, and nothing at all draws nothing', () {
      final invocations = record(
        painter(<GraphNode>[node('a'), node('b')], selected: <String>{'b'}),
      );
      expect(calls(invocations, #drawRRect), 1);

      expect(calls(record(painter(const <GraphNode>[])), #drawVertices), 0);
    });
  });

  test('a note is sketched with its text inside its padding', () {
    final note = NodeComment.create(
      id: 'note',
      position: Offset.zero,
      text: 'Low scores skip the reply entirely.',
    );
    final sketch = ResolvedSketch.of(
      commentSketch(note, const Size(260, 70), const Color(0xFF0D0F13)),
      const Size(260, 70),
    );
    final lines = bars(sketch);
    expect(lines, isNotEmpty);
    expect(lines.first.rect.left, closeTo(12, 0.5));
  });
}
