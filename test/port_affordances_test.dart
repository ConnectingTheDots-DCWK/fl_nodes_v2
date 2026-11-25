import 'dart:ui' as ui;

import 'package:fl_nodes_v2/fl_nodes_v2.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The two things a handle says about itself before a wire is traced: what
/// kind of pin it is, by its shape, and what it carries, by a label the host
/// writes.
void main() {
  group('port shapes', () {
    test('a control pin and a data pin are told apart by default', () {
      final theme = NodeEditorTheme.dark();
      expect(theme.shapeOf(PortKind.control), PortShape.triangle);
      expect(theme.shapeOf(PortKind.data), PortShape.circle);
    });

    test('a host that wants the old row of dots says so once', () {
      final plain = NodeEditorTheme.dark().copyWith(
        controlPortShape: PortShape.circle,
      );
      expect(plain.shapeOf(PortKind.control), PortShape.circle);
      expect(plain.shapeOf(PortKind.data), PortShape.circle);
    });

    test('the shapes are part of what makes two themes different', () {
      final theme = NodeEditorTheme.dark();
      expect(theme.copyWith(), theme);
      expect(
        theme.copyWith(controlPortShape: PortShape.diamond),
        isNot(theme),
        reason: 'a repaint has to follow a shape somebody changed',
      );
    });

    test('every shape sits on its row, in the circle they share', () {
      for (final shape in PortShape.values) {
        final bounds = shape.path(const Offset(50, 50), 6).getBounds();
        expect(
          bounds.center.dy,
          closeTo(50, 0.001),
          reason: '$shape is level with the handles either side of it',
        );
        expect(
          bounds.contains(const Offset(50, 50)),
          isTrue,
          reason: '$shape covers the point the wire attaches to',
        );
        // Within a few pixels of the circle they share, so a row of mixed
        // shapes reads as one row rather than as two sizes.
        expect(
          bounds.longestSide,
          closeTo(12, 3),
          reason: '$shape is about as big as the dot beside it',
        );
      }
    });

    test('a shape is built on its circumradius, not its bounding box', () {
      // The anchor is the wire's attachment and the hit target's centre, so
      // it is the *circumcentre* that sits on the row. A triangle's box is
      // therefore offset towards its tip, and that is the shape being
      // correct rather than a shape being off-centre.
      final circle = PortShape.circle.path(Offset.zero, 6).getBounds();
      expect(circle.center.dx, closeTo(0, 0.001));
      final triangle = PortShape.triangle.path(Offset.zero, 6).getBounds();
      expect(triangle.center.dx, greaterThan(0));
    });

    test('a triangle points the same way at both ends of a wire', () {
      final bounds = PortShape.triangle.path(Offset.zero, 6).getBounds();
      expect(
        bounds.right,
        greaterThan(-bounds.left),
        reason:
            'the tip is the rightmost point and the flat back is behind it, '
            'so an input and an output both read left to right',
      );
    });
  });

  group('a shape per port', () {
    // One handle, large, in the middle of a 100-unit square, so a pixel
    // inside a square's corner and outside the circle tells the two apart.
    final theme = NodeEditorTheme.dark().copyWith(portRadius: 12);
    const node = GraphNode(
      id: 'n',
      position: Offset.zero,
      width: 100,
      height: 100,
      ports: <NodePort>[NodePort.input(id: 'many', anchor: Offset(0.5, 0.5))],
    );

    PortsPainter painter({PortShapeResolver? shapeOf}) => PortsPainter(
      nodes: const <GraphNode>[node],
      sizeOf: (_) => const Size(100, 100),
      connectedPorts: const <String, Set<String>>{
        'n': <String>{'many'},
      },
      viewport: ViewportTransform.identity,
      theme: theme,
      revision: 0,
      selectionRevision: 0,
      coversOf: (_) => const <Rect>[],
      shapeOf: shapeOf,
    );

    /// The alpha of the pixel just inside the square's corner, at offsets of
    /// nine to ten from the anchor on both axes: past the circle of radius
    /// twelve, within the square of half-side ten and a half.
    Future<int> cornerAlpha(WidgetTester tester, PortsPainter painter) async {
      final recorder = ui.PictureRecorder();
      painter.paint(Canvas(recorder), const Size(100, 100));
      final picture = recorder.endRecording();
      final alpha = await tester.runAsync(() async {
        final image = await picture.toImage(100, 100);
        final bytes = await image.toByteData();
        image.dispose();
        return bytes!.getUint8((59 * 100 + 59) * 4 + 3);
      });
      picture.dispose();
      return alpha!;
    }

    testWidgets("the host's answer is what is drawn, and none is the theme's", (
      tester,
    ) async {
      final asked = <(String, String)>[];
      final square = painter(
        shapeOf: (node, port) {
          asked.add((node.id, port.id));
          return PortShape.square;
        },
      );
      expect(await cornerAlpha(tester, square), greaterThan(200));
      expect(asked, <(String, String)>[('n', 'many')]);

      expect(
        await cornerAlpha(tester, painter(shapeOf: (_, _) => null)),
        0,
        reason: "null leaves the theme's dot for a data port",
      );
      expect(await cornerAlpha(tester, painter()), 0);
    });

    test('a new resolver repaints the handles', () {
      PortShape? square(GraphNode node, NodePort port) => PortShape.square;
      final before = painter(shapeOf: square);
      expect(painter(shapeOf: square).shouldRepaint(before), isFalse);
      expect(
        painter(shapeOf: (_, _) => PortShape.pill).shouldRepaint(before),
        isTrue,
      );
    });

    test('a pill stands upright', () {
      final bounds = PortShape.pill.path(Offset.zero, 6).getBounds();
      expect(bounds.height, greaterThan(bounds.width * 1.5));
    });
  });

  group('port tooltips', () {
    // Driven through NodeEditor.portTooltip and a real hover, not the
    // callback in isolation: these used to pin a contract the widget never
    // exercised, leaving the actual hover-to-label path untested.
    final NodeEditorTheme theme = NodeEditorTheme.dark();

    GraphNode node() => GraphNode(
      id: 'n',
      type: 't',
      position: const Offset(100, 100),
      width: 160,
      height: 90,
      ports: const <NodePort>[
        NodePort.input(id: 'exec', kind: PortKind.control),
        NodePort.input(id: 'value', kind: PortKind.data),
      ],
    );

    Future<NodeEditorController> boot(
      WidgetTester tester, {
      String? Function(GraphNode, NodePort)? portTooltip,
    }) async {
      final controller = NodeEditorController(
        graph: NodeGraph(nodes: <GraphNode>[node()]),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NodeEditor(
              controller: controller,
              theme: theme,
              portTooltip: portTooltip,
              nodeBuilder: (context, graphNode, state) =>
                  const ColoredBox(color: Color(0xFF2A2E38)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return controller;
    }

    Offset screenPoint(
      WidgetTester tester,
      NodeEditorController controller,
      Offset scenePoint,
    ) =>
        tester.getTopLeft(find.byType(NodeEditor)) +
        controller.camera.viewport.toScreen(scenePoint);

    testWidgets(
      'hovering the port the host labels shows the label; one it declines '
      'shows nothing',
      (tester) async {
        final controller = await boot(
          tester,
          portTooltip: (node, port) => port.id == 'value' ? 'A number' : null,
        );
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        addTearDown(mouse.removePointer);

        await mouse.moveTo(
          screenPoint(
            tester,
            controller,
            controller.layout.portPosition(const PortRef('n', 'value'))!,
          ),
        );
        await tester.pump();
        expect(find.text('A number'), findsOneWidget);

        // Nothing else in this tree writes a Text widget, so its absence
        // here is the null-return case actually showing nothing rather than
        // the earlier label simply lingering.
        await mouse.moveTo(
          screenPoint(
            tester,
            controller,
            controller.layout.portPosition(const PortRef('n', 'exec'))!,
          ),
        );
        await tester.pump();
        expect(find.byType(Text), findsNothing);
      },
    );

    testWidgets('with no portTooltip at all, a hovered port shows nothing', (
      tester,
    ) async {
      final controller = await boot(tester);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);

      await mouse.moveTo(
        screenPoint(
          tester,
          controller,
          controller.layout.portPosition(const PortRef('n', 'value'))!,
        ),
      );
      await tester.pump();

      expect(find.byType(Text), findsNothing);
    });
  });
}
