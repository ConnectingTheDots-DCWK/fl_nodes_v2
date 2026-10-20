import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_nodes_v2/fl_nodes_v2.dart';
import 'package:fl_nodes_v2/src/painting/sketch_painter.dart';
import 'package:fl_nodes_v2/src/widgets/comment_view.dart';

void main() {
  GraphNode node(String id, Offset position) => GraphNode(
    id: id,
    position: position,
    width: 200,
    height: 100,
    ports: const <NodePort>[
      NodePort.input(id: 'in'),
      NodePort.output(id: 'out'),
    ],
    data: <String, Object?>{'title': id},
  );

  NodeEditorController controllerOf(List<GraphNode> nodes) =>
      NodeEditorController(graph: NodeGraph(nodes: nodes));

  NodeEditorController pair() => controllerOf(<GraphNode>[
    node('a', const Offset(100, 100)),
    node('b', const Offset(600, 100)),
  ]);

  var asked = 0;
  NodeSketch card(GraphNode node, Size size) {
    asked++;
    return NodeSketch(
      fill: const Color(0xFF21242B),
      parts: <SketchPart>[
        SketchText(
          Rect.fromLTWH(10, 0, size.width - 20, 30),
          node.id,
          const TextStyle(fontSize: 12, color: Color(0xFFFFFFFF)),
        ),
      ],
    );
  }

  Widget harness(
    NodeEditorController controller, {
    NodeSketches? sketches,
    NodeWidgetBuilder? builder,
    void Function(GraphNode)? onDoubleTap,
    void Function(GraphNode, Offset)? onSecondaryTap,
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
            sketches: sketches,
            onNodeDoubleTap: onDoubleTap,
            onNodeSecondaryTap: onSecondaryTap,
            nodeBuilder:
                builder ??
                (context, graphNode, state) => ColoredBox(
                  key: ValueKey<String>('body_${graphNode.id}'),
                  color: const Color(0xFF2A2E38),
                ),
          ),
        ),
      ),
    ),
  );

  final sketched = NodeSketches(sketch: card);

  void zoom(NodeEditorController controller, double scale) =>
      controller.camera.viewport = ViewportTransform(
        offset: Offset.zero,
        scale: scale,
      );

  int bodies(WidgetTester tester) => find
      .byWidgetPredicate((widget) {
        final key = widget.key;
        return key is ValueKey<String> && key.value.startsWith('body_');
      })
      .evaluate()
      .length;

  Iterable<SketchPainter> sketchPainters(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((widget) => widget.painter)
      .whereType<SketchPainter>();

  /// The centre of [id] on screen.
  Offset centreOf(NodeEditorController controller, String id) {
    final n = controller.graph.nodes[id]!;
    return controller.camera.viewport.toScreen(
      n.position + Offset(n.width / 2, (n.height ?? 0) / 2),
    );
  }

  setUp(() => asked = 0);

  group('the switch', () {
    testWidgets('below the threshold nothing is built, above it everything '
        'is, with a band between where the last answer stands', (tester) async {
      final controller = pair();
      addTearDown(controller.dispose);
      await tester.pumpWidget(harness(controller, sketches: sketched));
      expect(bodies(tester), 2);

      // Down: still built inside the band, sketched past it.
      zoom(controller, 0.24);
      await tester.pump();
      expect(bodies(tester), 2, reason: 'inside the band, still built');
      zoom(controller, 0.21);
      await tester.pump();
      expect(bodies(tester), 0);
      expect(sketchPainters(tester).single.nodes, hasLength(2));

      // Up: still sketched inside the band, built past it.
      zoom(controller, 0.27);
      await tester.pump();
      expect(bodies(tester), 0, reason: 'inside the band, still sketched');
      zoom(controller, 0.29);
      await tester.pump();
      expect(bodies(tester), 2);
      expect(sketchPainters(tester), isEmpty);
    });

    testWidgets('with no sketches every node is built at any zoom', (
      tester,
    ) async {
      final controller = pair();
      addTearDown(controller.dispose);
      zoom(controller, 0.15);
      await tester.pumpWidget(harness(controller));
      expect(bodies(tester), 2);
      expect(sketchPainters(tester), isEmpty);
      expect(asked, 0);
    });

    testWidgets('a note is sketched by the package, not by the host', (
      tester,
    ) async {
      final controller = controllerOf(<GraphNode>[
        node('a', const Offset(100, 100)),
        NodeComment.create(
          id: 'note',
          position: const Offset(600, 100),
          text: 'A note',
        ),
      ]);
      addTearDown(controller.dispose);
      zoom(controller, 0.2);
      await tester.pumpWidget(harness(controller, sketches: sketched));
      await tester.pump();
      expect(find.byType(CommentView), findsNothing);
      expect(sketchPainters(tester).single.nodes, hasLength(2));
      expect(asked, 1, reason: 'only the host node is the host\'s to sketch');
    });

    testWidgets('a focus lifts its sketches over the scrim with it', (
      tester,
    ) async {
      final controller = pair();
      addTearDown(controller.dispose);
      zoom(controller, 0.2);
      controller.emphasis.value = const GraphEmphasis(
        nodes: <String, Color?>{'b': null},
      );
      await tester.pumpWidget(harness(controller, sketches: sketched));

      final bands = sketchPainters(tester).toList();
      expect(
        bands.map((p) => p.nodes.map((n) => n.id).toList()),
        <List<String>>[
          <String>['a'],
          <String>['b'],
        ],
      );
      final layers = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((widget) => widget.painter)
          .where((p) => p is SketchPainter || p is EmphasisPainter)
          .map((p) => p.runtimeType)
          .toList();
      expect(layers, <Type>[SketchPainter, EmphasisPainter, SketchPainter]);
    });

    test('ports go away where the sketches begin', () {
      expect(
        NodeEditorTheme.dark().portMinScale,
        const NodeSketches(sketch: _never).below,
        reason:
            'handles drawn over a sketch belong to a card that is no longer '
            'there, and one missing over a built card cannot be grabbed',
      );
    });
  });

  group('laying sketches out', () {
    testWidgets('a frame spends a budget on it, and a node waiting for its '
        'sketch stays built until it has one', (tester) async {
      final controller = controllerOf(<GraphNode>[
        for (var i = 0; i < 12; i++) node('n$i', Offset(i * 250.0, 100)),
      ]);
      addTearDown(controller.dispose);
      NodeSketch slow(GraphNode node, Size size) {
        final clock = Stopwatch()..start();
        while (clock.elapsedMicroseconds < 1500) {}
        return card(node, size);
      }

      await tester.pumpWidget(
        harness(controller, sketches: NodeSketches(sketch: slow)),
      );
      zoom(controller, 0.2);
      await tester.pump();
      final first = bodies(tester);
      expect(first, inInclusiveRange(1, 11), reason: 'some, not all');

      for (var frame = 0; frame < 12 && bodies(tester) > 0; frame++) {
        await tester.pump();
      }
      expect(bodies(tester), 0);
    });

    testWidgets('they are laid out ahead of the switch, while the zoom is '
        'on its way there', (tester) async {
      final controller = pair();
      addTearDown(controller.dispose);
      await tester.pumpWidget(harness(controller, sketches: sketched));
      expect(asked, 0);
      zoom(controller, 0.35);
      await tester.pump();
      expect(bodies(tester), 2);
      expect(asked, 2, reason: 'ready before they are needed');

      zoom(controller, 0.2);
      await tester.pump();
      expect(asked, 2, reason: 'and not asked again at the switch');
    });

    testWidgets('a refresh asks again; a pan does not', (tester) async {
      final controller = pair();
      addTearDown(controller.dispose);
      final refresh = ChangeNotifier();
      addTearDown(refresh.dispose);
      zoom(controller, 0.2);
      await tester.pumpWidget(
        harness(
          controller,
          sketches: NodeSketches(sketch: card, refresh: refresh),
        ),
      );
      expect(asked, 2);

      controller.camera.panBy(const Offset(30, 10));
      await tester.pump();
      expect(asked, 2);

      refresh.notifyListeners();
      await tester.pump();
      expect(asked, 4);
    });
  });

  group('coming back in', () {
    NodeEditorController grid() => controllerOf(<GraphNode>[
      for (var i = 0; i < 60; i++)
        node('n$i', Offset((i % 10) * 250.0, (i ~/ 10) * 150.0)),
    ]);
    final few = NodeSketches(sketch: card, mountsPerFrame: 10);

    testWidgets('the first build of a board builds it whole', (tester) async {
      final controller = grid();
      addTearDown(controller.dispose);
      zoom(controller, 0.3);
      await tester.pumpWidget(harness(controller, sketches: few));
      expect(bodies(tester), 60);
      expect(sketchPainters(tester), isEmpty);
    });

    testWidgets('a crowd is built a few a frame, nearest the middle first, '
        'with sketches standing in for the rest', (tester) async {
      final controller = grid();
      addTearDown(controller.dispose);
      zoom(controller, 0.3);
      await tester.pumpWidget(harness(controller, sketches: few));
      zoom(controller, 0.2);
      await tester.pump();
      expect(bodies(tester), 0);

      zoom(controller, 0.3);
      await tester.pump();
      expect(bodies(tester), 10);
      final standing = sketchPainters(tester).single.nodes;
      expect(standing, hasLength(50));

      // The ten built are the ten nearest the middle of the view.
      final centre = controller.camera.viewport
          .visibleSceneRect(const Size(800, 600))
          .center;
      double distance(GraphNode n) =>
          (n.position + const Offset(100, 50) - centre).distance;
      final built = controller.graph.nodes.values
          .where(
            (n) => find
                .byKey(ValueKey<String>('body_${n.id}'))
                .evaluate()
                .isNotEmpty,
          )
          .map(distance);
      final waiting = standing.map(distance);
      expect(
        built.reduce((a, b) => a > b ? a : b),
        lessThanOrEqualTo(waiting.reduce((a, b) => a < b ? a : b)),
      );

      for (var frame = 0; frame < 5; frame++) {
        await tester.pump();
      }
      expect(bodies(tester), 60, reason: 'all of them by the sixth frame');
      expect(sketchPainters(tester), isEmpty);
    });
  });

  group('a sketch answers presses', () {
    testWidgets('a tap selects, a double tap reaches the host, a right '
        'click is the node\'s', (tester) async {
      final controller = pair();
      addTearDown(controller.dispose);
      final doubled = <String>[];
      final secondary = <String>[];
      zoom(controller, 0.2);
      await tester.pumpWidget(
        harness(
          controller,
          sketches: sketched,
          onDoubleTap: (n) => doubled.add(n.id),
          onSecondaryTap: (n, _) => secondary.add(n.id),
        ),
      );

      await tester.tapAt(
        centreOf(controller, 'b'),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(controller.selection.nodeIds, <String>{'b'});
      await tester.tapAt(
        centreOf(controller, 'b'),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(doubled, <String>['b']);

      await tester.tapAt(
        centreOf(controller, 'a'),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryButton,
      );
      await tester.pump();
      expect(secondary, <String>['a']);
    });

    testWidgets('a drag moves it, and a sweep from empty canvas still '
        'selects', (tester) async {
      final controller = pair();
      addTearDown(controller.dispose);
      zoom(controller, 0.2);
      await tester.pumpWidget(harness(controller, sketches: sketched));

      final drag = await tester.startGesture(
        centreOf(controller, 'a'),
        kind: PointerDeviceKind.mouse,
      );
      await drag.moveBy(const Offset(20, 0));
      await drag.moveBy(const Offset(20, 0));
      await drag.up();
      await tester.pump();
      expect(
        controller.graph.nodes['a']!.position.dx,
        closeTo(100 + 40 / 0.2, 1),
      );
      expect(controller.graph.nodes['b']!.position, const Offset(600, 100));

      controller.selection.clear();
      final sweep = await tester.startGesture(
        const Offset(5, 5),
        kind: PointerDeviceKind.mouse,
      );
      await sweep.moveBy(const Offset(200, 60));
      await sweep.up();
      await tester.pump();
      expect(controller.selection.nodeIds, containsAll(<String>['a', 'b']));
    });
  });

  group('what stays built', () {
    testWidgets('a node dragged across the threshold keeps its drag', (
      tester,
    ) async {
      final controller = pair();
      addTearDown(controller.dispose);
      zoom(controller, 0.3);
      await tester.pumpWidget(harness(controller, sketches: sketched));

      final drag = await tester.startGesture(
        centreOf(controller, 'a'),
        kind: PointerDeviceKind.mouse,
      );
      await drag.moveBy(const Offset(30, 0));
      await tester.pump();

      zoom(controller, 0.2);
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('body_a')),
        findsOneWidget,
        reason: 'unmounting it would end the drag',
      );
      expect(find.byKey(const ValueKey<String>('body_b')), findsNothing);

      final before = controller.graph.nodes['a']!.position;
      await drag.moveBy(const Offset(30, 0));
      await tester.pump();
      expect(controller.graph.nodes['a']!.position.dx, greaterThan(before.dx));
      await drag.up();
      await tester.pump();
      await tester.pump();
      expect(bodies(tester), 0, reason: 'once let go it is a sketch again');
    });

    testWidgets('a node holding the focus keeps what is typed in it', (
      tester,
    ) async {
      final controller = pair();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        harness(
          controller,
          sketches: sketched,
          builder: (context, graphNode, state) => SizedBox(
            key: ValueKey<String>('body_${graphNode.id}'),
            width: 200,
            height: 100,
            child: Material(
              child: TextField(key: ValueKey('field_${graphNode.id}')),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey<String>('field_a')));
      await tester.enterText(
        find.byKey(const ValueKey<String>('field_a')),
        'half',
      );

      zoom(controller, 0.2);
      await tester.pump();
      expect(find.text('half'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('body_b')), findsNothing);
    });
  });
}

NodeSketch _never(GraphNode node, Size size) => throw StateError('not called');
