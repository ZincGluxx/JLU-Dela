import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/app/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'uses bundled HarmonyOS Sans SC for readable application text',
    () async {
      final theme = AppTheme.light();
      expect(theme.textTheme.bodyMedium?.fontFamily, 'HarmonyOS Sans SC');
      expect(theme.textTheme.titleLarge?.fontFamily, 'HarmonyOS Sans SC');
      for (final weight in ['Regular', 'Medium', 'Bold']) {
        final font = await rootBundle.load(
          'assets/fonts/HarmonyOS_Sans_SC_$weight.ttf',
        );
        expect(font.lengthInBytes, greaterThan(1000000));
      }
      final license = await rootBundle.loadString(
        'assets/fonts/LICENSE_Fonts.txt',
      );
      expect(license, contains('Copyright 2021 Huawei Device Co., Ltd.'));
      expect(license, contains('HarmonyOS Sans Fonts License Agreement'));
    },
  );
}
