# Changelog

What a host can do with each version, newest first. The reasoning behind a
change lives beside the code in `CLAUDE.md`; this file only says what changed.

## 1.2.2

A hotfix: a laptop trackpad works in a browser, and the editor's own chrome
survives a large OS text size. No API changes. 1.2.1 was never published; its
fixes are here.

### Fixed

- **On the web, scrolling pans the canvas**: a two-finger swipe, and a mouse
  wheel with it, since a browser gives no reliable way to tell the two apart.
  Hold command or control to zoom with a scroll instead. Native desktop is
  unchanged — the wheel zooms and the trackpad pans.
- **A pinch zooms the canvas on the web**, about the pointer. It did nothing:
  a browser reports a pinch as a control-wheel, which reaches Flutter as a
  scale signal the canvas did not listen for. Control + mouse wheel on the web
  zooms for the same reason.
- The example's page sets `overscroll-behavior: none`, so a sideways swipe
  pans the demo rather than going back a page. A host serving the editor on
  the web wants the same line in its own `index.html`.
- **A group's name is no longer cut off** when the reader's text scale is
  above 1.0. The handle zooms with the canvas, so its name is laid out at the
  handle's own size, the way a node's body is; the colour menu still follows
  the reader.
- **The minimap's bar grows with the reader's text scale**, so its title is
  not cut off either. `MinimapController.barHeight` is still the height at
  1.0, and a folded panel is the taller bar.

### Changed

- **A selection rectangle held against the edge scrolls the canvas**, the way
  a wire, a node or a group already did, and keeps selecting what it reaches.
  Its starting corner stays where it was in the graph. Off with the rest of
  the edge scroll, `edgeScroll: null`.

## 1.2.0

The three words a host could set but not translate now fall back to the
localizations: the minimap's title and Size choices, and the link-label
dialog's heading. Additive: a host that sets none sees the English it saw in
1.1.0, and one that sets its own keeps it in every locale.

### Added

- `NodeEditorLocalizations.minimapTitle` (`'Minimap'`) and
  `minimapSizePresetLabel(size)` (the label from
  `MinimapConfig.defaultSizePresets`), in `DefaultNodeEditorLocalizations`.
- `MinimapConfig.titleIn(words)` and `sizePresetsIn(words)`, what the panel
  draws: the host's own, or the words given.
- `EditableLinkLabel.editorTitleIn(words)`, and `words`
  (`const DefaultNodeEditorLocalizations()`) on
  `NodeDefinitionRegistry.editorTitleFor`.

### Changed

- `MinimapConfig`'s `title` and `sizePresets` and `EditableLinkLabel`'s
  `editorTitle` are now optional with no default value; left out, they are
  said in the localizations in scope. Their getters still answer the host's
  string or the English.
- A `MinimapConfig` given `title: 'Minimap'` or the default presets
  explicitly is no longer `==` to one given nothing, since only the second
  is translated.

## 1.1.0

The editor's own words can be translated, and its menus can be read without
reading English. Additive: a host that changes nothing sees exactly what
1.0.0 showed, and documents are unchanged.

### Added

- `NodeEditorLocalizations`: the words of the built-in menus, the three
  dialogs, the minimap's bar and gear, and an empty comment's hint, in the
  pattern of `MaterialLocalizations`. `NodeEditorLocalizations.of(context)`
  falls back to `DefaultNodeEditorLocalizations` (English), so nothing has to
  be set up. Translate by extending the default and listing a delegate for it
  in `localizationsDelegates`.
- `DefaultNodeEditorLocalizations.delegate`, the English for every locale.
- `NodeMenuRequest.localizations` (`const DefaultNodeEditorLocalizations()`),
  which the editor fills from the context.
- `NodeMenuEntry.id` (null) and `NodeMenuEntryId`, one per built-in entry; a
  `build` hook matches on it rather than on a label, and `copyWith` keeps it.

### Changed

- The `title` of `showNodeDescription`, `showGroupNameEditor` and
  `showConnectionLabelEditor` is now `String?`; null takes the localised
  title. Callers that pass one are unaffected.

## 1.0.0

The API is stable from here. **A document saved by 0.5.0 reads unchanged**:
the envelope is still version 1 and every key is the same, because the names
that changed are Dart's, and the ones that are also the file's — a node's
`type`, a port's `kind` and `dataType` — were kept for exactly that reason.

### Renamed

- **A prototype is a definition.** `NodePrototype` was never a template
  stamped out once; it is a rule a node is resolved against for as long as it
  exists, which its own documentation said. Everything named after it follows.

| 0.5.0 | 1.0.0 |
| --- | --- |
| `NodePrototype` | `NodeDefinition` |
| `LinkPrototype` | `LinkDefinition` |
| `NodePrototypeRegistry` | `NodeDefinitionRegistry` |
| `PrototypeResolution` | `DefinitionResolution` |
| `PrototypeDivergenceHandler` | `DefinitionDivergenceHandler` |
| `registry.linkPrototype(type)` | `registry.linkDefinition(type)` |
| `NodeEditorController(prototypes:)`, `controller.prototypes` | `definitions:`, `controller.definitions` |
| `NodeGraphCodec(prototypes:)`, `ConnectionsPainter.prototypes` | `definitions` |
| `(graph, from, to) => …` as a `ConnectionValidator` | `(check) => check.allowedByDefault && …` |
| `NodeEditorController.defaultConnectionValidator` | `ConnectionCheck.allowedByDefault` |

### Wiring

- **BREAKING: a connection validator is handed the default rather than
  replaced by it.** `ConnectionValidator` takes a `ConnectionCheck` — both
  `PortRef`s, both `NodePort`s, the graph, and `allowedByDefault`, the
  package's own verdict on duplicates, `maxConnections` and `portsCompatible`,
  worked out only if read. Anding it in adds a rule; not reading it replaces
  the checks, which used to happen to every validator whether or not its
  author meant it. *a validator adds to the default checks, or replaces them*
  in `test/controller_test.dart`.
- **`connectionValidator` is a settable field** (`null`), beside `guard` and
  `onEdit`, so a host whose rules change with a mode swaps it.
- **A pasted wire answers to the same rules as a drawn one.** A fragment can
  come from clipboard text, so its wires are judged against the graph after
  resolution and admitted one at a time; a refused one stays behind and its
  nodes still arrive. *a pasted wire is asked what a drawn one is* in
  `test/clipboard_test.dart`.

### Reading a node

- **`GraphNode.field<T>`, `fieldOr<T>` and `metadataValue<T>`** read `data`
  and `metadata` typed: null when a key is absent or holds something else,
  rather than a throw under a host reading a file somebody edited, and an
  `int` accepted as a `double` because `1.0` comes back as `1` from anything
  that is not the Dart VM. The resolution and execution contexts' `field` now
  follow the same rule. *a node reads its stored values typed* in
  `test/model_test.dart`.

### Removed from the barrel

- `arrowheadSize`, `arrowheadsPath`, `minimapShadeBands` and
  `minimapNodeColor`: helpers the package's painters share. The painters,
  `ConnectionLayout`, `ConnectionRouter`, `SpatialHashGrid` and
  `MinimapProjection` stay public — the README's Layers table is a promise
  that each layer is usable on its own.

### Documentation

- The README follows the order a new editor meets things — the model, the
  controller, bodies, ports, node types, wiring — then customisation, and
  keeps dynamic ports, execution and serialisation for an *Advanced* part.


### The canvas

- **A move can land on the grid the canvas draws.**
  `NodeEditorController.snapToGrid` (`bool`, `false`) turns it on, and the
  step is not a number of its own — it is `NodeEditorTheme.gridSpacing`, which
  the editor reports to the controller, so a card lands on a line that is
  drawn. `snapStep` is the resolved scene-space step, `0` when nothing snaps
  or when no editor has mounted yet. A node's top-left corner is what lands,
  each dragged node rounds its own, and it reaches a drag, an arrow-key nudge,
  the corner grip and a dragged waypoint. `GridSnap.axis` and `GridSnap.offset`
  are the rounding, public so a host placing a node itself gets the same
  answer. An arrangement through `applyLayout` is untouched by it.
- **BREAKING: `NodeEditorTheme.snapToGrid` is gone.** It was a second number
  unrelated to the drawn grid. Set `controller.snapToGrid` instead; to keep a
  step that is not the spacing, change `gridSpacing`.
- **BREAKING: `moveNodes`, `translateNodes` and `moveWaypoint` no longer take
  `snap`.** The first two consult `snapToGrid` themselves and take
  `snap: false` to place a node exactly — which is what `Shift` and an arrow
  key now do, since a one-unit nudge rounded to a cell would be a no-op.
  `moveWaypoint` takes its point as given: where a handle belongs depends on
  the connection style, so the editor resolves it.
- **A waypoint lined up with its neighbour stays lined up.** With the grid on,
  an orthogonal handle takes a neighbour's row or column on whichever axes
  claim one and the grid on the rest — a corner with no jog beats a corner on
  a line.
- **A duplicate lands on the grid.** `NodeEditorClipboard.nudge` is one cell on
  each axis while snapping is on and `pasteNudge` (32) otherwise;
  `duplicate({Offset? offset})` takes null for it, where it used to default to
  `pasteNudge`.
- **A wire carried by a drag keeps its route when the grid is on.** Both ends
  moving used to mean both ends moving in the same *frame*, which snapping
  makes almost never true.

### A card can explain itself

- **`NodePort.description` and `NodeField.description`** say what one wire
  carries and what one control on the card does, beside the definition's own
  `description`. A host with a documentation page no longer keeps that prose
  in two places.
  A port's is **outside `==`, `hashCode` and the codec**, on purpose: a port is
  serialised and resolution keeps the node it has when the ports it would build
  compare equal, so comparing prose would rewrite every node in every document
  written before the prose existed. A field's is neither serialised nor
  compared-away, because a field declaration never leaves the definition.
- **`NodeEditor.descriptionBuilder`** renders the "About this node" dialog's
  body. The default is still selectable plain text; a host whose descriptions
  are Markdown passes its own body, with its own styles and link handling. The
  package gains no dependency — what a description is written in is the host's
  decision, not the package's.

## 0.5.0

### Ports

- **A control port and a data port are different shapes.**
  `NodeEditorTheme.controlPortShape` and `dataPortShape` pick from
  `PortShape.circle`, `triangle` and `diamond`, one choice per kind for the
  whole canvas. The default is a triangle for control and a dot for data, so
  a row reads without tracing a wire; set both to `circle` for the old
  appearance.
- **`NodeEditor.portTooltip` labels a handle the pointer rests on.** The
  package asks the host what a port carries, because a `dataType` is a tag
  the host chose and only the host knows what it is called out loud.
  Returning null or an empty string says nothing for that port.

## 0.4.0

### Wires

- **Wires can be routed through waypoints.** Double-click a wire to add a
  handle on the curve, drag the handle to route the wire, double-click it to
  remove it; the wire's context menu offers *Add waypoint here*, *Remove
  waypoint* and *Clear waypoints*. `NodeConnection.waypoints`
  (`List<Offset>`, `const []`), with `setConnectionWaypoints`,
  `insertWaypoint`, `moveWaypoint` and `removeWaypoint` on the controller and
  `GraphEditKind.routeConnection` for `guard` and `onEdit`. A drag that moves
  both ends of a wire carries its route; `applyLayout` clears the routes of
  the wires it moves; a copy pastes with its route. Written to the document
  as an optional `waypoints` key, without a format version bump — an older
  build reads the wire and drops the route on its next save.
  `NodeEditorTheme.waypointRadius` (4.5) and `waypointHitRadius` (9);
  `NodeMenuConnectionTarget` gains `waypoint` and `insertion`.
- **Wires can be drawn in right angles.** `NodeEditorTheme.connectionStyle`
  (`ConnectionStyle`, `curved`) — `orthogonal` draws every wire as
  axis-aligned legs with rounded corners; a waypoint is then a corner, and a
  dragged handle snaps onto the row or column of its neighbours
  (`waypointAlignSnap`, 6 screen px). `connectionStub` (24) is how far a wire
  runs straight out of a port before it may turn, `connectionCornerRadius`
  (8) the arc at each corner. Neither style routes around cards.
  `ConnectionPath.build` takes `style`, `via`, `stub` and `cornerRadius`;
  `ConnectionPath.nearestOnRoute`, `ConnectionSpan`, `CubicSegment`,
  `PolylineSpan`, `RoutePoint` and `OrthogonalRoute` are public.
- **A drag held against the edge of the canvas scrolls it**, for a wire, a
  node, a group or a waypoint handle. `NodeEditor.edgeScroll`
  (`EdgeScrollConfig?`, `const EdgeScrollConfig()`) with `margin` (40) and
  `speed` (600 px/s), both in screen pixels; `null` turns it off.

### Nodes

- **A node body is told which of its ports are wired.**
  `NodeRenderState.connectedPorts` (`Set<String>`, `const {}`) and
  `isWired(portId)`, so a body can show an editor for a value only while no
  wire supplies it. Drawing a wire rebuilds the two bodies it touches and no
  others.
- **Every node carries metadata of its own.** `GraphNode.metadata`
  (`Map<String, Object?>`, `const {}`), beside `data` rather than in it, so a
  prototype's pruning of `data` cannot take a user's notes away.
  `copyWith(metadata:)`, `NodeEditorController.setNodeMetadata(id, map)`
  (reported as `updateNodes`; an equal map is not an edit). Written to the
  document only when non-empty, without a format version bump.

## 0.3.0

The first release since 0.1.0. `0.2.0` was never published; documents stamped
`fl_nodes_v2/0.2.0` were written by an unreleased build in between.

### Watching a run

- `NodeEditorRunner.onEvent` (`GraphRunListener?`, null) is handed a
  `GraphRunEvent` for every step of a run — `RunStarted`, `NodeStarted`,
  `NodeFinished`, `MemoHit`, `DiagnosticRaised`, `LogEmitted`, `RunFinished`
  — a sealed hierarchy, fired synchronously before the notification that
  follows. A listener that throws is reported and the run goes on.
- `NodeEditorRunner.tracePayloads` (`bool`, false) decides whether a
  `GraphTraceValue` carries the value on the wire; off, it is a
  `WithheldPayload` that still names the ports and the `dataType` tag. A wire
  nothing was written on is `AbsentPayload`.
- `NodeExecutionContext.log(message, {level, data})` lands on `GraphRun.log`
  and reaches the listener as `LogEmitted`.
- `GraphRun.id` climbs per run; every event carries it, its `sequence` and
  `at`. `GraphRunRecorder` is a list-backed listener for tests and demos.

### Documents

- `NodeGraphCodec.schemaVersion` (`int?`, null) and `schemaMigrations`
  (`Map<int, GraphDocumentMigration>`, empty) — the host's own version axis
  for what a node's `type` and `data` mean, stamped as `schema` and gated
  the way `version` is. A missing `schema` reads as 1; a null `schemaVersion`
  carries the key through untouched.
- `GraphDocumentMigrations.upgrade` gains `label` and `key`, so a gap in
  either chain names its axis.

### Nodes

- **A node's corner can be dragged** when its prototype says
  `NodePrototype.resizable` (`bool`, false), within `minWidth`, `maxWidth`
  and `maxHeight`. The height set this way is a floor, `GraphNode.minHeight`
  (`double?`, null), written to the document once set; ports stay on their
  rows (`NodeEditorLayout.anchorSizeOf`). One undo step per drag.
- `NodeEditorController.applyLayout(GraphLayout, {recordHistory})` places a
  whole arrangement in one edit, ignoring `draggable`; returns whether
  anything moved. `NodeEditorLayout.onMeasured` (`VoidCallback?`, null)
  fires once when every node has been measured.
- `NodeEditorController.guard` (`GraphEditGuard?`, null) can refuse an edit
  before it lands; `onEdit` (`GraphEditListener?`, null) is told what landed,
  as a `GraphEdit` with a `GraphEditKind` and the ids it touched. Undo and
  redo pass through neither.
- `NodeEditorController.emphasis` — a focus: a `GraphEmphasis` of nodes and
  connections that stand clear of a scrim washed over everything else,
  outside the document and the undo history. `NodeEditorTheme.scrimColor`
  (null, derived from `background`), `scrimOpacity` (0.62), `emphasisInset`
  (7), `emphasisRadius` (`Radius.circular(14)`).
- `ConnectionLabel.maxWidth` (160) is public, so a layout can leave room for
  a caption.

### Menus

- Submenus are `NodeSubmenuButton`: a cascade opens to the right of its row,
  slides up only as far as the window demands, and never flips above the
  row it opened from. The whole tree opens one way, `CascadeSide`, chosen
  from its widest chain.
- With `createOnDrop` on, the wire stays drawn while the Create menu is up
  and goes when the menu closes.
- The minimap's gear and fold buttons sit against the panel's edge.

## 0.1.0

First release: a node graph editor for Flutter, the successor to
[fl_nodes](https://github.com/WilliamKarolDiCioccio/fl_nodes), rebuilt so
that a node body is an ordinary widget — text fields, sliders and forms all
work inside one.

- Immutable `NodeGraph` of `GraphNode`s, `NodePort`s and `NodeConnection`s,
  edited through a `NodeEditorController` with `history`, `selection`,
  `camera`, `layout`, `clipboard`, `project` and `runner` subsystems.
- Ports declare a `PortKind` (`data` or `control`) and an optional
  `dataType`; the default validator refuses to wire across either.
- Prototypes as reduction rules: given a node's fields and wiring, they
  return the ports, fields and height it should have. Static and dynamic
  port families; foreign ports left alone.
- Execution: `controller.runner.run()` walks control flow depth-first and
  pulls data inputs on demand, memoised per run; `NodeExecutionContext.enteredVia`
  names the control input the flow arrived on; a `GraphRun` carries the
  trace, values, diagnostics and failure.
- Pan, zoom, marquee select, node drag, port-to-port wiring, connection
  captions, keyboard shortcuts and undo. Context menus on node, port, wire
  and canvas, built from `MenuAnchor` with entries as data and a build hook.
  Optional drop-to-create.
- Comments: free-standing notes sharing the nodes' paint order, typed edits
  folding into one undo step per run.
- Groups: named frames behind a set of nodes (`Ctrl+G`), moved by their
  handle, floating to the front with their members when selected.
- Minimap: `NodeEditor.minimap` (`MinimapConfig?`, null) draws a movable,
  foldable readout over the canvas; `MinimapController` holds its size,
  `maxScale` (0.2) and `idleOpacity` (0.28) for a host to persist.
- Rendering: connections, ports, grid and overlays painted rather than
  built; per-node widget slots, an incremental connection layout, a spatial
  hash for hit testing and culling, a fragment-shader grid with a CPU
  fallback.
- `NodeGraphCodec` reads and writes a versioned JSON document with
  pluggable payload codecs and map-to-map migrations; a `project` subsystem
  keeps I/O behind a host-supplied source and sink.
