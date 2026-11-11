//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class CalendarItem {
  CalendarItem._(this.actualInstance);

  CalendarItem.fromAssignmentItem(AssignmentItem value) : actualInstance = value;
  CalendarItem.fromLessonItem(LessonItem value) : actualInstance = value;
  CalendarItem.fromTodoItem(TodoItem value) : actualInstance = value;

  final Object actualInstance;

  Map<String, dynamic> toJson() {
    final value = actualInstance;
    if (value is AssignmentItem) return value.toJson();
    if (value is LessonItem) return value.toJson();
    if (value is TodoItem) return value.toJson();
    throw StateError('Invalid CalendarItem instance');
  }

  static CalendarItem? fromJson(dynamic value) {
    if (value is! Map) return null;
    switch (value[r'kind']) {
      case 'assignment':
        return CalendarItem._(AssignmentItem.fromJson(value)!);
      case 'lesson':
        return CalendarItem._(LessonItem.fromJson(value)!);
      case 'todo':
        return CalendarItem._(TodoItem.fromJson(value)!);
      default:
        throw FormatException('Unknown CalendarItem discriminator', value[r'kind']);
    }
  }

  static List<CalendarItem> listFromJson(dynamic json, {bool growable = false}) =>
      json is List
          ? json.map((value) => fromJson(value)!).toList(growable: growable)
          : <CalendarItem>[];

  static Map<String, CalendarItem> mapFromJson(dynamic json) =>
      json is Map
          ? json.map((key, value) => MapEntry(key as String, fromJson(value)!))
          : <String, CalendarItem>{};

  static Map<String, List<CalendarItem>> mapListFromJson(dynamic json, {bool growable = false}) =>
      json is Map
          ? json.map((key, value) => MapEntry(key as String, listFromJson(value, growable: growable)))
          : <String, List<CalendarItem>>{};

  @override
  bool operator ==(Object other) =>
      other is CalendarItem && actualInstance == other.actualInstance;

  @override
  int get hashCode => actualInstance.hashCode;
}
