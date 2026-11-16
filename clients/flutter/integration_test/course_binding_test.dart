import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/support/course_binding_flow.dart';
import '../test/assignments_dialog_session_test.dart' as dialog_session;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  dialog_session.main();
  testWidgets(
    'Windows learning platform course binding flow with source fixtures',
    (tester) async {
      final logical = tester.view.physicalSize / tester.view.devicePixelRatio;
      debugPrint('Windows binding logical viewport: $logical');
      await exerciseCourseBindingFlow(tester);
      expect(tester.takeException(), isNull);
    },
  );
}
