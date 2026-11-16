import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/bound_materials_flow.dart';

const _captureDirectory = String.fromEnvironment('C_MATERIALS_CAPTURE_DIR');

void main() {
  testWidgets(
    'captures synthetic bound course and private material navigation',
    (tester) async {
      await (FontLoader('HarmonyOS Sans SC')..addFont(
            rootBundle.load('assets/fonts/HarmonyOS_Sans_SC_Regular.ttf'),
          ))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      await tester.binding.setSurfaceSize(const ui.Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await exerciseBoundMaterialsFlow(
        tester,
        fromTeaching: true,
        onCapture: (name) async {
          final view = tester.binding.renderViews.single;
          final boundary = view.debugLayer! as OffsetLayer;
          final image = await tester.runAsync(
            () => boundary.toImage(
              view.paintBounds,
              pixelRatio: 1 / tester.view.devicePixelRatio,
            ),
          );
          final bytes = await tester.runAsync(
            () => image!.toByteData(format: ui.ImageByteFormat.png),
          );
          await tester.runAsync(() async {
            final file = File('$_captureDirectory/$name.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
          });
          image!.dispose();
        },
      );
      expect(tester.takeException(), isNull);
    },
    skip: _captureDirectory.isEmpty,
  );
}
