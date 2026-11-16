import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/support/bound_materials_flow.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Windows bound course private material flow with source fixtures', (
    tester,
  ) async {
    debugPrint(
      'Windows materials logical viewport: ${tester.view.physicalSize / tester.view.devicePixelRatio}',
    );
    await exerciseBoundMaterialsFlow(tester, fromTeaching: true);
  });
  testWidgets('Windows account switch destroys material source page', (
    tester,
  ) async {
    await exerciseBoundMaterialsFlow(tester, privacy: 'source');
  });
}
