import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_nodes_v2/fl_nodes_v2.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Stands in for the platform clipboard.
  String? system;

  setUp(() {
    system = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          switch (call.method) {
            case 'Clipboard.setData':
              system =
                  (call.arguments as Map<Object?, Object?>)['text'] as String?;
              return null;
            case 'Clipboard.getData':
              return system == null ? null : <String, Object?>{'text': system};
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  /// The graph's one source, which #28 asked for: selectable and draggable
  /// like any node, never deleted and never copied.
  const source = NodeDefinition(
    type: 'source',
    deletable: false,
    copyable: false,
  );
  const step = NodeDefinition(type: 'step');
  // One of each half, so a test can tell which flag did what.
  const pinned = NodeDefinition(type: 'pinned', deletable: false);
  const single = NodeDefinition(type: 'single', copyable: false);

  GraphNode node(String id, String type, {double x = 0}) => GraphNode(
    id: id,
    type: type,
    position: Offset(x, 0),
    width: 100,
    height: 50,
    ports: const <NodePort>[
      NodePort.input(id: 'in'),
      NodePort.output(id: 'out'),
    ],
  );

  /// `src` wired to `a`, `a` to `b`.
  NodeEditorController board({
    List<NodeGroup> groups = const <NodeGroup>[],
    NodeGraphCodec? codec,
  }) {
    final controller = NodeEditorController(
      graph: NodeGraph(
        nodes: <GraphNode>[
          node('src', 'source'),
          node('a', 'step', x: 200),
          node('b', 'step', x: 400),
          node('pin', 'pinned', x: 600),
          node('one', 'single', x: 800),
        ],
        connections: const <NodeConnection>[
          NodeConnection(
            id: 'src-a',
            from: PortRef('src', 'out'),
            to: PortRef('a', 'in'),
          ),
          NodeConnection(
            id: 'a-b',
            from: PortRef('a', 'out'),
            to: PortRef('b', 'in'),
          ),
        ],
        groups: groups,
      ),
      definitions: NodeDefinitionRegistry(const <NodeDefinition>[
        source,
        step,
        pinned,
        single,
      ]),
      codec: codec,
    );
    addTearDown(controller.dispose);
    return controller;
  }

  Set<String> types(NodeGraph graph) => <String>{
    for (final node in graph.nodes.values) node.type,
  };

  group('delete', () {
    test('leaves a node that may not go and takes the rest, '
        'as one undo step', () {
      final controller = board();
      controller.selection.selectAll();
      controller.selection.deleteSelected();

      expect(
        controller.graph.nodes.keys,
        unorderedEquals(<String>['src', 'pin']),
      );
      expect(controller.selection.isEmpty, isTrue);

      controller.history.undo();
      expect(controller.graph.nodes, hasLength(5));
    });

    test('keeps the frame around a node that stays', () {
      final controller = board(
        groups: const <NodeGroup>[
          NodeGroup(id: 'g', nodeIds: <String>{'src', 'a'}),
        ],
      );
      controller.selection.selectGroup('g');
      controller.selection.deleteSelected();

      expect(controller.graph.nodes.containsKey('a'), isFalse);
      expect(
        controller.graph.groups['g']?.nodeIds,
        <String>{'src'},
        reason:
            'the frame was asked to go with its contents, and not all of '
            'them could',
      );
    });
  });

  group('copy and duplicate', () {
    test('leave out a node that may not be copied, and its wires', () {
      final controller = board();
      controller.selection.selectNodes(<String>['src', 'a', 'b']);

      expect(controller.clipboard.copy(), isTrue);
      final fragment = controller.clipboard.buffer!.graph;
      expect(fragment.nodes.keys, unorderedEquals(<String>['a', 'b']));
      expect(fragment.connections.keys, <String>['a-b']);

      final added = controller.clipboard.duplicate();
      expect(added, hasLength(2));
      expect(
        controller.graph.nodes.values.where((n) => n.type == 'source'),
        hasLength(1),
      );
    });

    test('a copy that takes nothing empties the clipboard rather than '
        'keeping an earlier one', () {
      final controller = board(codec: const NodeGraphCodec());
      controller.selection.selectNode('a');
      controller.clipboard.copy();
      expect(system, isNotEmpty, reason: 'the premise: a copy is mirrored');

      controller.selection.selectNode('src');
      expect(controller.clipboard.copy(), isFalse);
      expect(controller.clipboard.canPaste, isFalse);
      expect(
        system,
        isEmpty,
        reason:
            'Ctrl+V reads the system clipboard first, so emptying only '
            'the buffer would still paste the earlier copy',
      );
    });

    test('a copy with nothing selected still leaves the clipboard alone', () {
      final controller = board();
      controller.selection.selectNode('a');
      controller.clipboard.copy();

      controller.selection.clear();
      expect(controller.clipboard.copy(), isFalse);
      expect(controller.clipboard.canPaste, isTrue);
    });
  });

  group('cut', () {
    test('removes only what it copied and what may be deleted', () {
      final controller = board();
      controller.selection.selectAll();

      expect(controller.clipboard.cut(), isTrue);
      expect(
        controller.graph.nodes.keys,
        unorderedEquals(<String>['src', 'pin', 'one']),
        reason:
            'src and one were never copied, so cutting them would only '
            'delete them; pin was copied but may not be deleted',
      );
      expect(
        controller.clipboard.buffer!.graph.nodes.keys,
        unorderedEquals(<String>['a', 'b', 'pin']),
      );
    });
  });

  test(
    'a paste from another document leaves out what may not be copied',
    () async {
      const codec = NodeGraphCodec();
      final elsewhere = board();
      system = jsonEncode(
        codec.encode(
          GraphDocument(
            graph: NodeGraph(
              nodes: <GraphNode>[
                for (final id in <String>['src', 'a'])
                  elsewhere.graph.nodes[id]!,
              ],
              connections: <NodeConnection>[
                elsewhere.graph.connections['src-a']!,
              ],
              groups: const <NodeGroup>[
                NodeGroup(id: 'g', nodeIds: <String>{'src', 'a'}),
              ],
            ),
            meta: const <String, Object?>{
              NodeEditorClipboard.fragmentKey: true,
            },
          ),
        ),
      );

      final controller = board(codec: codec);
      final before = controller.graph;
      final pasted = await controller.clipboard.pasteFromSystem();

      expect(pasted, hasLength(1));
      expect(controller.graph.nodes[pasted.single]!.type, 'step');
      expect(
        types(controller.graph).length,
        types(before).length,
        reason: 'no second source',
      );
      expect(
        controller.graph.connections.length,
        before.connections.length,
        reason: "the source's wire stays behind with it",
      );
      expect(
        controller.graph.groups,
        isEmpty,
        reason:
            'a frame around the source is not pasted around half its '
            'members',
      );
    },
  );

  group('the menus grey out what would do nothing', () {
    const menus = NodeEditorMenus();

    NodeMenuEntry entry(List<NodeMenuEntry> entries, NodeMenuEntryId id) =>
        entries.firstWhere((entry) => entry.id == id);

    List<NodeMenuEntry> nodeMenu(NodeEditorController controller, String id) =>
        menus.entriesFor(
          NodeMenuRequest(
            controller: controller,
            target: NodeMenuNodeTarget(
              controller.graph.nodes[id]!,
              Offset.zero,
            ),
            viewportSize: const Size(800, 600),
            describeNode: (_, _) {},
            renameGroup: (_) {},
            newProject: () {},
            openProject: () {},
            saveProject: () {},
          ),
        );

    test('on the source', () {
      final controller = board();
      controller.selection.selectNode('src');
      final entries = nodeMenu(controller, 'src');

      for (final id in <NodeMenuEntryId>[
        NodeMenuEntryId.cut,
        NodeMenuEntryId.copy,
        NodeMenuEntryId.delete,
      ]) {
        expect(entry(entries, id).onSelected, isNull, reason: '$id');
      }
    });

    test('and offer them again once the selection holds something they '
        'can take', () {
      final controller = board();
      controller.selection.selectNodes(<String>['src', 'a']);
      final entries = nodeMenu(controller, 'src');

      for (final id in <NodeMenuEntryId>[
        NodeMenuEntryId.cut,
        NodeMenuEntryId.copy,
        NodeMenuEntryId.delete,
      ]) {
        expect(entry(entries, id).onSelected, isNotNull, reason: '$id');
      }
    });
  });
}
