import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../minimap/minimap_config.dart';
import '../model/node_group.dart';

/// The words the editor's own chrome says: its context menus, its dialogs,
/// the minimap's bar and gear, the empty comment.
///
/// The same pattern as Flutter's `MaterialLocalizations`. Nothing has to be
/// set up — with no delegate in scope, [of] answers
/// [DefaultNodeEditorLocalizations], which is the English the package has
/// always shown. A host that translates its interface supplies a delegate for
/// this type in `localizationsDelegates`, beside its own and Material's.
///
/// **Extend [DefaultNodeEditorLocalizations] rather than implementing this
/// class.** A later minor version may add a string; a subclass of the default
/// then shows it in English until it is translated, where an `implements`
/// would stop compiling.
///
/// Only what a host cannot already say is here. A node definition's label,
/// category and description, `MinimapConfig.title` and `sizePresets`, and
/// `EditableLinkLabel.editorTitle` are the host's own strings; and
/// [NodeGroup.defaultName] is not a word at all but a value written into
/// documents, which no locale may change.
abstract class NodeEditorLocalizations {
  const NodeEditorLocalizations();

  /// The localizations in scope, or English when no delegate provides any.
  static NodeEditorLocalizations of(BuildContext context) =>
      Localizations.of<NodeEditorLocalizations>(
        context,
        NodeEditorLocalizations,
      ) ??
      const DefaultNodeEditorLocalizations();

  // ------------------------------------------------------------ menus

  String get cut;
  String get copy;
  String get paste;

  /// Deletes the selection, or a wire.
  String get delete;

  /// A group's menu: deletes the frame and every node in it.
  String get deleteWithContents;

  /// A node's menu: opens the definition's description.
  String get description;

  /// A node's menu: frames the selection in a new group.
  String get group;

  /// A node's menu, when the selection already holds a group: adds the rest
  /// of the selection to it.
  String get addToGroup;

  /// A group's menu: removes the frame and keeps the nodes.
  String get disband;

  /// A group's menu: asks for a new name.
  String get rename;

  /// A group's menu: the colour submenu.
  String get colour;

  /// The first entry of the colour submenu: no colour.
  String get neutralColour;

  /// A port's menu: removes the [count] wires on it. Zero is offered
  /// disabled, so it needs a wording too.
  String cutLinks(int count);

  String get goToSource;
  String get goToDestination;
  String get removeWaypoint;
  String get addWaypointHere;
  String get clearWaypoints;

  /// The canvas menu: fits the whole graph in view.
  String get centerView;

  /// The canvas menu: back to a scale of one.
  String get resetZoom;

  /// The canvas menu: the submenu of node types.
  String get create;

  String get addComment;

  /// The canvas menu: the submenu of undo, redo, open, save and new.
  String get project;

  String get undo;
  String get redo;
  String get open;
  String get save;
  String get newProject;

  // ---------------------------------------------------------- dialogs

  /// The description dialog's title when the caller gives none.
  String get aboutThisNode;

  /// Closes a dialog that asks nothing.
  String get close;

  /// Dismisses a dialog without applying it.
  String get cancel;

  /// The group-name dialog's title when the caller gives none.
  String get groupNameTitle;

  /// The group-name field's hint: what an empty name becomes.
  /// [defaultName] is [NodeGroup.defaultName], which is data and arrives
  /// untranslated.
  String groupNameHint(String defaultName);

  /// Applies the group-name dialog.
  String get renameConfirm;

  /// The link-label dialog's title when the caller gives none.
  String get linkLabelTitle;

  /// The link-label field's hint.
  String get linkLabelHint;

  /// Applies the link-label dialog.
  String get saveConfirm;

  /// The confirmation before New project drops unsaved work.
  String get discardChangesTitle;
  String get discardChangesMessage;
  String get discardConfirm;

  // ---------------------------------------------------------- minimap

  /// The fold button's tooltip, open and folded.
  String get minimapMinimise;
  String get minimapRestore;

  /// The gear's submenus.
  String get minimapZoomCap;
  String get minimapSize;
  String get minimapShow;
  String get minimapWhenIdle;

  /// The Show submenu's three layers.
  String get minimapConnections;
  String get minimapGroupFrames;
  String get minimapComments;

  /// One of [MinimapConfig.zoomCapPresets], as a choice in the gear: a number,
  /// so a host formats it the way its locale writes a percentage.
  String minimapZoomCapLabel(double scale);

  /// One of [MinimapConfig.opacityPresets], as a choice in the gear.
  String minimapIdleOpacityLabel(double opacity);

  // ----------------------------------------------------------- canvas

  /// What an empty comment shows until something is typed.
  String get commentHint;
}

/// The English every host shows until it says otherwise.
class DefaultNodeEditorLocalizations extends NodeEditorLocalizations {
  const DefaultNodeEditorLocalizations();

  /// Answers [DefaultNodeEditorLocalizations] for every locale, like
  /// `DefaultMaterialLocalizations.delegate` — for a host that lists its
  /// delegates explicitly and wants this one's English among them.
  static const LocalizationsDelegate<NodeEditorLocalizations> delegate =
      _DefaultNodeEditorLocalizationsDelegate();

  @override
  String get cut => 'Cut';
  @override
  String get copy => 'Copy';
  @override
  String get paste => 'Paste';
  @override
  String get delete => 'Delete';
  @override
  String get deleteWithContents => 'Delete with contents';
  @override
  String get description => 'Description';
  @override
  String get group => 'Group';
  @override
  String get addToGroup => 'Add to group';
  @override
  String get disband => 'Disband';
  @override
  String get rename => 'Rename';
  @override
  String get colour => 'Colour';
  @override
  String get neutralColour => 'Neutral';
  @override
  String cutLinks(int count) => count == 1 ? 'Cut link' : 'Cut links';
  @override
  String get goToSource => 'Go to source';
  @override
  String get goToDestination => 'Go to destination';
  @override
  String get removeWaypoint => 'Remove waypoint';
  @override
  String get addWaypointHere => 'Add waypoint here';
  @override
  String get clearWaypoints => 'Clear waypoints';
  @override
  String get centerView => 'Center view';
  @override
  String get resetZoom => 'Reset zoom';
  @override
  String get create => 'Create';
  @override
  String get addComment => 'Add comment';
  @override
  String get project => 'Project';
  @override
  String get undo => 'Undo';
  @override
  String get redo => 'Redo';
  @override
  String get open => 'Open';
  @override
  String get save => 'Save';
  @override
  String get newProject => 'New project';

  @override
  String get aboutThisNode => 'About this node';
  @override
  String get close => 'Close';
  @override
  String get cancel => 'Cancel';
  @override
  String get groupNameTitle => 'Group name';
  @override
  String groupNameHint(String defaultName) => 'Leave empty for "$defaultName"';
  @override
  String get renameConfirm => 'Rename';
  @override
  String get linkLabelTitle => 'Link label';
  @override
  String get linkLabelHint => 'Leave empty to remove the caption';
  @override
  String get saveConfirm => 'Save';
  @override
  String get discardChangesTitle => 'Discard unsaved changes?';
  @override
  String get discardChangesMessage =>
      'This document has changes that have not been saved.';
  @override
  String get discardConfirm => 'Discard';

  @override
  String get minimapMinimise => 'Minimise';
  @override
  String get minimapRestore => 'Restore';
  @override
  String get minimapZoomCap => 'Zoom cap';
  @override
  String get minimapSize => 'Size';
  @override
  String get minimapShow => 'Show';
  @override
  String get minimapWhenIdle => 'When idle';
  @override
  String get minimapConnections => 'Connections';
  @override
  String get minimapGroupFrames => 'Group frames';
  @override
  String get minimapComments => 'Comments';

  /// The preset's own label, so the English has one source: the table.
  @override
  String minimapZoomCapLabel(double scale) {
    for (final (label, value) in MinimapConfig.zoomCapPresets) {
      if (value == scale) return label;
    }
    return '${(scale * 100).round()}%';
  }

  @override
  String minimapIdleOpacityLabel(double opacity) {
    for (final (label, value) in MinimapConfig.opacityPresets) {
      if (value == opacity) return label;
    }
    return '${(opacity * 100).round()}%';
  }

  @override
  String get commentHint => 'Comment';
}

class _DefaultNodeEditorLocalizationsDelegate
    extends LocalizationsDelegate<NodeEditorLocalizations> {
  const _DefaultNodeEditorLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<NodeEditorLocalizations> load(Locale locale) =>
      SynchronousFuture<NodeEditorLocalizations>(
        const DefaultNodeEditorLocalizations(),
      );

  @override
  bool shouldReload(_DefaultNodeEditorLocalizationsDelegate old) => false;
}
