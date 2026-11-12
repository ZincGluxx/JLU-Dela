import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/features/planner/school_time.dart';

void main() {
  group('北京时间零点', () {
    test('北京日历日的零点换算成 UTC 时刻', () {
      expect(
        beijingDayStartUtc(DateTime.utc(2026, 11, 13)),
        DateTime.utc(2026, 11, 12, 16),
      );
    });

    test('UTC 傍晚已经属于北京次日', () {
      expect(
        beijingDayStartUtc(DateTime.utc(2026, 11, 12, 16)),
        DateTime.utc(2026, 11, 12, 16),
      );
      expect(
        beijingDayStartUtc(DateTime.utc(2026, 11, 12, 15, 59)),
        DateTime.utc(2026, 11, 11, 16),
      );
    });

    test('跨月', () {
      expect(
        beijingDayStartUtc(DateTime.utc(2026, 12, 1)),
        DateTime.utc(2026, 11, 30, 16),
      );
      expect(
        beijingDayStartUtc(DateTime.utc(2026, 11, 1)),
        DateTime.utc(2026, 10, 31, 16),
      );
    });

    test('跨年', () {
      expect(
        beijingDayStartUtc(DateTime.utc(2027, 1, 1)),
        DateTime.utc(2026, 12, 31, 16),
      );
      expect(
        beijingDayStartUtc(DateTime.utc(2026, 1, 1)),
        DateTime.utc(2025, 12, 31, 16),
      );
    });

    test('任意时刻归到所属北京日期的本地零点', () {
      final late = beijingMidnight(DateTime.utc(2026, 11, 12, 16));
      expect([late.year, late.month, late.day], [2026, 11, 13]);
      final early = beijingMidnight(DateTime.utc(2026, 11, 12, 15, 59));
      expect([early.year, early.month, early.day], [2026, 11, 12]);
      expect(early.isUtc, isFalse);
    });
  });

  group('formatDay', () {
    test('按北京日期补零', () {
      expect(formatDay(DateTime.utc(2026, 11, 12, 16)), '2026-11-13');
      expect(formatDay(DateTime.utc(2026, 11, 12, 15, 59)), '2026-11-12');
      expect(formatDay(DateTime.utc(2026, 1, 4, 20)), '2026-01-05');
    });
  });

  group('周视图', () {
    test('周五属于当周周一', () {
      expect(
        mondayOf(DateTime.utc(2026, 11, 13, 3)),
        DateTime.utc(2026, 11, 8, 16),
      );
    });

    test('周一零点不会退到上一周', () {
      expect(
        mondayOf(DateTime.utc(2026, 11, 8, 16)),
        DateTime.utc(2026, 11, 8, 16),
      );
    });

    test('周日的北京日仍属当周', () {
      expect(
        mondayOf(DateTime.utc(2026, 11, 15, 12)),
        DateTime.utc(2026, 11, 8, 16),
      );
    });

    test('跨年的周一', () {
      expect(
        mondayOf(DateTime.utc(2027, 1, 1, 3)),
        DateTime.utc(2026, 12, 27, 16),
      );
    });

    test('weekDays 给出连续 7 天', () {
      final monday = mondayOf(DateTime.utc(2026, 11, 13, 3));
      final days = weekDays(monday);
      expect(days, hasLength(7));
      expect(days.first, monday);
      expect(days.last, monday.add(const Duration(days: 6)));
      expect(formatDay(days.first), '2026-11-09');
      expect(formatDay(days.last), '2026-11-15');
    });
  });

  group('展示格式', () {
    test('时刻折到北京时间', () {
      expect(formatClock(DateTime.utc(2026, 11, 12, 9, 0)), '17:00');
      expect(formatClock(DateTime.utc(2026, 11, 12, 0, 0)), '08:00');
      expect(formatClock(DateTime.utc(2026, 11, 12, 15, 59)), '23:59');
    });

    test('无时区的日历日不再折算', () {
      expect(formatDateOnly(DateTime.utc(2026, 11, 14)), '2026-11-14');
      expect(formatDateOnly(DateTime(2026, 1, 5)), '2026-01-05');
    });
  });
}
