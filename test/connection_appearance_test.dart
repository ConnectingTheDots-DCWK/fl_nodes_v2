import 'dart:ui';

import 'package:fl_nodes_v2/fl_nodes_v2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const Color _number = Color(0xFF33AA55);
const Color _text = Color(0xFFAA3355);

void main() {
  GraphNode node(String id, Offset position, {Color? outColor}) => GraphNode(
    id: id,
    position: position,
    width: 140,
    height: 60,
    ports: <NodePort>[
      const NodePort.input(id: 'in'),
      NodePort.output(id: 'out', color: outColor),
    ],
  );

  NodeEditorController wired() {
    final controller = NodeEditorController(
      graph: NodeGraph(
        nodes: <GraphNode>[
          node('a', const Offset(60, 200), outColor: _number),
          node('b', const Offset(400, 200)),
        ],
        connections: const <NodeConnection>[
          NodeConnection(
            id: 'c1',
            from: PortRef('a', 'out'),
            to: PortRef('b', 'in'),
          ),
        ],
      ),
    );
    addTearDown(controller.dispose);
    return controller;
  }

  Widget harness(
    NodeEditorController controller, {
    ConnectionAppearanceResolver? appearance,
  }) => MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 800,
          height: 600,
          child: NodeEditor(
            controller: controller,
            theme: NodeEditorTheme.dark(),
            connectionAppearance: appearance,
            nodeBuilder: (context, graphNode, state) =>
                const ColoredBox(color: Color(0xFF2A2E38)),
          ),
        ),
      ),
    ),
  );

  Finder layerOf<T extends CustomPainter>() => find.byWidgetPredicate(
    (widget) => widget is CustomPaint && widget.painter is T,
  );

  testWidgets('a wire takes the colour and width the resolver gives it, '
      'asked with the ports it joins', (tester) async {
    final controller = wired();
    final asked = <(String, String)>[];
    await tester.pumpWidget(
      harness(
        controller,
        appearance: (connection, from, to) {
          asked.add((from.id, to.id));
          return ConnectionAppearance(color: from.color, width: 5);
        },
      ),
    );

    expect(asked, contains(('out', 'in')));
    expect(
      layerOf<ConnectionsPainter>(),
      paints..path(color: _number, strokeWidth: 5),
    );
  });

  testWidgets('a field the resolver leaves null falls back to the '
      "connection's own colour", (tester) async {
    final controller = NodeEditorController(
      graph: NodeGraph(
        nodes: <GraphNode>[
          node('a', const Offset(60, 200)),
          node('b', const Offset(400, 200)),
        ],
        connections: const <NodeConnection>[
          NodeConnection(
            id: 'c1',
            from: PortRef('a', 'out'),
            to: PortRef('b', 'in'),
            color: _text,
          ),
        ],
      ),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      harness(
        controller,
        appearance: (connection, from, to) =>
            const ConnectionAppearance(width: 4),
      ),
    );

    expect(
      layerOf<ConnectionsPainter>(),
      paints..path(color: _text, strokeWidth: 4),
    );
  });

  testWidgets('a selected wire is never drawn thinner than the host made it', (
    tester,
  ) async {
    final controller = wired();
    await tester.pumpWidget(
      harness(
        controller,
        appearance: (connection, from, to) =>
            const ConnectionAppearance(width: 6),
      ),
    );
    controller.selection.selectConnection('c1');
    await tester.pump();

    final theme = NodeEditorTheme.dark();
    expect(theme.selectedConnectionWidth, lessThan(6), reason: 'the premise');
    expect(
      layerOf<ConnectionsPainter>(),
      paints..path(color: theme.selectedConnectionColor, strokeWidth: 6),
    );
  });

  testWidgets('a lifted wire keeps its colour above the focus scrim', (
    tester,
  ) async {
    final controller = wired();
    await tester.pumpWidget(
      harness(
        controller,
        appearance: (connection, from, to) =>
            ConnectionAppearance(color: from.color),
      ),
    );
    // Lifted without a tint: what is drawn above the scrim is the wire's own
    // look, which used to be the theme's default however it was drawn below.
    controller.emphasis.value = const GraphEmphasis(
      nodes: <String, Color?>{'a': null, 'b': null},
      connections: <String, Color?>{'c1': null},
    );
    await tester.pump();

    expect(layerOf<EmphasisPainter>(), paints..path(color: _number));
  });

  group('a dash pattern', () {
    Path line(double length) => Path()
      ..moveTo(0, 0)
      ..lineTo(length, 0);

    int contours(Path path) => path.computeMetrics().length;

    test('cuts a path into its drawn lengths', () {
      final dashed = const ConnectionDash(<double>[10, 10]).apply(line(100));
      expect(contours(dashed), 5);
      expect(
        dashed.computeMetrics().map((metric) => metric.length),
        everyElement(closeTo(10, 0.01)),
      );
    });

    test('carries on across contours rather than restarting at each', () {
      // Two 15-unit pieces under a 10-on, 20-off pattern. Restarting would
      // draw 10 of each; carrying on draws 10 of the first and spends the
      // whole second piece inside the gap the first one started.
      final path = Path()
        ..moveTo(0, 0)
        ..lineTo(15, 0)
        ..moveTo(0, 50)
        ..lineTo(15, 50);
      final lengths = const ConnectionDash(<double>[
        10,
        20,
      ]).apply(path).computeMetrics().map((metric) => metric.length).toList();
      expect(lengths, <Matcher>[closeTo(10, 0.01)]);
    });

    test('an odd pattern repeats to make itself even', () {
      // [10] reads as [10, 10], as SVG's stroke-dasharray does.
      final dashed = const ConnectionDash(<double>[10]).apply(line(100));
      expect(contours(dashed), 5);
    });

    test('is cut once per curve and reused', () {
      final controller = wired();
      final layout = ConnectionLayout()..sync(controller);
      final geometry = layout['c1']!;

      final first = geometry.dashedPath(ConnectionDash.dashed);
      expect(
        identical(geometry.dashedPath(ConnectionDash.dashed), first),
        isTrue,
        reason: 'panning repaints every wire; the cut must not be repaid',
      );
      expect(
        identical(geometry.dashedPath(ConnectionDash.dotted), first),
        isFalse,
      );
    });
  });
}
