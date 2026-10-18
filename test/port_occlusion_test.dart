import 'package:fl_nodes_v2/fl_nodes_v2.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // `a` sits underneath `b`, which is added after it and so drawn over it.
  // `b`'s left edge is four units short of `a`'s exit, so the exit is half
  // under `b`: the half at x < 236 is in the clear, the rest is covered.
  const exit = Offset(240, 130);
  const radius = 11.0;

  GraphNode a() => const GraphNode(
    id: 'a',
    position: Offset(100, 100),
    width: 140,
    height: 60,
    ports: <NodePort>[
      NodePort.input(id: 'in'),
      NodePort.output(id: 'out'),
    ],
  );

  GraphNode b({List<NodePort> ports = const <NodePort>[]}) => GraphNode(
    id: 'b',
    position: const Offset(236, 80),
    width: 140,
    height: 100,
    ports: ports,
  );

  NodeEditorController overlapping({GraphNode? over}) {
    final controller = NodeEditorController(
      graph: NodeGraph(nodes: <GraphNode>[a(), over ?? b()]),
    );
    addTearDown(controller.dispose);
    return controller;
  }

  PortRef? portAt(NodeEditorController controller, Offset point) =>
      controller.layout.portAt(point, radius: radius);

  group('picking', () {
    test('a handle under a card cannot be picked through it', () {
      final controller = overlapping();
      expect(
        controller.layout.portPosition(const PortRef('a', 'out')),
        exit,
        reason: 'the premise the geometry below rests on',
      );

      expect(portAt(controller, exit + const Offset(3, 0)), isNull);
      expect(
        portAt(controller, exit + const Offset(-7, 0)),
        const PortRef('a', 'out'),
        reason: 'the half of the handle no card covers is still grabbable',
      );
    });

    test('a covered handle does not shadow a visible one farther off', () {
      // b's own entry is 7 units from the probe; a's exit, under b, is 3.
      final controller = overlapping(
        over: b(ports: const <NodePort>[NodePort.input(id: 'in')]),
      );
      expect(
        portAt(controller, exit + const Offset(3, 0)),
        const PortRef('b', 'in'),
      );
    });

    test('selecting the lower node raises its handles with it', () {
      final controller = overlapping();
      controller.selection.selectNode('a');
      expect(
        portAt(controller, exit + const Offset(3, 0)),
        const PortRef('a', 'out'),
      );
    });
  });

  test('overlapping nodes stack in document order, and a press agrees', () {
    // Forty, because Dart's sort is an insertion sort — and so stable —
    // up to thirty-two elements, which would hide an order left to chance.
    final ids = <String>[for (var i = 0; i < 40; i++) 'n$i'];
    final controller = NodeEditorController(
      graph: NodeGraph(
        nodes: <GraphNode>[
          for (final id in ids)
            GraphNode(id: id, position: Offset.zero, width: 100, height: 50),
        ],
      ),
    );
    addTearDown(controller.dispose);

    expect(<String>[
      for (final node in controller.layout.nodesIn(
        const Rect.fromLTWH(0, 0, 100, 50),
      ))
        node.id,
    ], ids);
    expect(controller.layout.nodeAt(const Offset(50, 25))?.id, 'n39');

    controller.selection.selectNode('n5');
    expect(controller.layout.nodeAt(const Offset(50, 25))?.id, 'n5');
  });

  group('on the canvas', () {
    Widget harness(NodeEditorController controller) => MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 800,
            height: 600,
            child: NodeEditor(
              controller: controller,
              theme: NodeEditorTheme.dark(),
              nodeBuilder: (context, node, state) =>
                  const ColoredBox(color: Color(0xFF2A2E38)),
            ),
          ),
        ),
      ),
    );

    Finder portsLayer() => find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is PortsPainter,
    );

    testWidgets('a press on the top card over a hidden handle drags the '
        'card and starts no wire', (tester) async {
      final controller = overlapping();
      await tester.pumpWidget(harness(controller));

      // Within the hit radius of a's exit, and inside b: the reporter's
      // purple line started here.
      final gesture = await tester.startGesture(
        exit + const Offset(8, 0),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(controller.graph.connections, isEmpty);
      expect(
        controller.graph.nodes['b']!.position,
        isNot(const Offset(236, 80)),
        reason: 'the press belonged to the card on top',
      );
    });

    testWidgets('a covered node draws its handles clipped out of the card '
        'over them, and an uncovered graph clips nothing', (tester) async {
      final controller = overlapping();
      await tester.pumpWidget(harness(controller));
      expect(
        portsLayer(),
        paints..clipRect(rect: const Rect.fromLTWH(236, 80, 140, 100)),
      );

      controller.moveNodes(<String, Offset>{'b': const Offset(600, 300)});
      await tester.pump();
      expect(portsLayer(), isNot(paints..clipRect()));
    });

    testWidgets('selecting the covered node repaints its handles', (
      tester,
    ) async {
      final controller = overlapping();
      await tester.pumpWidget(harness(controller));
      final before =
          tester.widget<CustomPaint>(portsLayer()).painter! as PortsPainter;

      controller.selection.selectNode('a');
      await tester.pump();
      final after =
          tester.widget<CustomPaint>(portsLayer()).painter! as PortsPainter;
      expect(after.shouldRepaint(before), isTrue);
      expect(portsLayer(), isNot(paints..clipRect()));
    });
  });
}
