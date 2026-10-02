import 'dart:collection';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../model/graph_node.dart';
import '../model/node_connection.dart';
import '../model/node_graph.dart';
import '../model/node_port.dart';
import '../model/port_ref.dart';
import 'link_definition.dart';
import 'node_definition.dart';
import 'node_resolution.dart';

/// Reports a node whose definition never settled.
typedef DefinitionDivergenceHandler = void Function(GraphNode node, int passes);

/// What came of a resolution.
@immutable
class DefinitionResolution {
  const DefinitionResolution({
    required this.graph,
    required this.changed,
    required this.pruned,
    required this.diverged,
  });

  /// The normalised graph.
  final NodeGraph graph;

  /// Nodes actually rewritten, so the spatial index can be patched rather than
  /// rebuilt.
  final Set<String> changed;

  /// Connections removed because the port they landed on disappeared.
  final Set<String> pruned;

  /// Nodes that hit their pass or step budget and were left as they were.
  final Set<String> diverged;

  bool get isUnchanged => changed.isEmpty && pruned.isEmpty;

  @override
  String toString() =>
      'DefinitionResolution(${changed.length} changed, ${pruned.length} pruned, '
      '${diverged.length} diverged)';
}

/// One field family's declared keys, as a document records them.
@immutable
class NodeFieldGroup {
  const NodeFieldGroup({
    required this.family,
    required this.keys,
    this.keyPrefix,
  });

  final String family;

  /// The keys this family declares right now, in builder order.
  final List<String> keys;

  /// The namespace a dynamic family manages, or null for a static one.
  final String? keyPrefix;

  @override
  String toString() => 'NodeFieldGroup($family, ${keys.length} keys)';
}

/// The definitions a document is normalised against.
///
/// Resolution is a pure function over a [NodeGraph] and lives here rather than
/// on the controller, so graph logic stays testable without pumping a widget.
/// The controller only decides *when* to call it.
class NodeDefinitionRegistry {
  NodeDefinitionRegistry(
    Iterable<NodeDefinition> definitions, {
    Iterable<LinkDefinition> links = const <LinkDefinition>[],
    this.onDiverged,
    this.maxSteps = 64,
  }) : _byType = <String, NodeDefinition>{
         for (final definition in definitions) definition.type: definition,
       },
       _linksByType = <String, LinkDefinition>{
         for (final link in links) link.type: link,
       };

  /// A registry that normalises nothing.
  static final NodeDefinitionRegistry empty = NodeDefinitionRegistry(
    const <NodeDefinition>[],
  );

  final Map<String, NodeDefinition> _byType;
  final Map<String, LinkDefinition> _linksByType;

  /// Called for a node that never settled.
  ///
  /// Defaults to a console error in debug builds. A divergent builder is a bug
  /// in the host, not in the document, and throwing would take the app down
  /// mid hot-reload — which is exactly when a half-written builder is normal.
  final DefinitionDivergenceHandler? onDiverged;

  /// Cascade steps allowed on top of the seeds, per [resolve] call.
  final int maxSteps;

  /// Whether there is anything to normalise.
  ///
  /// Link definitions do not take part in resolution — they describe what the
  /// app user may do with a connection, not what shape it takes — so they do
  /// not count here.
  bool get isEmpty => _byType.isEmpty;
  bool get isNotEmpty => _byType.isNotEmpty;

  Iterable<String> get types => _byType.keys;

  NodeDefinition? operator [](String type) => _byType[type];

  /// The definition for connections of [type], if one is registered.
  LinkDefinition? linkDefinition(String type) => _linksByType[type];

  /// Whether the app user may retitle [connection] by tapping its caption.
  ///
  /// Never true for a derived caption: the two are exclusive by construction.
  bool allowsLabelEditing(NodeConnection connection) =>
      _linksByType[connection.type]?.editableLabel ?? false;

  /// The caption [connection] should show, or null when it shows none.
  ///
  /// A derived caption is computed here rather than stored, so it follows
  /// whatever it was derived from and the document never carries it. An
  /// editable one is read straight off the connection, because there it is the
  /// app user's to keep.
  String? captionOf(NodeGraph graph, NodeConnection connection) {
    if (_linksByType.isEmpty) return connection.label;
    return switch (_linksByType[connection.type]?.label) {
      DerivedLinkLabel(:final build) => build(
        LinkResolutionContext(graph: graph, connection: connection),
      ),
      EditableLinkLabel() || null => connection.label,
    };
  }

  /// Heading for the editor opened by tapping [connection]'s caption.
  String editorTitleFor(NodeConnection connection) {
    final label = _linksByType[connection.type]?.label;
    return label is EditableLinkLabel ? label.editorTitle : 'Link label';
  }

  /// Whether [node] is normalised by a definition at all.
  bool handles(GraphNode node) => _byType.containsKey(node.type);

  /// The fields [node] declares right now.
  ///
  /// This is what a node body builds its editors from: the declarations follow
  /// the node's current values, so a body rendering these rows grows and
  /// shrinks with them instead of hard-coding a list.
  List<NodeField> fieldsOf(NodeGraph graph, GraphNode node) {
    final definition = _byType[node.type];
    if (definition == null) return const <NodeField>[];
    return _declare(_contextFor(graph, node, 0), definition).fields;
  }

  /// The field families [node] declares right now, in declaration order.
  ///
  /// [fieldsOf] flattens the same information. This keeps the family each key
  /// belongs to, which is what a document records so a reader can tell a value
  /// the definition manages from one the host put there itself.
  List<NodeFieldGroup> fieldGroupsOf(NodeGraph graph, GraphNode node) {
    final definition = _byType[node.type];
    if (definition == null || definition.fields.isEmpty) {
      return const <NodeFieldGroup>[];
    }

    final context = _contextFor(graph, node, 0);
    final groups = <NodeFieldGroup>[];
    for (final family in definition.fields) {
      final fields = switch (family) {
        StaticFieldFamily(fields: final declared) => declared,
        DynamicFieldFamily(:final build) => build(context.forFamily(family.id)),
      };
      if (fields.isEmpty) continue;
      groups.add(
        NodeFieldGroup(
          family: family.id,
          keys: <String>[for (final field in fields) field.key],
          keyPrefix: family is DynamicFieldFamily ? family.keyPrefix : null,
        ),
      );
    }
    return groups;
  }

  /// A node of [type] with ports and default field values already materialised.
  ///
  /// Handy for palettes and tests. Adding a node to a controller resolves it
  /// anyway, so this is not required to create one.
  GraphNode instantiate(
    String type, {
    required String id,
    required Offset position,
    double? width,
    Map<String, Object?> data = const <String, Object?>{},
  }) {
    final definition = _byType[type];
    final seed = GraphNode(
      id: id,
      type: type,
      position: position,
      width: width ?? definition?.defaultWidth ?? GraphNode.defaultWidth,
      data: data,
    );
    if (definition == null) return seed;
    return _settle(NodeGraph(nodes: <GraphNode>[seed]), seed, definition).node;
  }

  /// Normalises every node in [graph].
  DefinitionResolution resolveAll(NodeGraph graph) =>
      resolve(graph, seeds: graph.nodes.keys.toList(growable: false));

  /// Normalises [seeds] and anything a cascade reaches.
  ///
  /// Removing a port prunes the connections that landed on it, and that prune
  /// changes the *other* endpoint's link state — which is an input to its own
  /// resolution. So this is a worklist over the graph, not a rewrite of one
  /// node in isolation.
  DefinitionResolution resolve(
    NodeGraph graph, {
    required Iterable<String> seeds,
  }) {
    final changed = <String>{};
    final pruned = <String>{};
    final diverged = <String>{};
    if (_byType.isEmpty) {
      return DefinitionResolution(
        graph: graph,
        changed: changed,
        pruned: pruned,
        diverged: diverged,
      );
    }

    final queue = Queue<String>.of(seeds);
    final queued = Set<String>.of(queue);
    void enqueue(String id) {
      if (queued.add(id)) queue.add(id);
    }

    // Seeds are known work; the budget bounds the cascade on top of them.
    var budget = queue.length + maxSteps;
    var out = graph;

    while (queue.isNotEmpty) {
      if (budget-- <= 0) {
        diverged.addAll(queue);
        break;
      }
      final id = queue.removeFirst();
      queued.remove(id);

      final node = out.node(id);
      if (node == null) continue;
      final definition = _byType[node.type];
      if (definition == null) continue;

      final settled = _settle(out, node, definition);
      if (settled.diverged) {
        diverged.add(id);
        _reportDivergence(node, definition);
      }

      final before = out;
      var handled = false;

      if (settled.node != node) {
        changed.add(id);
        out = out.putNode(settled.node);

        final gone = <NodePort>[
          for (final port in node.ports)
            if (settled.node.portById(port.id) == null) port,
        ];
        if (gone.isNotEmpty) {
          final affected = <NodeConnection>[
            for (final connection in out.connectionsOf(id))
              if (gone.any(
                (port) => connection.touchesPort(PortRef(id, port.id)),
              ))
                connection,
          ];
          if (affected.isNotEmpty) {
            handled = true;
            out = definition.onPortsRemoved(
              PortRemoval(
                graph: out,
                node: settled.node,
                removed: gone,
                affected: affected,
              ),
            );
          }
        }
      }

      // Swept for every node that settled, not only for one that lost a port.
      // A document can arrive referencing a port its definition never creates —
      // a saved wire on an exit that was not stored, say — and a connection
      // pointing at a port that is not there draws nothing while staying in the
      // model. An invisible edge that survives undo and gets written out again
      // is worse than an honest deletion.
      out = _dropDangling(out, id);

      // A removal handler may rewrite connections anywhere, so check the whole
      // graph when one ran; otherwise only this node's own edges can have gone,
      // and that lookup is indexed.
      final removed = <NodeConnection>[
        for (final connection
            in handled ? before.connections.values : before.connectionsOf(id))
          if (!out.connections.containsKey(connection.id)) connection,
      ];
      if (removed.isEmpty) continue;

      pruned.addAll(removed.map((connection) => connection.id));

      // Both ends of anything that actually went away may now resolve
      // differently, this node included.
      for (final connection in removed) {
        enqueue(connection.from.nodeId);
        enqueue(connection.to.nodeId);
      }
      enqueue(id);
    }

    return DefinitionResolution(
      graph: out,
      changed: changed,
      pruned: pruned,
      diverged: diverged,
    );
  }

  // --- node-local resolution ------------------------------------------------

  /// Runs passes until the node stops changing.
  _Settled _settle(NodeGraph graph, GraphNode node, NodeDefinition definition) {
    var current = node;
    var next = _pass(graph, current, definition, 0);
    var pass = 1;
    while (next != current && pass < definition.maxPasses) {
      current = next;
      next = _pass(graph, current, definition, pass);
      pass++;
    }
    return _Settled(next, next != current);
  }

  /// One derivation: fields, then the merge, then ports, then height.
  ///
  /// Fields merge *before* ports build so a default seeded this pass is already
  /// visible to the port builders — otherwise every new field would cost an
  /// extra pass.
  GraphNode _pass(
    NodeGraph graph,
    GraphNode node,
    NodeDefinition definition,
    int pass,
  ) {
    final context = _contextFor(graph, node, pass);
    final declared = _declare(context, definition);

    final data = definition.inheritFields(
      NodeFieldMergeContext(
        node: node,
        declared: declared.fields,
        managedPrefixes: declared.prefixes,
        pass: pass,
      ),
    );
    final seeded = mapEquals(data, node.data)
        ? node
        : node.copyWith(data: data);
    final seededContext = context.forNode(seeded);

    final ports = <NodePort>[];
    final generated = <String>{};
    for (final family in definition.ports) {
      final built = switch (family) {
        StaticPortFamily(ports: final declaredPorts) => declaredPorts,
        DynamicPortFamily(build: final build) => build(
          seededContext.forFamily(family.id),
        ),
      };
      for (final port in built) {
        assert(
          port.family == null || port.family == family.id,
          'port "${port.id}" is stamped "${port.family}" but was returned by '
          'family "${family.id}" — almost always a copy-paste slip',
        );
        assert(
          !generated.contains(port.id),
          'definition "${definition.type}" produced two ports with id '
          '"${port.id}" on node "${node.id}"',
        );
        generated.add(port.id);
        ports.add(
          port.family == family.id ? port : port.copyWith(family: family.id),
        );
      }
    }

    // Ports no family owns keep their place after the generated ones — unless
    // the definition declares the same id, in which case the generated port
    // adopts it. That is what lets a definition be pointed at a document whose
    // ports were authored by hand: it takes them over rather than doubling
    // them up, which would break every lookup that goes through portById.
    for (final port in seededContext.foreignPorts) {
      if (generated.contains(port.id)) continue;
      ports.add(port);
    }

    var next = listEquals(ports, seeded.ports)
        ? seeded
        : seeded.copyWith(ports: ports);

    final resolveHeight = definition.resolveHeight;
    if (resolveHeight != null) {
      final height = resolveHeight(seededContext.forNode(next).forFamily(null));
      if (height != next.height) next = next.withHeight(height);
    }
    return next;
  }

  _Declared _declare(NodeResolutionContext context, NodeDefinition definition) {
    if (definition.fields.isEmpty) return const _Declared._empty();
    final fields = <NodeField>[];
    final prefixes = <String>{};
    for (final family in definition.fields) {
      switch (family) {
        case StaticFieldFamily(fields: final declared):
          fields.addAll(declared);
        case DynamicFieldFamily(:final keyPrefix, :final build):
          prefixes.add(keyPrefix);
          fields.addAll(build(context.forFamily(family.id)));
      }
    }
    return _Declared(fields, prefixes);
  }

  NodeResolutionContext _contextFor(NodeGraph graph, GraphNode node, int pass) {
    final counts = <String, int>{};
    for (final connection in graph.connectionsOf(node.id)) {
      if (connection.from.nodeId == node.id) {
        counts.update(
          connection.from.portId,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }
      if (connection.to.nodeId == node.id) {
        counts.update(
          connection.to.portId,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }
    }
    return NodeResolutionContext(
      graph: graph,
      node: node,
      pass: pass,
      connectionCounts: counts,
    );
  }

  /// Removes connections on [nodeId] whose port is no longer there.
  NodeGraph _dropDangling(NodeGraph graph, String nodeId) {
    final node = graph.node(nodeId);
    if (node == null) return graph;
    final doomed = <String>[
      for (final connection in graph.connectionsOf(nodeId))
        if ((connection.from.nodeId == nodeId &&
                node.portById(connection.from.portId) == null) ||
            (connection.to.nodeId == nodeId &&
                node.portById(connection.to.portId) == null))
          connection.id,
    ];
    return doomed.isEmpty ? graph : graph.removeConnections(doomed);
  }

  void _reportDivergence(GraphNode node, NodeDefinition definition) {
    final handler = onDiverged;
    if (handler != null) {
      handler(node, definition.maxPasses);
      return;
    }
    assert(() {
      FlutterError.presentError(
        FlutterErrorDetails(
          exception: StateError(
            'Node "${node.id}" of type "${node.type}" did not settle in '
            '${definition.maxPasses} passes, so its shape may be stale.\n'
            'A family builder has to return an equal result when called twice '
            'on the same state. The usual causes are generating port ids from '
            'a counter instead of from the state, and putting a freshly '
            'allocated object in NodePort.data or NodeField.defaultValue — '
            'both read as a change on every pass.',
          ),
          library: 'fl_nodes_v2',
          context: ErrorDescription('resolving a node against its definition'),
        ),
      );
      return true;
    }());
  }
}

@immutable
class _Settled {
  const _Settled(this.node, this.diverged);
  final GraphNode node;
  final bool diverged;
}

@immutable
class _Declared {
  const _Declared(this.fields, this.prefixes);
  const _Declared._empty()
    : fields = const <NodeField>[],
      prefixes = const <String>{};

  final List<NodeField> fields;
  final Set<String> prefixes;
}
