/// 校园当地日历日，只表示年月日，不携带时区。
///
/// 纯日期值用 UTC 午夜做算术，避免设备时区参与；时刻换算见 `school_time.dart`。
class LocalDate implements Comparable<LocalDate> {
  const LocalDate(this.year, this.month, this.day);

  factory LocalDate.fromDateTime(DateTime value) {
    return LocalDate(value.year, value.month, value.day);
  }

  factory LocalDate.parse(String value) {
    final parts = value.split('-');
    return LocalDate(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  final int year;
  final int month;
  final int day;

  DateTime get utcMidnight => DateTime.utc(year, month, day);

  int get weekday => utcMidnight.weekday;

  LocalDate addDays(int days) {
    return LocalDate.fromDateTime(utcMidnight.add(Duration(days: days)));
  }

  int differenceInDays(LocalDate other) {
    return utcMidnight.difference(other.utcMidnight).inDays;
  }

  String toIso8601String() {
    final paddedMonth = month.toString().padLeft(2, '0');
    final paddedDay = day.toString().padLeft(2, '0');
    return '$year-$paddedMonth-$paddedDay';
  }

  @override
  int compareTo(LocalDate other) => utcMidnight.compareTo(other.utcMidnight);

  @override
  bool operator ==(Object other) {
    return other is LocalDate &&
        other.year == year &&
        other.month == month &&
        other.day == day;
  }

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toIso8601String();
}
