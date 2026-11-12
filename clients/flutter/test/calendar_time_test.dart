import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/core/models/local_date.dart';
import 'package:jlu_dela/core/models/school_time.dart';
import 'package:jlu_dela/features/planner/calendar_grid.dart';
import 'package:jlu_dela/features/planner/calendar_time.dart';

void main() {
  group('Asia/Shanghai 换算', () {
    test('UTC 傍晚属于北京次日', () {
      expect(
        schoolDateOf(DateTime.utc(2026, 11, 12, 16)),
        const LocalDate(2026, 11, 13),
      );
      expect(
        schoolDateOf(DateTime.utc(2026, 11, 12, 15, 59)),
        const LocalDate(2026, 11, 12),
      );
    });

    test('北京时刻按 UTC+8 显示', () {
      expect(formatSchoolClock(DateTime.utc(2026, 11, 12, 9)), '17:00');
      expect(formatSchoolClock(DateTime.utc(2026, 11, 12, 0)), '08:00');
      expect(formatSchoolClock(DateTime.utc(2026, 11, 12, 15, 59)), '23:59');
    });

    test('北京时间零点对应的 UTC 时刻', () {
      expect(
        schoolDayStartUtc(const LocalDate(2026, 11, 13)),
        DateTime.utc(2026, 11, 12, 16),
      );
    });

    test('时间戳标签固定按北京时间', () {
      expect(
        calendarTimestampLabel(DateTime.utc(2026, 11, 12, 2)),
        '2026年11月12日 10:00',
      );
      expect(
        calendarTimestampLabel(DateTime.utc(2026, 11, 12, 16, 30)),
        '2026年11月13日 00:30',
      );
    });
  });

  group('周范围', () {
    test('周一开始到下周一共 7 天', () {
      final range = weekRangeOf(const LocalDate(2026, 11, 12));
      expect(range.from, const LocalDate(2026, 11, 9));
      expect(range.to, const LocalDate(2026, 11, 16));
      expect(range.days, hasLength(7));
    });

    test('周一与周日都归入同一周', () {
      expect(
        weekRangeOf(const LocalDate(2026, 11, 9)).from,
        const LocalDate(2026, 11, 9),
      );
      expect(
        weekRangeOf(const LocalDate(2026, 11, 15)).from,
        const LocalDate(2026, 11, 9),
      );
    });

    test('跨年周仍从周一开始', () {
      final range = weekRangeOf(const LocalDate(2027, 1, 1));
      expect(range.from, const LocalDate(2026, 12, 28));
      expect(range.to, const LocalDate(2027, 1, 4));
    });

    test('范围是左闭右开', () {
      final range = weekRangeOf(const LocalDate(2026, 11, 12));
      expect(range.contains(const LocalDate(2026, 11, 9)), isTrue);
      expect(range.contains(const LocalDate(2026, 11, 16)), isFalse);
      expect(range.contains(const LocalDate(2026, 11, 8)), isFalse);
    });

    test('周标签省略同年重复年份', () {
      expect(
        calendarWeekLabel(const LocalDate(2026, 11, 9)),
        '2026年11月9日 – 11月15日',
      );
      expect(
        calendarWeekLabel(const LocalDate(2026, 12, 28)),
        '2026年12月28日 – 2027年1月3日',
      );
    });
  });

  group('月范围与月网格', () {
    test('月范围从当月 1 日到次月 1 日', () {
      final range = monthRangeOf(const LocalDate(2026, 11, 12));
      expect(range.from, const LocalDate(2026, 11, 1));
      expect(range.to, const LocalDate(2026, 12, 1));
    });

    test('12 月递增跨年', () {
      expect(
        shiftMonthStart(const LocalDate(2026, 12, 1), 1),
        const LocalDate(2027, 1, 1),
      );
      expect(
        shiftMonthStart(const LocalDate(2027, 1, 1), -1),
        const LocalDate(2026, 12, 1),
      );
    });

    test('月网格补齐完整周', () {
      final range = monthGridRangeOf(const LocalDate(2026, 11, 12));
      expect(range.from, const LocalDate(2026, 10, 26));
      expect(range.to, const LocalDate(2026, 12, 7));
      expect(range.lengthInDays, 42);
      expect(range.days.first.weekday, DateTime.monday);
      expect(range.days.last.weekday, DateTime.sunday);
    });

    test('2 月恰好从周一开始时只占 5 周', () {
      final range = monthGridRangeOf(const LocalDate(2027, 2, 1));
      expect(range.from, const LocalDate(2027, 2, 1));
      expect(range.to, const LocalDate(2027, 3, 8));
      expect(range.lengthInDays, 35);
    });

    test('月标签', () {
      expect(calendarMonthLabel(const LocalDate(2026, 11, 12)), '2026年11月');
    });
  });

  group('日期展示', () {
    test('星期标签从周一开始', () {
      expect(calendarWeekdayLabel(const LocalDate(2026, 11, 9)), '周一');
      expect(calendarWeekdayLabel(const LocalDate(2026, 11, 15)), '周日');
    });

    test('长短日期标签', () {
      expect(calendarDateLabel(const LocalDate(2026, 11, 9)), '2026年11月9日');
      expect(calendarShortDateLabel(const LocalDate(2026, 11, 9)), '11月9日');
    });
  });
}
