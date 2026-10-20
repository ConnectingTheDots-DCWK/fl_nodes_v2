import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_nodes_v2/fl_nodes_v2.dart';

import 'widget_benchmark.dart' show body, nodeBuilds;

const Size kViewport = Size(1600, 900);
const int kNodes = 5000;

/// Zoom levels visited, from 1.0 down to the theme's floor in equal ratios,
/// so each step brings roughly the same multiple of nodes into view.
const int kSteps = 8;

/// Frames spent zooming from one level to the next, and then holding there
/// while panning, at every step.
const int kFrames = 12;

/// A grid about as wide as it is tall, so zooming out fills the screen rather
/// than running off the end of a strip.
NodeEditorController buildSquareGrid(int count) {
  final columns = math.sqrt(count * 1.6).ceil();
  final nodes = <GraphNode>[];
  final connections = <NodeConnection>[];
  for (var i = 0; i < count; i++) {
    nodes.add(
      GraphNode(
        id: 'n$i',
        position: Offset((i % columns) * 260.0, (i ~/ columns) * 160.0),
        width: 220,
        height: 120,
        ports: const <NodePort>[
          NodePort.input(id: 'in'),
          NodePort.output(id: 'out'),
        ],
        data: <String, Object?>{'title': 'Node $i'},
      ),
    );
    if (i % columns != 0) {
      connections.add(
        NodeConnection(
          id: 'c$i',
          from: PortRef('n${i - 1}', 'out'),
          to: PortRef('n$i', 'in'),
        ),
      );
    }
  }
  return NodeEditorController(
    graph: NodeGraph(nodes: nodes, connections: connections),
  );
}

int bodyLayouts = 0;
int bodyPaints = 0;

/// Counts how often the editor lays out and paints a body it already has,
/// which a build counter cannot see: a body handed back unchanged is not
/// built, but it can still be laid out and painted again.
class _Probe extends SingleChildRenderObjectWidget {
  const _Probe({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderProbe();
}

class _RenderProbe extends RenderProxyBox {
  @override
  void performLayout() {
    bodyLayouts++;
    super.performLayout();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    bodyPaints++;
    super.paint(context, offset);
  }
}

/// What zooming out costs on the UI thread, level by level.
///
/// The question it answers is where the work goes as more of the graph comes
/// into view, which is what level of detail would have to remove. Per zoom
/// level it reports the nodes drawn and, both while zooming to that level and
/// while panning at it, the time per frame and how many bodies were built,
/// laid out and painted per frame. Then it zooms back in, which is the
/// direction that mounts bodies.
///
/// `flutter test` never rasterises, so this prices only the UI thread; the
/// raster half is `example/lib/bench.dart` with `SCENARIO=zoom`. The times
/// are JIT and machine-dependent; the counts are not.
///
/// ```sh
/// flutter test benchmark/zoom_benchmark.dart
/// ```
void main() {
  // Off for the reason `widget_benchmark.dart` gives: an app runs without it.
  testWidgets('zoom-out benchmark', semanticsEnabled: false, (tester) async {
    tester.view.physicalSize = kViewport;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final controller = buildSquareGrid(kNodes);
    addTearDown(controller.dispose);
    final theme = NodeEditorTheme.dark();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NodeEditor(
            controller: controller,
            theme: theme,
            nodeBuilder: (context, node, state) =>
                _Probe(child: body(context, node, state)),
          ),
        ),
      ),
    );
    final bounds = controller.graph.contentBounds(controller.layout.sizeOf)!;
    controller.camera.centerOn(bounds.center, kViewport);
    await tester.pumpAndSettle();

    final camera = controller.camera;
    final focal = kViewport.center(Offset.zero);
    final ratio = math.pow(theme.minScale, 1 / kSteps).toDouble();
    final levels = <double>[
      for (var k = 0; k <= kSteps; k++) math.pow(ratio, k).toDouble(),
    ];

    int drawn() => controller.layout
        .nodesIn(camera.viewport.visibleSceneRect(kViewport))
        .length;

    /// Runs [frames] frames of [step] and returns the cost per frame.
    Future<String> measure(void Function() step) async {
      nodeBuilds = bodyLayouts = bodyPaints = 0;
      final watch = Stopwatch()..start();
      for (var i = 0; i < kFrames; i++) {
        step();
        await tester.pump();
      }
      watch.stop();
      String per(int n) => (n / kFrames).toStringAsFixed(1).padLeft(7);
      return '${(watch.elapsedMicroseconds / kFrames / 1000).toStringAsFixed(2).padLeft(7)}ms'
          '${per(nodeBuilds)}${per(bodyLayouts)}${per(bodyPaints)}';
    }

    final rows = <String>[];
    Future<void> visit(double from, double to) async {
      final factor = math.pow(to / from, 1 / kFrames).toDouble();
      final zooming = await measure(
        () => camera.zoomBy(factor, focalScreenPoint: focal),
      );
      camera.setScale(to, focalScreenPoint: focal);
      await tester.pump();
      final panning = await measure(() => camera.panBy(const Offset(3, 2)));
      rows.add(
        '${to.toStringAsFixed(3).padLeft(6)}${drawn().toString().padLeft(7)}'
        '  |$zooming  |$panning',
      );
    }

    for (var k = 1; k < levels.length; k++) {
      await visit(levels[k - 1], levels[k]);
    }
    rows.add('--- and back in ---');
    for (var k = levels.length - 2; k >= 0; k--) {
      await visit(levels[k + 1], levels[k]);
    }

    debugPrint(
      '\n--- $kNodes nodes, ${controller.graph.connections.length} links, '
      '${kViewport.width.toInt()}x${kViewport.height.toInt()} ---\n'
      'per frame, $kFrames frames each\n'
      '                 | zooming to this level              | panning at it\n'
      '  zoom  drawn  |   time  built   laid  painted |   time  built   laid  painted\n'
      '${rows.join('\n')}',
    );
  });
}
