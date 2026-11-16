import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/bound_materials_flow.dart';

void main() {
  testWidgets(
    'teaching lesson opens only matching bound platform material directories',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await exerciseBoundMaterialsFlow(tester, fromTeaching: true);
    },
  );
  testWidgets(
    'teaching course without that platform binding never falls back by name',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await exerciseBoundMaterialsFlow(
        tester,
        fromTeaching: true,
        bindingCase: 'unbound',
      );
    },
  );
  testWidgets(
    'teaching course with no platform bindings shows empty scoped directory',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await exerciseBoundMaterialsFlow(
        tester,
        fromTeaching: true,
        bindingCase: 'none',
      );
    },
  );
  for (final width in [390.0, 820.0, 1280.0, 1920.0]) {
    testWidgets('bound course private materials flow at $width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await exerciseBoundMaterialsFlow(tester);
      expect(tester.takeException(), isNull);
    });
  }
  for (final change in ['switch', 'signout', 'relogin']) {
    for (final dialog in ['access', 'source', 'dropdown', 'inflight']) {
      testWidgets('$change disposes material $dialog and underlying routes', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(1280, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await exerciseBoundMaterialsFlow(
          tester,
          privacy: dialog,
          accountChange: change,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
  for (final binding in ['missing', 'unbound']) {
    testWidgets(
      '$binding teaching binding keeps original platform materials available',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await exerciseBoundMaterialsFlow(tester, bindingCase: binding);
      },
    );
  }
}
