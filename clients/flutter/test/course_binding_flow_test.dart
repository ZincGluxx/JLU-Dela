import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/course_binding_flow.dart';

void main() {
  testWidgets('binding flow at narrow width with enlarged text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(() {
      tester.binding.setSurfaceSize(null);
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await exerciseCourseBindingFlow(tester);
    expect(tester.takeException(), isNull);
  });
  for (final width in [390.0, 820.0, 1280.0, 1920.0]) {
    testWidgets('connect, bind, view, open and recover at $width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await exerciseCourseBindingFlow(tester);
      expect(tester.takeException(), isNull);
    });
  }
}
