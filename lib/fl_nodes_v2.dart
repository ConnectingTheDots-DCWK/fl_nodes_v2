/// A reusable, pannable and zoomable node graph editor.
///
/// The package splits into three layers, and each can be used on its own:
///
/// * **Model** — [NodeGraph], [GraphNode], [NodePort] and [NodeConnection] are
///   immutable value types with no Flutter dependency beyond geometry.
/// * **Controller** — [NodeEditorController] owns the current graph, and
///   reaches the rest through subsystems: [NodeEditorHistory],
///   [NodeEditorSelection], [NodeEditorCamera], [NodeEditorLayout],
///   [NodeEditorClipboard], [NodeEditorProject] and [NodeEditorRunner].
/// * **View** — [NodeEditor] renders the canvas and handles interaction, and
///   delegates the look of each node to a `nodeBuilder` you supply.
library;

export 'src/controller/graph_edit.dart'
    show GraphEdit, GraphEditKind, GraphEditGuard, GraphEditListener;
export 'src/controller/node_editor_controller.dart'
    show
        ConnectionCheck,
        ConnectionValidator,
        GraphDocumentSink,
        GraphDocumentSource,
        GraphFragment,
        GraphLayout,
        AbsentPayload,
        DiagnosticRaised,
        GraphPayload,
        GraphRun,
        GraphRunDiagnostic,
        GraphRunEvent,
        GraphRunException,
        GraphRunIssue,
        GraphRunListener,
        GraphRunRecorder,
        GraphTraceValue,
        LogEmitted,
        MemoHit,
        NodeFinished,
        NodeStarted,
        PresentPayload,
        RunFinished,
        RunStarted,
        WithheldPayload,
        NodeEditorCamera,
        NodeEditorClipboard,
        NodeEditorController,
        NodeEditorEmphasis,
        NodeEditorHistory,
        NodeEditorLayout,
        NodeEditorProject,
        NodeEditorRunner,
        NodeEditorSelection,
        NodeRunState;
export 'src/collections/spatial_hash_grid.dart' show SpatialHashGrid;
export 'src/geometry/connection_path.dart'
    show
        ConnectionPath,
        ConnectionSpan,
        ConnectionStyle,
        CubicSegment,
        PathArrow,
        PolylineSpan,
        RoutePoint;
export 'src/geometry/orthogonal_route.dart' show OrthogonalRoute;
export 'src/geometry/connection_router.dart'
    show ConnectionEndpoints, ConnectionRouter;
export 'src/geometry/grid_snap.dart' show GridSnap;
export 'src/geometry/node_geometry.dart' show NodeGeometry;
export 'src/geometry/viewport_transform.dart' show ViewportTransform;
export 'src/model/graph_emphasis.dart' show GraphEmphasis;
export 'src/model/graph_node.dart' show GraphNode;
export 'src/model/node_comment.dart' show NodeComment;
export 'src/model/node_connection.dart' show NodeConnection, WaypointRef;
export 'src/model/node_group.dart' show NodeGroup;
export 'src/model/node_graph.dart' show NodeGraph;
export 'src/model/node_port.dart'
    show NodePort, PortDirection, PortKind, PortSide;
export 'src/model/payload_equality.dart' show payloadEquals, payloadHash;
export 'src/model/port_ref.dart' show PortRef;
export 'src/definition/link_definition.dart'
    show
        DerivedLinkLabel,
        EditableLinkLabel,
        LinkLabel,
        LinkLabelBuilder,
        LinkDefinition,
        LinkResolutionContext;
export 'src/definition/node_execution.dart'
    show GraphLogEntry, GraphLogLevel, NodeExecutionContext, NodeExecutor;
export 'src/definition/node_definition.dart'
    show
        DynamicFieldFamily,
        DynamicPortFamily,
        FieldFamily,
        NodeField,
        NodeDefinition,
        PortFamily,
        StaticFieldFamily,
        StaticPortFamily;
export 'src/definition/node_definition_registry.dart'
    show
        NodeFieldGroup,
        NodeDefinitionRegistry,
        DefinitionDivergenceHandler,
        DefinitionResolution;
export 'src/definition/node_resolution.dart'
    show
        FieldFamilyBuilder,
        NodeFieldMerge,
        NodeFieldMergeContext,
        NodeFields,
        NodeHeightResolver,
        NodePortRemoval,
        NodeResolutionContext,
        PortFamilyBuilder,
        PortRemoval,
        PortRemovalHandler;
export 'src/definition/port_family_builders.dart' show PortFamilies;
export 'src/menus/node_editor_menu_host.dart' show NodeEditorMenuHost;
export 'src/menus/node_submenu_button.dart' show CascadeSide, NodeSubmenuButton;
export 'src/menus/node_editor_menus.dart'
    show
        NodeEditorMenus,
        NodeMenuBuilder,
        NodeMenuCanvasTarget,
        NodeMenuConnectionTarget,
        NodeMenuGroupTarget,
        NodeMenuNodeTarget,
        NodeMenuPortTarget,
        NodeMenuRequest,
        NodeMenuTarget;
export 'src/l10n/node_editor_localizations.dart'
    show DefaultNodeEditorLocalizations, NodeEditorLocalizations;
export 'src/menus/node_menu_entry.dart' show NodeMenuEntry, NodeMenuEntryId;
export 'src/minimap/minimap_config.dart' show MinimapConfig, MinimapNodeColor;
export 'src/minimap/minimap_controller.dart' show MinimapController;
export 'src/minimap/minimap_painter.dart' show MinimapPainter;
export 'src/minimap/minimap_projection.dart' show MinimapProjection;
export 'src/minimap/minimap_scene.dart' show MinimapScene;
export 'src/painting/connection_label.dart'
    show ConnectionCaption, ConnectionLabel;
export 'src/painting/connection_layout.dart'
    show ConnectionGeometry, ConnectionLayout;
export 'src/painting/connections_painter.dart' show ConnectionsPainter;
export 'src/painting/emphasis_painter.dart' show EmphasisPainter;
export 'src/painting/grid_painter.dart' show GridPainter;
export 'src/painting/port_shape.dart' show PortShape;
export 'src/painting/grid_shader.dart' show GridShader;
export 'src/painting/ports_painter.dart' show PortsPainter;
export 'src/painting/overlay_painter.dart'
    show OverlayPainter, PendingConnection;
export 'src/serialization/document_exceptions.dart'
    show
        GraphDocumentException,
        GraphDocumentFormatException,
        GraphDocumentVersionException,
        UnencodablePayloadException;
export 'src/serialization/document_migrations.dart'
    show GraphDocumentMigration, GraphDocumentMigrations;
export 'src/serialization/graph_document.dart' show GraphDocument;
export 'src/serialization/node_graph_codec.dart'
    show NodeGraphCodec, PortStorage;
export 'src/serialization/payload_codecs.dart'
    show PayloadCodec, PayloadCodecs, PayloadDecoder, PayloadEncoder;
export 'src/theme/node_editor_theme.dart' show NodeEditorTheme;
export 'src/widgets/connection_label_editor.dart'
    show showConnectionLabelEditor;
export 'src/widgets/edge_scroll_config.dart' show EdgeScrollConfig;
export 'src/widgets/node_editor.dart'
    show CanvasDragBehavior, NodeEditor, NodeEditorState;
export 'src/widgets/group_name_editor.dart' show showGroupNameEditor;
export 'src/widgets/node_description_dialog.dart' show showNodeDescription;
export 'src/widgets/node_editor_scope.dart' show NodeEditorScope;
export 'src/widgets/node_view.dart' show NodeRenderState, NodeWidgetBuilder;
