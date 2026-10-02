import 'package:flutter/material.dart';

/// Which built-in entry a [NodeMenuEntry] is.
///
/// A menu builder that keeps, drops or relabels one of the editor's own
/// entries matches on this, never on [NodeMenuEntry.label]: the label is in
/// whatever language the host speaks, and a match on `'Disband'` stops
/// matching the day the host translates it. Entries a host adds carry no id,
/// and neither do the Create submenu's, which are the host's definitions.
enum NodeMenuEntryId {
  cut,
  copy,
  paste,

  /// Deletes the selection — on a node's menu.
  delete,

  /// Deletes one wire — on a wire's menu.
  deleteLink,
  deleteWithContents,
  description,

  /// "Group" or "Add to group", depending on the selection.
  group,
  disband,
  rename,
  colour,
  neutralColour,

  /// One of `NodeGroup.palette`, in the colour submenu.
  colourSwatch,
  cutLinks,
  goToSource,
  goToDestination,
  removeWaypoint,
  addWaypointHere,
  clearWaypoints,
  centerView,
  resetZoom,
  create,
  addComment,
  project,
  undo,
  redo,
  open,
  save,
  newProject,
}

/// One row of a context menu.
///
/// Entries are data rather than widgets so that what a menu offers — and what
/// it offers greyed out — can be asserted without pumping a menu and
/// dismissing it. It also gives a host something to inspect: the build hook
/// receives the defaults and can filter or reorder them instead of having to
/// rebuild the whole menu to change one line.
@immutable
class NodeMenuEntry {
  const NodeMenuEntry({
    required this.label,
    this.icon,
    this.shortcut,
    this.onSelected,
    this.children = const <NodeMenuEntry>[],
    this.id,
  }) : _separator = false;

  /// A rule between two groups of entries.
  ///
  /// Leading, trailing and doubled separators are dropped when the menu is
  /// built, so a hook that removes the last entry of a group does not leave a
  /// rule hanging under nothing.
  const NodeMenuEntry.separator()
    : label = '',
      icon = null,
      shortcut = null,
      onSelected = null,
      children = const <NodeMenuEntry>[],
      id = null,
      _separator = true;

  final String label;
  final IconData? icon;

  /// Rendered as a hint. It does not bind anything — the editor's own
  /// shortcuts already do, and a menu that claimed a key it did not own would
  /// be lying.
  final MenuSerializableShortcut? shortcut;

  /// Null renders the entry disabled, which is the point: an action that does
  /// not apply right now should still say it exists.
  final VoidCallback? onSelected;

  /// Non-empty turns this into a submenu, and [onSelected] is then ignored.
  final List<NodeMenuEntry> children;

  /// Which built-in entry this is, or null for one a host made. Kept by
  /// [copyWith], so a relabelled default is still recognisable.
  final NodeMenuEntryId? id;

  final bool _separator;

  bool get isSeparator => _separator;
  bool get isSubmenu => children.isNotEmpty;

  /// A submenu is enabled when anything inside it is, however deep.
  bool get isEnabled =>
      isSubmenu ? children.any((child) => child.isEnabled) : onSelected != null;

  NodeMenuEntry copyWith({
    String? label,
    IconData? icon,
    MenuSerializableShortcut? shortcut,
    VoidCallback? onSelected,
    List<NodeMenuEntry>? children,
    NodeMenuEntryId? id,
  }) => _separator
      ? this
      : NodeMenuEntry(
          label: label ?? this.label,
          icon: icon ?? this.icon,
          shortcut: shortcut ?? this.shortcut,
          onSelected: onSelected ?? this.onSelected,
          children: children ?? this.children,
          id: id ?? this.id,
        );

  /// Drops separators that would render against nothing.
  ///
  /// Menus are assembled from parts that come and go — a description a
  /// definition may not declare, a project submenu a host may switch off — so
  /// tidying at the end is simpler than every builder having to know what its
  /// neighbours decided.
  static List<NodeMenuEntry> tidy(List<NodeMenuEntry> entries) {
    final out = <NodeMenuEntry>[];
    for (final entry in entries) {
      if (entry.isSeparator && (out.isEmpty || out.last.isSeparator)) continue;
      out.add(entry);
    }
    while (out.isNotEmpty && out.last.isSeparator) {
      out.removeLast();
    }
    return out;
  }

  @override
  String toString() => _separator
      ? 'NodeMenuEntry.separator()'
      : 'NodeMenuEntry($label'
            '${isSubmenu ? ', ${children.length} children' : ''}'
            '${isEnabled ? '' : ', disabled'})';
}
