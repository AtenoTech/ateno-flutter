import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ateno_flutter/ateno_flutter.dart';

void main() {
  testWidgets('PlyViewer instantiates correctly', (WidgetTester tester) async {
    // Build the widget within a standard Material app envelope
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PlyViewer(
            filePath: 'test_model.glb',
            backgroundColor: Colors.white,
          ),
        ),
      ),
    );

    // Verify that the PlyViewer widget successfully mounts in the tree
    expect(find.byType(PlyViewer), findsOneWidget);
  });
}
