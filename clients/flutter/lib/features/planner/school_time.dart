/// 学校日历固定使用 Asia/Shanghai（UTC+8，无夏令时）。
///
/// 服务端把 `from` / `to` 解释为北京时间日历日，客户端切天必须用同一把尺子：
/// 设备时区不是 UTC+8 时，本地日期与北京日期可能相差一天，所以这里先把时刻折算
/// 到北京时间再取年月日，而不是直接读 [DateTime.year] 这些本地字段。
const Duration schoolUtcOffset = Duration(hours: 8);

/// 任意时刻所属的北京时间日历日，写成只表示年月日的 UTC 日历值。
DateTime _schoolDate(DateTime value) {
  final school = value.toUtc().add(schoolUtcOffset);
  return DateTime.utc(school.year, school.month, school.day);
}

String _two(int value) => value.toString().padLeft(2, '0');

/// 把任意时刻归到它所属的北京时间当天零点，返回本地 [DateTime] 供展示。
///
/// 返回值的年月日就是北京日历日，因此同一北京日的不同时刻得到相等的值，可以直接
/// 用来分组；但它的时刻本身是设备本地零点，不能当作北京零点对应的瞬间使用。
DateTime beijingMidnight(DateTime day) {
  final date = _schoolDate(day);
  return DateTime(date.year, date.month, date.day);
}

/// 北京时间当天零点对应的 UTC 时刻，周视图的区间端点用它。
///
/// 例如 `2026-11-13` 的北京零点等于 `2026-11-12T16:00:00Z`。
DateTime beijingDayStartUtc(DateTime day) {
  return _schoolDate(day).subtract(schoolUtcOffset);
}

/// 北京时间日历日的 `YYYY-MM-DD` 写法。
String formatDay(DateTime day) {
  final date = _schoolDate(day);
  return '${date.year.toString().padLeft(4, '0')}-${_two(date.month)}-${_two(date.day)}';
}

/// 周视图起点：该时刻所属北京时间那一周的周一，返回北京时间周一零点的 UTC 时刻。
DateTime mondayOf(DateTime day) {
  final date = _schoolDate(day);
  return date
      .subtract(Duration(days: date.weekday - 1))
      .subtract(schoolUtcOffset);
}

/// 从 [monday] 起的 7 天，每项都是北京时间当天零点的 UTC 时刻。
List<DateTime> weekDays(DateTime monday) {
  return [
    for (var index = 0; index < 7; index++) monday.add(Duration(days: index)),
  ];
}

/// 北京时间的一天之内的时刻，写成 `HH:mm`。
String formatClock(DateTime value) {
  final school = value.toUtc().add(schoolUtcOffset);
  return '${_two(school.hour)}:${_two(school.minute)}';
}

/// 已经是一个日历日的值（`due_date` 这类）写成的 `YYYY-MM-DD`。
///
/// 这类值不带时区，再折一次北京时间会把它挪到前一天或后一天，所以直接取年月日。
String formatDateOnly(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-${_two(value.month)}-${_two(value.day)}';
}
