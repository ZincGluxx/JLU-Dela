List<int> parseTeachingWeekPattern(String pattern, {required int totalWeeks}) {
  if (totalWeeks < 1) {
    throw ArgumentError.value(totalWeeks, 'totalWeeks', 'Must be positive');
  }

  final normalized = pattern
      .trim()
      .replaceAll('，', ',')
      .replaceAll('（', '(')
      .replaceAll('）', ')');
  final match = RegExp(
    r'^([0-9]+(?:-[0-9]+)?(?:,[0-9]+(?:-[0-9]+)?)*)周?(?:\(([单双])\))?$',
  ).firstMatch(normalized);
  if (match == null) {
    throw FormatException('Invalid teaching week pattern', pattern);
  }

  final parity = match.group(2);
  final weeks = <int>{};
  for (final part in match.group(1)!.split(',')) {
    final bounds = part.split('-').map(int.parse).toList();
    final first = bounds.first;
    final last = bounds.last;
    if (first < 1 || first > last || last > totalWeeks) {
      throw FormatException(
        'Teaching weeks are outside the valid range',
        pattern,
      );
    }
    for (var week = first; week <= last; week++) {
      if (parity == null ||
          (parity == '单' && week.isOdd) ||
          (parity == '双' && week.isEven)) {
        weeks.add(week);
      }
    }
  }
  if (weeks.isEmpty) {
    throw FormatException('Teaching week pattern selects no weeks', pattern);
  }
  return weeks.toList()..sort();
}
