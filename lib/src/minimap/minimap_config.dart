import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../l10n/node_editor_localizations.dart';
import '../model/graph_node.dart';

/// The colour a node is drawn in on the map, or null to take the default.
///
/// Re-asked whenever the graph or the selection moves, and at no other time: a
/// callback that reads state outside the document will not repaint on its own.
///
/// Selection wins over it. A selected node the host had coloured by type would
/// otherwise be indistinguishable from an unselected one of the same type, on
/// the one panel whose whole job is telling you where you are.
typedef MinimapNodeColor = Color? Function(GraphNode node);

/// What the *host* decides about the minimap.
///
/// Everything the app user can change through the panel's own gear lives on
/// `MinimapController` instead, with its default there and nowhere else. Two
/// homes for one default is how a setting a host has persisted gets silently
/// overwritten by a config seed on the next launch.
///
/// [title] and [sizePresets] are words. Left out, the panel says them in the
/// `NodeEditorLocalizations` in scope; given, they are the host's and no
/// locale replaces them.
@immutable
class MinimapConfig {
  const MinimapConfig({
    this.alignment = Alignment.bottomRight,
    this.margin = const EdgeInsets.all(16),
    this.minSize = const Size(120, 90),
    this.maxSize = const Size(480, 360),
    List<(String, Size)>? sizePresets,
    String? title,
    this.nodeColor,
  }) : _sizePresets = sizePresets,
       _title = title;

  /// What the gear offers under Size when the host sets no [sizePresets],
  /// labelled in English. The panel shows each through
  /// `NodeEditorLocalizations.minimapSizePresetLabel`, keyed on the size.
  /// The corner grip is the direct route; these write the same field.
  static const List<(String, Size)> defaultSizePresets = <(String, Size)>[
    ('Small', Size(160, 110)),
    ('Medium', Size(240, 160)),
    ('Large', Size(360, 240)),
  ];

  /// The gear's zoom-cap choices, as (label, scale). A cap of 1 is "none" in
  /// practice: the map never zooms past life size. The labels are the
  /// English and the key `minimapZoomCapLabel` reads it by, not words a host
  /// sets: the gear shows each through the localizations.
  static const List<(String, double)> zoomCapPresets = <(String, double)>[
    ('5%', 0.05),
    ('10%', 0.1),
    ('20%', 0.2),
    ('40%', 0.4),
    ('100%', 1.0),
  ];

  /// The gear's idle-opacity choices, labelled the same way as
  /// [zoomCapPresets], through `minimapIdleOpacityLabel`.
  static const List<(String, double)> opacityPresets = <(String, double)>[
    ('Solid', 1.0),
    ('Dim', 0.6),
    ('Faint', 0.28),
  ];

  /// Where the panel sits before anyone has moved it.
  final Alignment alignment;

  /// Distance from the canvas edge at [alignment].
  final EdgeInsets margin;

  final Size minSize;
  final Size maxSize;

  final List<(String, Size)>? _sizePresets;
  final String? _title;

  /// What the gear offers under Size: the host's, or [defaultSizePresets] in
  /// English. What the gear shows is [sizePresetsIn] the localizations in
  /// scope.
  List<(String, Size)> get sizePresets => _sizePresets ?? defaultSizePresets;

  /// The word on the action bar: the host's, or the English. What the bar
  /// shows is [titleIn] the localizations in scope.
  String get title => titleIn(const DefaultNodeEditorLocalizations());

  /// The bar's word in [words], unless the host gave its own.
  String titleIn(NodeEditorLocalizations words) => _title ?? words.minimapTitle;

  /// The Size choices in [words], unless the host gave its own.
  List<(String, Size)> sizePresetsIn(NodeEditorLocalizations words) =>
      _sizePresets ??
      <(String, Size)>[
        for (final (_, size) in defaultSizePresets)
          (words.minimapSizePresetLabel(size), size),
      ];

  final MinimapNodeColor? nodeColor;

  MinimapConfig copyWith({
    Alignment? alignment,
    EdgeInsets? margin,
    Size? minSize,
    Size? maxSize,
    List<(String, Size)>? sizePresets,
    String? title,
    MinimapNodeColor? nodeColor,
  }) => MinimapConfig(
    alignment: alignment ?? this.alignment,
    margin: margin ?? this.margin,
    minSize: minSize ?? this.minSize,
    maxSize: maxSize ?? this.maxSize,
    sizePresets: sizePresets ?? _sizePresets,
    title: title ?? _title,
    nodeColor: nodeColor ?? this.nodeColor,
  );

  /// Value equality, so the editor can cache the panel widget against it and
  /// hand back the identical instance on a camera tick.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MinimapConfig &&
          other.alignment == alignment &&
          other.margin == margin &&
          other.minSize == minSize &&
          other.maxSize == maxSize &&
          listEquals(other._sizePresets, _sizePresets) &&
          other._title == _title &&
          other.nodeColor == nodeColor;

  @override
  int get hashCode => Object.hash(
    alignment,
    margin,
    minSize,
    maxSize,
    _sizePresets == null ? null : Object.hashAll(_sizePresets),
    _title,
    nodeColor,
  );
}
