import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_nodes_v2/fl_nodes_v2.dart';
import 'package:fl_nodes_v2/src/painting/sketch_cache.dart';
import 'package:fl_nodes_v2/src/painting/sketch_painter.dart';

/// What sketches cost the UI thread: laying them out the first time a
/// screenful is zoomed out, and recording a frame of them after that.
///
/// 2592 nodes is what a 2560x1348 window holds at 15% (`CLAUDE.md`, *Zoomed
/// out*). The card is shaped like the heaviest one ripple_effect draws — a
/// header, a six-line preview of prose and three choice rows — so the text
/// measured is about what a real board would hand over. `flutter test` runs
/// in JIT, so read the numbers as an upper bound.
const int kNodes = 2592;
const Size kCard = Size(320, 260);

const TextStyle _title = TextStyle(fontSize: 13, color: Color(0xFFE8EAEF));
const TextStyle _prose = TextStyle(
  fontSize: 12,
  height: 1.4,
  color: Color(0xFF99A0AE),
);

const String _passage =
    'The gates of Elsenmar stand open, though nobody seems to be guarding '
    'them. A cart lies overturned in the road, its load of turnips spilled '
    'across the cobbles, and somewhere beyond the wall a bell is ringing '
    'with the steady patience of somebody who has been told to keep going '
    'until they are told to stop.';

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
      Rect.fromLTWH(36, 0, size.width - 48, 36),
      node.data['title']! as String,
      _title,
    ),
    SketchBox(
      Rect.fromLTWH(12, 48, size.width - 24, 110),
      const Color(0xFF1A1D23),
    ),
    SketchText(
      Rect.fromLTWH(20, 54, size.width - 40, 100),
      '${node.id} $_passage',
      _prose,
      maxLines: 6,
    ),
    for (var i = 0; i < 3; i++)
      SketchText(
        Rect.fromLTWH(12, 170.0 + i * 26, size.width - 40, 26),
        'Choice ${i + 1} of ${node.id}',
        _prose,
        align: TextAlign.right,
      ),
  ],
);

void main() {
  final nodes = <GraphNode>[
    for (var i = 0; i < kNodes; i++)
      GraphNode(
        id: 'n$i',
        position: Offset((i % 72) * 360.0, (i ~/ 72) * 300.0),
        width: kCard.width,
        height: kCard.height,
        data: <String, Object?>{'title': 'Passage $i'},
      ),
  ];

  test('laying out a screenful of sketches', () {
    final cache = SketchCache();
    final watch = Stopwatch()..start();
    for (final node in nodes) {
      cache.resolve(node, kCard, card);
    }
    watch.stop();
    final shapes = nodes.fold<int>(
      0,
      (sum, node) => sum + cache.resolve(node, kCard, card).shapes.length,
    );
    debugPrint(
      'resolve: $kNodes sketches in ${watch.elapsedMilliseconds} ms '
      '(${(watch.elapsedMicroseconds / kNodes).toStringAsFixed(1)} us each), '
      '${(shapes / kNodes).toStringAsFixed(1)} shapes a node',
    );
  });

  test('recording a frame of them', () {
    final cache = SketchCache();
    for (final node in nodes) {
      cache.resolve(node, kCard, card);
    }
    for (final scale in <double>[0.25, 0.15, 0.08, 0.03]) {
      final times = <int>[];
      for (var frame = 0; frame < 30; frame++) {
        final painter = SketchPainter(
          nodes: nodes,
          sketchOf: (node) => cache.resolve(node, kCard, card),
          origin: Offset(frame.toDouble(), 0),
          scale: scale,
          theme: NodeEditorTheme.dark(),
          revision: 0,
          selectionRevision: 0,
        );
        final recorder = ui.PictureRecorder();
        final watch = Stopwatch()..start();
        painter.paint(Canvas(recorder), const Size(2560, 1348));
        recorder.endRecording().dispose();
        watch.stop();
        times.add(watch.elapsedMicroseconds);
      }
      times.sort();
      debugPrint(
        'paint at ${(scale * 100).round()}%: '
        'p50 ${(times[15] / 1000).toStringAsFixed(2)} ms, '
        'p90 ${(times[27] / 1000).toStringAsFixed(2)} ms',
      );
    }
  });
}
