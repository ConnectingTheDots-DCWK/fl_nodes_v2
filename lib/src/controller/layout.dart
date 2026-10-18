part of 'node_editor_controller.dart';

/// Where things are: node sizes, the spatial index built from them, and every
/// query that answers "what is at this point".
///
/// The index is kept in step with each mutation rather than rebuilt, so a
/// viewport query costs the area asked for rather than the size of the graph.
/// Hover picking runs on every mouse move and is the reason this exists.
class NodeEditorLayout {
  NodeEditorLayout(this._controller, {required double cellSize})
    : _index = SpatialHashGrid(cellSize: cellSize);

  final NodeEditorController _controller;

  final SpatialHashGrid _index;

  /// Content sizes reported by laid-out node widgets, for auto-height nodes.
  /// Deliberately outside the history: it is a measurement, not a document
  /// edit.
  final Map<String, Size> _measuredSizes = <String, Size>{};

  /// The resolved size of [node]: its declared height, the height measured
  /// from its built content, or a fallback on the very first frame — and no
  /// less than [GraphNode.minHeight] when somebody has dragged the corner.
  ///
  /// This is the **box**: what is hit, selected, framed and drawn on the map.
  /// Ports are placed against [anchorSizeOf] instead, which is the same thing
  /// until a node is stretched.
  Size sizeOf(GraphNode node) {
    final natural = anchorSizeOf(node);
    final floor = node.minHeight;
    if (floor == null || floor <= natural.height) return natural;
    return Size(natural.width, floor);
  }

  /// The size a port's anchor is a fraction of: the declared height, else the
  /// measured one.
  ///
  /// Deliberately not [sizeOf]. Every explicit anchor is a fraction of the
  /// height its definition laid the rows out at, so a card made taller than
  /// that must keep its handles on the rows rather than sliding them down
  /// the empty room below. A measured node's content is already laid out to
  /// its floor — see `NodeView` — so for it the two agree.
  Size anchorSizeOf(GraphNode node) {
    final declared = node.height;
    if (declared != null) return Size(node.width, declared);
    final measured = _measuredSizes[node.id];
    return Size(node.width, measured?.height ?? GraphNode.fallbackHeight);
  }

  /// True while an auto-height node has yet to report a measured size.
  ///
  /// Callers that depend on accurate extents — framing the view, exporting an
  /// image — should wait for this to go false rather than trust the fallback.
  bool get hasUnmeasuredNodes => _controller._graph.nodes.values.any(
    (node) => node.hasIntrinsicHeight && !_measuredSizes.containsKey(node.id),
  );

  /// Told the moment [hasUnmeasuredNodes] stops being true.
  ///
  /// The other half of that sentence. Knowing to wait is no use without being
  /// told the wait is over, and the controller's own notifications cannot say
  /// it: they fire for every edit and every measurement, so a host watching
  /// them has to re-ask on each one and remember the previous answer. This
  /// fires once, on the transition, which is where an automatic layout wants
  /// to run — see [NodeEditorController.applyLayout].
  ///
  /// A graph whose nodes all declare a height never has anything to wait for
  /// and so never fires this at all.
  VoidCallback? onMeasured;

  /// Called by node widgets once their content has been laid out.
  void reportMeasuredSize(String nodeId, Size size) {
    if (_measuredSizes[nodeId] == size) return;
    // Asked before the size is recorded: afterwards this node is measured by
    // definition, and the transition being reported would be invisible.
    final wasWaiting = hasUnmeasuredNodes;
    _measuredSizes[nodeId] = size;
    if (!(_controller._graph.nodes[nodeId]?.hasIntrinsicHeight ?? false)) {
      return;
    }
    _controller._revision++;
    _reindexNodes(<String>[nodeId]);
    _controller._notify();
    // After the notification rather than before it: a host that arranges from
    // here mutates the graph, and doing that midway through announcing a
    // measurement would have listeners reading a graph that is about to move.
    if (wasWaiting && !hasUnmeasuredNodes) onMeasured?.call();
  }

  /// Nodes in paint order: raised ones last so they float above the rest.
  List<GraphNode> get nodesInPaintOrder =>
      _inPaintOrder(_controller._graph.nodes.values.toList(growable: false));

  /// Nodes overlapping [sceneRect], in paint order.
  ///
  /// Backed by the spatial index, so a viewport query costs the area asked for
  /// rather than the size of the graph — and only the survivors get sorted.
  List<GraphNode> nodesIn(Rect sceneRect) => _inPaintOrder(<GraphNode>[
    for (final id in _index.queryRect(sceneRect))
      if (_controller._graph.nodes[id] case final GraphNode node) node,
  ]);

  /// Ids of selectable nodes whose bounds overlap [sceneRect].
  ///
  /// The raw query behind [NodeEditorSelection.selectInRect], for callers that
  /// need to combine the result with a selection of their own — a rubber band
  /// that adds to what was already selected, say.
  Set<String> nodeIdsIn(Rect sceneRect) => <String>{
    for (final id in _index.queryRect(sceneRect))
      if (_controller._graph.nodes[id]?.selectable ?? false) id,
  };

  /// The topmost node containing [scenePoint], matching paint order.
  GraphNode? nodeAt(Offset scenePoint) {
    final raised = _raised;
    final order = _documentOrder;
    GraphNode? best;
    var bestRank = -1;
    for (final id in _index.queryPoint(scenePoint)) {
      final node = _controller._graph.nodes[id];
      if (node == null) continue;
      final rank = _rank(node, raised, order);
      if (rank > bestRank) {
        best = node;
        bestRank = rank;
      }
    }
    return best;
  }

  /// The boxes of the nodes painted over [node] that come within [reach] of
  /// its box — what its port handles have to be clipped out of.
  ///
  /// The ports layer is one painter above every card, so a handle is drawn
  /// over whatever overlaps it unless something says otherwise; this is what
  /// says otherwise. Group frames are not in it: a frame sits beneath its
  /// members and lets presses through. Comments are, being nodes.
  ///
  /// Remembered until the graph or the paint order moves, because the layer
  /// repaints on every pan and the answer does not change with the camera.
  List<Rect> coversOf(GraphNode node, {required double reach}) {
    final raised = _raised;
    if (_coversRevision != _controller._revision ||
        !identical(_coversRaised, raised) ||
        _coversReach != reach) {
      _covers.clear();
      _coversRevision = _controller._revision;
      _coversRaised = raised;
      _coversReach = reach;
    }
    return _covers.putIfAbsent(node.id, () {
      final order = _documentOrder;
      final own = _rank(node, raised, order);
      final covers = <Rect>[];
      for (final id in _index.queryRect(
        node.rect(sizeOf(node)).inflate(reach),
      )) {
        if (id == node.id) continue;
        final other = _controller._graph.nodes[id];
        if (other == null || _rank(other, raised, order) < own) continue;
        if (_index.rectOf(id) case final Rect box) covers.add(box);
      }
      return covers.isEmpty ? const <Rect>[] : covers;
    });
  }

  final Map<String, List<Rect>> _covers = <String, List<Rect>>{};
  int _coversRevision = -1;
  Set<String>? _coversRaised;
  double _coversReach = -1;

  /// Node bounds as the spatial index currently sees them.
  Rect? boundsOf(String nodeId) => _index.rectOf(nodeId);

  /// The frame [group] draws, or null once every member is gone.
  ///
  /// Read off the spatial index, which already holds each node's rect at the
  /// size it was last measured at — so a frame can never disagree with the
  /// nodes it is drawn around.
  Rect? boundsOfGroup(NodeGroup group) =>
      NodeGraph.groupBounds(group, _index.rectOf);

  /// Groups whose frame overlaps [sceneRect], each with its frame.
  ///
  /// Not backed by the spatial index: a group has no entry of its own there,
  /// and there are rarely enough of them for that to matter. A frame can
  /// overlap the viewport while none of its members do — two nodes either side
  /// of the screen — so this is asked independently of the node cull.
  List<(NodeGroup, Rect)> groupsIn(Rect sceneRect) => <(NodeGroup, Rect)>[
    for (final group in _controller._graph.groups.values)
      if (boundsOfGroup(group) case final Rect frame)
        if (frame.overlaps(sceneRect)) (group, frame),
  ];

  /// Reference count held by the spatial index, for diagnostics.
  int get cellReferences => _index.cellReferences;

  /// The port nearest [scenePoint] within [radius], or null.
  ///
  /// Only nodes whose bounds are near the point are considered, so this stays
  /// cheap enough to run on every pointer move during a connection drag.
  PortRef? portAt(Offset scenePoint, {required double radius}) {
    PortRef? best;
    var bestDistance = double.infinity;

    // A handle under the focus scrim is not drawn, and so must not be
    // grabbable either: the package's one rule about invisible handles — see
    // [NodeEditorTheme.portMinScale] — is that a single condition gates
    // drawing *and* hitting, because a dot you cannot see that still starts a
    // wire is worse than one plainly not there yet.
    final lifted = _controller.emphasis.lifted;

    // A handle under a card painted over its own is not grabbable through
    // that card, for the reason it is not drawn there: the press belongs to
    // the card on top. Asked once, of the point itself, so a covered handle
    // nearby cannot shadow a visible one farther off.
    final raised = _raised;
    final order = _documentOrder;
    final top = nodeAt(scenePoint);
    final topRank = top == null ? -1 : _rank(top, raised, order);

    final probe = Rect.fromCircle(center: scenePoint, radius: radius);
    for (final id in _index.queryRect(probe)) {
      if (lifted.isNotEmpty && !lifted.contains(id)) continue;
      final node = _controller._graph.nodes[id];
      if (node == null) continue;
      if (_rank(node, raised, order) < topRank) continue;
      final size = anchorSizeOf(node);
      for (final port in node.ports) {
        final distance =
            (NodeGeometry.portPosition(node, port, size) - scenePoint).distance;
        if (distance <= radius && distance < bestDistance) {
          bestDistance = distance;
          best = PortRef(node.id, port.id);
        }
      }
    }
    return best;
  }

  /// Scene-space centre of a port, or null if the port no longer exists.
  Offset? portPosition(PortRef ref) {
    final node = _controller._graph.nodes[ref.nodeId];
    if (node == null) return null;
    final port = node.portById(ref.portId);
    if (port == null) return null;
    return NodeGeometry.portPosition(node, port, anchorSizeOf(node));
  }

  void _reindexAll() {
    _index.rebuild(<String, Rect>{
      for (final node in _controller._graph.nodes.values)
        node.id: node.rect(sizeOf(node)),
    });
  }

  void _reindexNodes(Iterable<String> ids) {
    for (final id in ids) {
      final node = _controller._graph.nodes[id];
      if (node == null) {
        _index.remove(id);
      } else {
        _index.put(id, node.rect(sizeOf(node)));
      }
    }
  }

  void _forgetMeasurements(Iterable<String> ids) {
    for (final id in ids) {
      _measuredSizes.remove(id);
    }
  }

  List<GraphNode> _inPaintOrder(List<GraphNode> nodes) {
    // Asked once rather than inside the comparator: with a group selected the
    // expansion allocates, and a sort would build it O(n log n) times.
    final raised = _raised;
    final order = _documentOrder;
    nodes.sort((a, b) => _rank(a, raised, order) - _rank(b, raised, order));
    return nodes;
  }

  /// Each node's place in the document, the tie-break between two nodes that
  /// are equally raised: the one added later is drawn, and pressed, on top.
  ///
  /// The rank used to be raised-or-not and nothing else, so the order among
  /// the rest fell to whatever the spatial index returned and an unstable
  /// sort made of it — and [nodeAt] broke the same ties its own way. A card
  /// could be drawn over its neighbour and lose a press to it. Covering a
  /// handle needs the order to be one answer, and so does a click.
  ///
  /// The node map keeps insertion order through every edit (`putNodes`
  /// copies it, and replacing a key keeps its place), so a dragged node keeps
  /// its rank. Cached on the map's identity.
  Map<String, int> get _documentOrder {
    final nodes = _controller._graph.nodes;
    if (!identical(nodes, _orderSource)) {
      _orderSource = nodes;
      var index = 0;
      _order = <String, int>{for (final id in nodes.keys) id: index++};
    }
    return _order;
  }

  Map<String, GraphNode>? _orderSource;
  Map<String, int> _order = const <String, int>{};

  /// The nodes that float above the rest.
  ///
  /// **A focus wins outright.** While [NodeEditorEmphasis] lifts anything, it
  /// alone decides, and the selection is ignored: a selected node floating
  /// above the scrim is precisely the thing the scrim promises will not
  /// happen, and a union of the two would let one stray click undo the whole
  /// effect.
  ///
  /// Otherwise it is what is selected, **plus every member of every selected
  /// group**. Selecting a group still does not select its nodes — this is the
  /// same expansion delete, cut, copy and drag already act through. Paint
  /// order is the one place the distinction would be actively unhelpful: a
  /// frame is picked up by its handle and moved as a unit, and a group that
  /// stayed underneath whatever it was dragged over has to be moved somewhere
  /// else before you can click what it is now covering.
  ///
  /// Costs nothing in either case: both are cached snapshots, and the group
  /// expansion returns [NodeEditorSelection.nodeIds] unchanged when no group
  /// is selected.
  Set<String> get _raised {
    final lifted = _controller.emphasis.lifted;
    if (lifted.isNotEmpty) return lifted;
    return _controller.selection.nodeIdsWithGroups;
  }

  /// Raised nodes above the rest, and document order within each.
  static int _rank(
    GraphNode node,
    Set<String> raised,
    Map<String, int> order,
  ) => (raised.contains(node.id) ? order.length : 0) + (order[node.id] ?? 0);
}
