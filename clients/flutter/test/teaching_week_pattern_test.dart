import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/features/teaching/teaching_week_pattern.dart';

void main() {
  group('parseTeachingWeekPattern', () {
    test('expands an inclusive range', () {
      expect(parseTeachingWeekPattern('1-5', totalWeeks: 5), [1, 2, 3, 4, 5]);
    });

    test('combines ranges and discrete weeks', () {
      expect(parseTeachingWeekPattern('1-5,8,10', totalWeeks: 10), [
        1,
        2,
        3,
        4,
        5,
        8,
        10,
      ]);
    });

    test('sorts and deduplicates overlapping ranges and discrete weeks', () {
      expect(parseTeachingWeekPattern('8,3-5,1,4-6,8', totalWeeks: 8), [
        1,
        3,
        4,
        5,
        6,
        8,
      ]);
    });

    test('filters odd weeks by absolute week number', () {
      expect(parseTeachingWeekPattern('1-16周(单)', totalWeeks: 16), [
        1,
        3,
        5,
        7,
        9,
        11,
        13,
        15,
      ]);
      expect(parseTeachingWeekPattern('2-6周(单)', totalWeeks: 6), [3, 5]);
    });

    test('filters even weeks and accepts Chinese punctuation', () {
      expect(parseTeachingWeekPattern('1-16周（双）', totalWeeks: 16), [
        2,
        4,
        6,
        8,
        10,
        12,
        14,
        16,
      ]);
      expect(parseTeachingWeekPattern('1-5，8，10', totalWeeks: 10), [
        1,
        2,
        3,
        4,
        5,
        8,
        10,
      ]);
    });

    test('applies the parity suffix to the whole list', () {
      expect(parseTeachingWeekPattern('1-5，8，10周（双）', totalWeeks: 10), [
        2,
        4,
        8,
        10,
      ]);
      expect(parseTeachingWeekPattern('1-5(单)', totalWeeks: 5), [1, 3, 5]);
    });

    test('accepts explicit boundaries and trims surrounding whitespace', () {
      expect(parseTeachingWeekPattern(' 1周\n', totalWeeks: 1), [1]);
      expect(parseTeachingWeekPattern('1,7-7', totalWeeks: 7), [1, 7]);
    });

    test('requires a positive totalWeeks', () {
      for (final totalWeeks in [0, -1]) {
        expect(
          () => parseTeachingWeekPattern('1', totalWeeks: totalWeeks),
          throwsArgumentError,
        );
      }
    });

    for (final pattern in [
      '',
      ' \t\n',
      '周',
      '(单)',
      '0',
      '0-2',
      '5-1',
      '11',
      '1-11',
      '0-4周(单)',
      '1-11周(双)',
      '1,',
      ',1',
      '1,,3',
      '1，,3',
      '-1',
      '1-',
      '1--3',
      '1-3-5',
      '1.5',
      '1;3',
      '1 0',
      '1\n2',
      '1-3x',
      '1-3周(单',
      '1-3周(单双)',
      '1-3周(单)extra',
      '1-3,invalid,5',
      '1-3,0',
      '1-3,7-5',
      '1-3,11',
      '1-3,5-',
      '1周(双)',
      '2-2周(单)',
      '1,3,5周(双)',
    ]) {
      test(
        'rejects invalid or empty selection: ${pattern.replaceAll('\n', r'\n')}',
        () {
          expect(
            () => parseTeachingWeekPattern(pattern, totalWeeks: 10),
            throwsFormatException,
          );
        },
      );
    }
  });
}
