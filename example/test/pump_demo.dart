import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_nodes_v2_example/main.dart';

/// The demo in a window the size of a desktop one.
///
/// The test default is 800x600, and the demo fits its board to what is left
/// beside the inspector — under a quarter of full size, where the editor
/// draws sketches instead of building cards. These tests are about the cards'
/// own widgets, so they need the zoom a desktop window opens at.
Future<void> pumpDemo(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(1600, 1000)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const NodeEditorDemoApp());
}
