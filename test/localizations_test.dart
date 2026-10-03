import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_nodes_v2/fl_nodes_v2.dart';

/// Every word bracketed, the way a pseudo-locale marks what went through the
/// localizations — so a label that did not shows up plain.
class _Bracketed extends DefaultNodeEditorLocalizations {
  const _Bracketed();

  @override
  String get cut => '[${super.cut}]';
  @override
  String get copy => '[${super.copy}]';
  @override
  String get paste => '[${super.paste}]';
  @override
  String get delete => '[${super.delete}]';
  @override
  String get deleteWithContents => '[${super.deleteWithContents}]';
  @override
  String get description => '[${super.description}]';
  @override
  String get group => '[${super.group}]';
  @override
  String get addToGroup => '[${super.addToGroup}]';
  @override
  String get disband => '[${super.disband}]';
  @override
  String get rename => '[${super.rename}]';
  @override
  String get colour => '[${super.colour}]';
  @override
  String get neutralColour => '[${super.neutralColour}]';
  @override
  String get goToSource => '[${super.goToSource}]';
  @override
  String get goToDestination => '[${super.goToDestination}]';
  @override
  String get removeWaypoint => '[${super.removeWaypoint}]';
  @override
  String get addWaypointHere => '[${super.addWaypointHere}]';
  @override
  String get clearWaypoints => '[${super.clearWaypoints}]';
  @override
  String get centerView => '[${super.centerView}]';
  @override
  String get resetZoom => '[${super.resetZoom}]';
  @override
  String get create => '[${super.create}]';
  @override
  String get addComment => '[${super.addComment}]';
  @override
  String get project => '[${super.project}]';
  @override
  String get undo => '[${super.undo}]';
  @override
  String get redo => '[${super.redo}]';
  @override
  String get open => '[${super.open}]';
  @override
  String get save => '[${super.save}]';
  @override
  String get newProject => '[${super.newProject}]';
  @override
  String get aboutThisNode => '[${super.aboutThisNode}]';
  @override
  String get close => '[${super.close}]';
  @override
  String get cancel => '[${super.cancel}]';
  @override
  String get groupNameTitle => '[${super.groupNameTitle}]';
  @override
  String get renameConfirm => '[${super.renameConfirm}]';
  @override
  String get linkLabelTitle => '[${super.linkLabelTitle}]';
  @override
  String get linkLabelHint => '[${super.linkLabelHint}]';
  @override
  String get saveConfirm => '[${super.saveConfirm}]';
  @override
  String get discardChangesTitle => '[${super.discardChangesTitle}]';
  @override
  String get discardChangesMessage => '[${super.discardChangesMessage}]';
  @override
  String get discardConfirm => '[${super.discardConfirm}]';
  @override
  String get minimapMinimise => '[${super.minimapMinimise}]';
  @override
  String get minimapRestore => '[${super.minimapRestore}]';
  @override
  String get minimapZoomCap => '[${super.minimapZoomCap}]';
  @override
  String get minimapSize => '[${super.minimapSize}]';
  @override
  String get minimapShow => '[${super.minimapShow}]';
  @override
  String get minimapWhenIdle => '[${super.minimapWhenIdle}]';
  @override
  String get minimapConnections => '[${super.minimapConnections}]';
  @override
  String get minimapGroupFrames => '[${super.minimapGroupFrames}]';
  @override
  String get minimapComments => '[${super.minimapComments}]';
  @override
  String get commentHint => '[${super.commentHint}]';
  @override
  String cutLinks(int count) => '[${super.cutLinks(count)}]';
  @override
  String groupNameHint(String defaultName) =>
      '[${super.groupNameHint(defaultName)}]';
  @override
  String minimapZoomCapLabel(double scale) =>
      '[${super.minimapZoomCapLabel(scale)}]';
  @override
  String minimapIdleOpacityLabel(double opacity) =>
      '[${super.minimapIdleOpacityLabel(opacity)}]';
}

/// English for `en_US`, bracketed for `en_GB` — two locales Material's own
/// English answers for, so switching between them changes nothing but ours.
class _ByCountry extends LocalizationsDelegate<NodeEditorLocalizations> {
  const _ByCountry();
  @override
  bool isSupported(Locale locale) => locale.languageCode == 'en';
  @override
  Future<NodeEditorLocalizations> load(Locale locale) =>
      SynchronousFuture<NodeEditorLocalizations>(
        locale.countryCode == 'GB'
            ? const _Bracketed()
            : const DefaultNodeEditorLocalizations(),
      );
  @override
  bool shouldReload(_ByCountry old) => false;
}

void main() {
  GraphNode node(String id, {String type = 'plain', Offset? at}) => GraphNode(
    id: id,
    type: type,
    position: at ?? Offset.zero,
    width: 160,
    height: 90,
    ports: const <NodePort>[
      NodePort.input(id: 'in'),
      NodePort.output(id: 'out'),
    ],
  );

  NodeEditorController boot() {
    final controller = NodeEditorController(
      graph: NodeGraph(
        nodes: <GraphNode>[
          node('a', type: 'documented'),
          node('b', at: const Offset(400, 0)),
        ],
      ),
      definitions: NodeDefinitionRegistry(<NodeDefinition>[
        NodeDefinition(
          type: 'documented',
          label: 'Documented',
          category: 'Things',
          description: 'What it does.',
        ),
      ]),
    );
    addTearDown(controller.dispose);
    return controller;
  }

  NodeMenuRequest request(
    NodeEditorController controller,
    NodeMenuTarget target, [
    NodeEditorLocalizations? localizations,
  ]) => localizations == null
      ? NodeMenuRequest(
          controller: controller,
          target: target,
          viewportSize: const Size(800, 600),
          describeNode: (_, _) {},
          renameGroup: (_) {},
          newProject: () {},
          openProject: () {},
          saveProject: () {},
        )
      : NodeMenuRequest(
          controller: controller,
          target: target,
          viewportSize: const Size(800, 600),
          describeNode: (_, _) {},
          renameGroup: (_) {},
          newProject: () {},
          openProject: () {},
          saveProject: () {},
          localizations: localizations,
        );

  /// Every default entry of every target, flattened through submenus.
  List<NodeMenuEntry> everyEntry(
    NodeEditorController controller, [
    NodeEditorLocalizations? localizations,
  ]) {
    const menus = NodeEditorMenus();
    final wire = controller.graph.connections.values.single;
    final group = controller.graph.groups.values.single;
    final targets = <NodeMenuTarget>[
      NodeMenuNodeTarget(controller.graph.nodes['a']!, Offset.zero),
      NodeMenuGroupTarget(group, Offset.zero),
      const NodeMenuPortTarget(PortRef('a', 'out'), Offset.zero),
      NodeMenuConnectionTarget(wire, Offset.zero),
      NodeMenuConnectionTarget(wire, Offset.zero, waypoint: 0),
      const NodeMenuCanvasTarget(Offset.zero),
    ];
    List<NodeMenuEntry> flatten(List<NodeMenuEntry> entries) => <NodeMenuEntry>[
      for (final entry in entries)
        if (!entry.isSeparator) ...<NodeMenuEntry>[
          entry,
          ...flatten(entry.children),
        ],
    ];
    return <NodeMenuEntry>[
      for (final target in targets)
        ...flatten(
          menus.defaultsFor(request(controller, target, localizations)),
        ),
    ];
  }

  NodeEditorController everythingOnOffer() {
    final controller = boot();
    final wire = controller.connect(
      const PortRef('a', 'out'),
      const PortRef('b', 'in'),
    )!;
    controller.setConnectionWaypoints(wire, const <Offset>[Offset(200, 50)]);
    controller.selection.selectNode('a');
    controller.groupSelection();
    controller.selection.selectNode('a');
    return controller;
  }

  test(
    'every built-in label comes from the localizations, and keeps its id',
    () {
      final controller = everythingOnOffer();
      final english = everyEntry(controller);
      final bracketed = everyEntry(controller, const _Bracketed());

      expect(
        bracketed.map((e) => e.id),
        english.map((e) => e.id),
        reason: 'a translation must not change which entry is which',
      );
      for (final entry in bracketed) {
        if (entry.id == null || entry.id == NodeMenuEntryId.colourSwatch) {
          continue;
        }
        expect(entry.label, startsWith('['), reason: '${entry.id}');
      }
      // Every id the package has is on offer somewhere above, so a new entry
      // added without a word or an id fails here rather than in a host.
      expect(
        english.map((e) => e.id).whereType<NodeMenuEntryId>().toSet(),
        NodeMenuEntryId.values.toSet(),
      );
    },
  );

  test('the host\'s own words are left alone', () {
    final controller = everythingOnOffer();
    final english = everyEntry(controller);
    final bracketed = everyEntry(controller, const _Bracketed());
    String hosts(List<NodeMenuEntry> entries) => <String>[
      for (final e in entries)
        if (e.id == null || e.id == NodeMenuEntryId.colourSwatch) e.label,
    ].join('|');
    expect(hosts(bracketed), hosts(english));
    expect(hosts(english), contains('Documented'));
    expect(hosts(english), contains('Things'));
  });

  test('a builder finds a default by id, whatever it says', () {
    final controller = everythingOnOffer();
    final menus = NodeEditorMenus(
      build: (request, defaults) => <NodeMenuEntry>[
        for (final e in defaults)
          if (e.id != NodeMenuEntryId.description)
            e.id == NodeMenuEntryId.cut ? e.copyWith(label: 'Snip') : e,
      ],
    );
    final entries = menus.entriesFor(
      request(
        controller,
        NodeMenuNodeTarget(controller.graph.nodes['a']!, Offset.zero),
        const _Bracketed(),
      ),
    );
    expect(entries.first.label, 'Snip');
    expect(entries.first.id, NodeMenuEntryId.cut, reason: 'copyWith keeps it');
    expect(
      entries.map((e) => e.id),
      isNot(contains(NodeMenuEntryId.description)),
    );
  });

  testWidgets('a locale switch reaches the minimap past its slot cache', (
    tester,
  ) async {
    final controller = boot();
    Widget app(Locale locale) => MaterialApp(
      locale: locale,
      supportedLocales: const <Locale>[Locale('en', 'US'), Locale('en', 'GB')],
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        _ByCountry(),
      ],
      home: Scaffold(
        body: NodeEditor(
          controller: controller,
          theme: NodeEditorTheme.dark(),
          minimap: const MinimapConfig(),
          nodeBuilder: (context, graphNode, state) => const SizedBox(),
        ),
      ),
    );

    await tester.pumpWidget(app(const Locale('en', 'US')));
    expect(find.byTooltip('Minimise'), findsOneWidget);

    await tester.pumpWidget(app(const Locale('en', 'GB')));
    await tester.pumpAndSettle();
    expect(
      find.byTooltip('[Minimise]'),
      findsOneWidget,
      reason: 'the panel is handed back from a cache; it must still rebuild',
    );
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    expect(find.text('[Size]'), findsOneWidget);
  });

  testWidgets('a right click on the canvas speaks the delegate in scope', (
    tester,
  ) async {
    final controller = boot();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en', 'GB'),
        supportedLocales: const <Locale>[Locale('en', 'GB')],
        localizationsDelegates: const <LocalizationsDelegate<Object>>[
          _ByCountry(),
        ],
        home: Scaffold(
          body: NodeEditor(
            controller: controller,
            theme: NodeEditorTheme.dark(),
            nodeBuilder: (context, graphNode, state) => const SizedBox(),
          ),
        ),
      ),
    );
    // Well below the two nodes, on empty canvas.
    await tester.tapAt(const Offset(400, 500), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    expect(find.text('[Center view]'), findsOneWidget);
    expect(find.text('Center view'), findsNothing);
  });

  testWidgets('the dialogs say what the delegate says, unless told a title', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en', 'GB'),
        supportedLocales: const <Locale>[Locale('en', 'GB')],
        localizationsDelegates: const <LocalizationsDelegate<Object>>[
          _ByCountry(),
        ],
        home: Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );

    showGroupNameEditor(context, initialValue: 'Gate');
    await tester.pumpAndSettle();
    expect(find.text('[Group name]'), findsOneWidget);
    expect(find.text('[Rename]'), findsOneWidget);
    // The default name is a value in the document, so it is quoted as stored.
    expect(
      tester.widget<TextField>(find.byType(TextField)).decoration!.hintText,
      '[Leave empty for "${NodeGroup.defaultName}"]',
    );
    await tester.tap(find.text('[Cancel]'));
    await tester.pumpAndSettle();

    showConnectionLabelEditor(context, initialValue: null);
    await tester.pumpAndSettle();
    expect(find.text('[Link label]'), findsOneWidget);
    expect(find.text('[Save]'), findsOneWidget);
    await tester.tap(find.text('[Cancel]'));
    await tester.pumpAndSettle();

    showNodeDescription(context, description: 'Prose.', title: 'Mine');
    await tester.pumpAndSettle();
    expect(find.text('Mine'), findsOneWidget, reason: 'a title given wins');
    expect(find.text('[Close]'), findsOneWidget);
  });
}
