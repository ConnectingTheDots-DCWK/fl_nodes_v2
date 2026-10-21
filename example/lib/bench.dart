import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:fl_nodes_v2/fl_nodes_v2.dart';

import 'bench_tiers.dart';
import 'sample_graph.dart';
import 'workflow_node_card.dart';

/// An on-device frame benchmark, for the half `flutter test` cannot see.
///
/// The widget benchmarks measure the UI thread, and the UI thread turned out
/// to be flat across resolutions — so anything that scales with pixels is on
/// the raster thread, and the only way to see that is to actually rasterise.
/// This runs a scripted drag against a real window and reports what
/// [FrameTiming] says about both threads.
///
/// ```sh
/// flutter run --profile -d linux -t lib/bench.dart
/// flutter run --profile -d linux -t lib/bench.dart --dart-define=SHADOW=off
/// flutter run --profile -d linux -t lib/bench.dart \
///   --dart-define=SCENARIO=zoom --dart-define=NODES=5000
/// ```
///
/// `SCENARIO=zoom` is the measurement level of detail is judged against: it
/// zooms from 100% down to the theme's floor in [kSteps] equal ratios, holds
/// and pans at every level, and comes back up, reporting both threads per
/// level and the nodes drawn there. `BODY=plain` swaps the card for a flat
/// box, which is roughly what an overview tier would draw — the gap between
/// the two is what drawing less per node could save, and what is left in
/// `plain` is the cost of having a widget per node at all.
///
/// | define | default | what it removes |
/// | --- | --- | --- |
/// | `NODES` | 500 | graph size |
/// | `GRID` | on | the background grid, a full-viewport fragment shader |
/// | `SHADOW` | on | the blurred drop shadow on every card |
/// | `FRAMES` | 240 | how long to run (`drag` only) |
/// | `SCENARIO` | drag | `zoom` for the zoom sweep |
/// | `BODY` | card | `plain` for a flat box per node, `replica` for [BenchCard] |
/// | `TEXT`, `BORDER`, `ROUND` | on | `replica`'s text, border and corners |
/// | `OVERLAY` | none | `atlas`, `card` or `blocks`: one painter draws every node |
/// | `CAPTURE` | 0.38 | the zoom `OVERLAY=atlas` snapshots were taken at |
/// | `SKETCH` | off | `on`: `NodeSketches` with [benchSketch], level of detail as shipped |
///
/// `BODY=replica` with one switch off prices that feature of the card. An
/// `OVERLAY` leaves every body empty and draws the nodes from one painter over
/// the editor — what a tier below full detail would draw, see
/// `bench_tiers.dart` — so its raster is that tier's and its build is still
/// the widget per node.
const int kNodes = int.fromEnvironment('NODES', defaultValue: 500);
const int kFrames = int.fromEnvironment('FRAMES', defaultValue: 240);
const String kGrid = String.fromEnvironment('GRID', defaultValue: 'on');
const String kShadow = String.fromEnvironment('SHADOW', defaultValue: 'on');
const String kScenario = String.fromEnvironment(
  'SCENARIO',
  defaultValue: 'drag',
);
const String kBody = String.fromEnvironment('BODY', defaultValue: 'card');
const String kText = String.fromEnvironment('TEXT', defaultValue: 'on');
const String kBorder = String.fromEnvironment('BORDER', defaultValue: 'on');
const String kRound = String.fromEnvironment('ROUND', defaultValue: 'on');
const String kOverlay = String.fromEnvironment('OVERLAY', defaultValue: 'none');
const String kCapture = String.fromEnvironment('CAPTURE', defaultValue: '0.38');
const String kSketch = String.fromEnvironment('SKETCH', defaultValue: 'off');

/// Zoom levels the sweep visits below 100%, and the frames it spends zooming
/// to each and then panning at it.
const int kSteps = 8;
const int kZoomFrames = 30;
const int kHoldFrames = 60;

/// How long to wait before measuring. The runner opens at 1280x720, which is
/// too small for an overview to reach the density a monitor does; give it a
/// few seconds and maximise the window from outside:
/// `wmctrl -r fl_nodes_v2_example -b add,maximized_vert,maximized_horz`.
const int kSettleMs = int.fromEnvironment('SETTLE', defaultValue: 600);

/// `bare` renders a plain box instead of the editor, to price the platform
/// itself; `empty` renders the editor with no nodes in it.
const String kMode = String.fromEnvironment('MODE', defaultValue: 'full');

void main() => runApp(const _BenchApp());

class _BenchApp extends StatelessWidget {
  const _BenchApp();

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(),
    home: const _BenchPage(),
  );
}

class _BenchPage extends StatefulWidget {
  const _BenchPage();

  @override
  State<_BenchPage> createState() => _BenchPageState();
}

class _BenchPageState extends State<_BenchPage>
    with SingleTickerProviderStateMixin {
  late final NodeEditorController _controller;
  final GlobalKey<NodeEditorState> _editorKey = GlobalKey<NodeEditorState>();
  late final Ticker _ticker;

  final List<FrameTiming> _timings = <FrameTiming>[];
  final NodeEditorTheme _theme = NodeEditorTheme.dark().copyWith(
    showGrid: kGrid == 'on',
  );
  int _frame = 0;

  /// The zoom sweep, one entry per frame: what the frame does and which row
  /// of the report it is counted under.
  late final List<(String, VoidCallback)> _sweep = _buildSweep();

  late final Tier? _tier = switch (kOverlay) {
    'atlas' => Tier.atlas,
    'card' => Tier.card,
    'blocks' => Tier.blocks,
    _ => null,
  };
  SnapshotAtlas? _atlas;

  /// Engine frame number -> report row, so timings that arrive in batches
  /// after the fact are still counted under the step that drew them.
  final Map<int, String> _rowOf = <int, String>{};

  /// Nodes drawn at the end of each row, in the order the rows ran.
  final Map<String, int> _drawnAt = <String, int>{};
  int _spin = 0;
  bool _recording = false;

  @override
  void initState() {
    super.initState();
    _controller = NodeEditorController(
      graph: kMode == 'empty'
          ? NodeGraph()
          : buildStressGraph(
              kNodes,
              columns: kScenario == 'zoom' ? math.sqrt(kNodes).ceil() : 24,
            ),
    );
    _ticker = createTicker(_tick);
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (kMode == 'full' && kScenario != 'zoom') {
        _editorKey.currentState?.fitToContent();
      }
      // A few frames of settling before anything is counted, and for the
      // sweep long enough to maximise the window first (see the doc above).
      Future<void>.delayed(Duration(milliseconds: kSettleMs), () {
        if (!mounted) return;
        if (_tier == Tier.atlas) {
          setState(() {
            _atlas = SnapshotAtlas.build(
              count: math.min(kNodes, 3000),
              captureScale: double.parse(kCapture),
              devicePixelRatio: View.of(context).devicePixelRatio,
            );
          });
        }
        // Centred only now, against the window as it ended up.
        if (kMode == 'full' && kScenario == 'zoom') {
          _controller.camera.centerOn(
            _controller.graph.contentBounds(_controller.layout.sizeOf)!.center,
            _editorKey.currentState!.viewportSize,
          );
        }
        _recording = true;
        _ticker.start();
      });
    });
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _ticker.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onTimings(List<FrameTiming> timings) {
    if (_recording) _timings.addAll(timings);
  }

  /// Moves one node every frame: the same work a pointer drag does, without
  /// needing a pointer.
  void _tick(Duration elapsed) {
    if (kScenario == 'zoom' && kMode == 'full') return _tickSweep();
    if (kMode == 'full') {
      _controller.translateNodes(const <String>['n0'], const Offset(2, 1));
    } else {
      // Nothing to drag, so dirty the frame the cheapest way there is.
      setState(() => _spin = (_spin + 1) % 1000);
    }
    if (++_frame >= kFrames) {
      _ticker.stop();
      _report();
    }
  }

  List<(String, VoidCallback)> _buildSweep() {
    final camera = _controller.camera;
    Offset focal() => _editorKey.currentState!.viewportSize.center(Offset.zero);
    final ratio = math.pow(_theme.minScale, 1 / kSteps).toDouble();
    final levels = <double>[
      for (var k = 0; k <= kSteps; k++) math.pow(ratio, k).toDouble(),
    ];
    final frames = <(String, VoidCallback)>[];
    void visit(double from, double to, String direction) {
      final factor = math.pow(to / from, 1 / kZoomFrames).toDouble();
      final level = '${(to * 100).round()}%'.padLeft(4);
      for (var i = 0; i < kZoomFrames; i++) {
        frames.add((
          '$direction $level zooming',
          () => camera.zoomBy(factor, focalScreenPoint: focal()),
        ));
      }
      for (var i = 0; i < kHoldFrames; i++) {
        frames.add((
          '$direction $level panning',
          () => camera.panBy(const Offset(3, 2)),
        ));
      }
    }

    for (var k = 1; k < levels.length; k++) {
      visit(levels[k - 1], levels[k], 'out');
    }
    for (var k = levels.length - 2; k >= 0; k--) {
      visit(levels[k + 1], levels[k], 'in ');
    }
    return frames;
  }

  void _tickSweep() {
    if (_frame >= _sweep.length) return;
    final (row, step) = _sweep[_frame];
    _rowOf[PlatformDispatcher.instance.frameData.frameNumber] = row;
    step();
    final editor = _editorKey.currentState!;
    _drawnAt[row] = _controller.layout
        .nodesIn(
          _controller.camera.viewport.visibleSceneRect(editor.viewportSize),
        )
        .length;
    if (++_frame >= _sweep.length) {
      _ticker.stop();
      // Timings are delivered in batches, so the last frames' arrive late.
      Future<void>.delayed(const Duration(seconds: 2), _reportSweep);
    }
  }

  void _reportSweep() {
    final view = View.of(context);
    final byRow = <String, List<FrameTiming>>{};
    for (final timing in _timings) {
      final row = _rowOf[timing.frameNumber];
      if (row != null) (byRow[row] ??= <FrameTiming>[]).add(timing);
    }
    String cell(List<FrameTiming> timings, Duration Function(FrameTiming) of) {
      final values = timings.map((t) => of(t).inMicroseconds / 1000).toList()
        ..sort();
      if (values.isEmpty) return '      -      -';
      String at(double p) =>
          values[(values.length * p).clamp(0, values.length - 1).floor()]
              .toStringAsFixed(2)
              .padLeft(7);
      return '${at(0.5)}${at(0.9)}';
    }

    final rows = <String>[
      for (final row in _drawnAt.keys)
        '$row${_drawnAt[row].toString().padLeft(7)}'
            '${cell(byRow[row] ?? const <FrameTiming>[], (t) => t.buildDuration)}'
            '${cell(byRow[row] ?? const <FrameTiming>[], (t) => t.rasterDuration)}'
            '${(byRow[row]?.length ?? 0).toString().padLeft(6)}',
    ];
    stdout.writeln(
      '\n=== node editor zoom sweep ===\n'
      'window ${view.physicalSize.width.toInt()}x'
      '${view.physicalSize.height.toInt()} physical, '
      'dpr ${view.devicePixelRatio}\n'
      '$kNodes nodes, body ${_tier == null ? kBody : 'empty'}, '
      'overlay $kOverlay${_tier == Tier.atlas ? ' at $kCapture, '
                '${_atlas?.pages.length} pages' : ''}, grid $kGrid, '
      'shadow $kShadow, text $kText, border $kBorder, round $kRound\n'
      'ms per frame               drawn  build p50/p90  raster p50/p90  frames\n'
      '${rows.join('\n')}',
    );
    exit(0);
  }

  void _report() {
    final view = View.of(context);
    double percentile(List<double> sorted, double p) =>
        sorted[(sorted.length * p).clamp(0, sorted.length - 1).floor()];

    String line(String name, Duration Function(FrameTiming t) pick) {
      final values = _timings.map((t) => pick(t).inMicroseconds / 1000).toList()
        ..sort();
      if (values.isEmpty) return '$name: no frames';
      return '$name  p50 ${percentile(values, 0.5).toStringAsFixed(2)}ms  '
          'p90 ${percentile(values, 0.9).toStringAsFixed(2)}ms  '
          'p99 ${percentile(values, 0.99).toStringAsFixed(2)}ms  '
          'max ${values.last.toStringAsFixed(2)}ms';
    }

    final editor = _editorKey.currentState;
    final drawn = editor == null
        ? 0
        : _controller.layout
              .nodesIn(
                _controller.camera.viewport.visibleSceneRect(
                  editor.viewportSize,
                ),
              )
              .length;

    stdout.writeln(
      '\n=== node editor frame benchmark ===\n'
      'window ${view.physicalSize.width.toInt()}x'
      '${view.physicalSize.height.toInt()} physical, '
      'dpr ${view.devicePixelRatio}\n'
      '$kNodes nodes, $drawn drawn, '
      'zoom ${(_controller.camera.viewport.scale * 100).round()}%, '
      'grid $kGrid, shadow $kShadow, mode $kMode\n'
      '${_timings.length} frames\n'
      '${line('BUILD ', (t) => t.buildDuration)}\n'
      '${line('RASTER', (t) => t.rasterDuration)}\n'
      '${line('TOTAL ', (t) => t.totalSpan)}',
    );
    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    if (kMode == 'bare') {
      return Scaffold(
        body: Center(
          child: Text('$_spin', style: const TextStyle(fontSize: 40)),
        ),
      );
    }
    final editor = NodeEditor(
      key: _editorKey,
      controller: _controller,
      theme: _theme,
      sketches: kSketch == 'on'
          ? const NodeSketches(sketch: benchSketch)
          : null,
      nodeBuilder: (context, node, state) => switch (kBody) {
        _ when _tier != null => const SizedBox.expand(),
        'plain' => const ColoredBox(color: Color(0xFF2A2F3A)),
        'replica' => BenchCard(
          node: node,
          text: kText == 'on',
          border: kBorder == 'on',
          round: kRound == 'on',
          shadow: kShadow == 'on',
        ),
        _ => WorkflowNodeCard(
          node: node,
          state: state,
          isDark: true,
          shadow: kShadow == 'on',
        ),
      },
    );
    final tier = _tier;
    return Scaffold(
      body: tier == null || (tier == Tier.atlas && _atlas == null)
          ? editor
          : Stack(
              fit: StackFit.expand,
              children: <Widget>[
                editor,
                IgnorePointer(
                  child: CustomPaint(
                    painter: TierPainter(
                      controller: _controller,
                      tier: tier,
                      atlas: _atlas,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
