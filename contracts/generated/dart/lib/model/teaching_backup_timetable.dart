//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class TeachingBackupTimetable {
  /// Returns a new [TeachingBackupTimetable] instance.
  TeachingBackupTimetable({
    required this.semesterCode,
    required this.name,
    required this.isCurrent,
    required this.startsOn,
    required this.totalWeeks,
    required this.observedAtUtc,
    this.courses = const [],
    this.lessons = const [],
  });

  String semesterCode;

  String name;

  bool isCurrent;

  /// A real calendar date in YYYY-MM-DD form.
  DateTime startsOn;

  /// Minimum value: 1
  /// Maximum value: 104
  int? totalWeeks;

  DateTime observedAtUtc;

  List<TeachingBackupCourse> courses;

  List<TeachingBackupLesson> lessons;

  @override
  bool operator ==(Object other) => identical(this, other) || other is TeachingBackupTimetable &&
    other.semesterCode == semesterCode &&
    other.name == name &&
    other.isCurrent == isCurrent &&
    other.startsOn == startsOn &&
    other.totalWeeks == totalWeeks &&
    other.observedAtUtc == observedAtUtc &&
    _deepEquality.equals(other.courses, courses) &&
    _deepEquality.equals(other.lessons, lessons);

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (semesterCode.hashCode) +
    (name.hashCode) +
    (isCurrent.hashCode) +
    (startsOn.hashCode) +
    (totalWeeks == null ? 0 : totalWeeks!.hashCode) +
    (observedAtUtc.hashCode) +
    (courses.hashCode) +
    (lessons.hashCode);

  @override
  String toString() => 'TeachingBackupTimetable[semesterCode=$semesterCode, name=$name, isCurrent=$isCurrent, startsOn=$startsOn, totalWeeks=$totalWeeks, observedAtUtc=$observedAtUtc, courses=$courses, lessons=$lessons]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'semester_code'] = this.semesterCode;
      json[r'name'] = this.name;
      json[r'is_current'] = this.isCurrent;
      json[r'starts_on'] = _isEpochMarker(r'/^[0-9]{4}-[0-9]{2}-[0-9]{2}$/')
        ? this.startsOn.millisecondsSinceEpoch
        : _dateFormatter.format(this.startsOn);
    if (this.totalWeeks != null) {
      json[r'total_weeks'] = this.totalWeeks;
    } else {
      json[r'total_weeks'] = null;
    }
      json[r'observed_at_utc'] = this.observedAtUtc.toUtc().toIso8601String();
      json[r'courses'] = this.courses;
      json[r'lessons'] = this.lessons;
    return json;
  }

  /// Returns a new [TeachingBackupTimetable] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static TeachingBackupTimetable? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'semester_code'), 'Required key "TeachingBackupTimetable[semester_code]" is missing from JSON.');
        assert(json[r'semester_code'] != null, 'Required key "TeachingBackupTimetable[semester_code]" has a null value in JSON.');
        assert(json.containsKey(r'name'), 'Required key "TeachingBackupTimetable[name]" is missing from JSON.');
        assert(json[r'name'] != null, 'Required key "TeachingBackupTimetable[name]" has a null value in JSON.');
        assert(json.containsKey(r'is_current'), 'Required key "TeachingBackupTimetable[is_current]" is missing from JSON.');
        assert(json[r'is_current'] != null, 'Required key "TeachingBackupTimetable[is_current]" has a null value in JSON.');
        assert(json.containsKey(r'starts_on'), 'Required key "TeachingBackupTimetable[starts_on]" is missing from JSON.');
        assert(json[r'starts_on'] != null, 'Required key "TeachingBackupTimetable[starts_on]" has a null value in JSON.');
        assert(json.containsKey(r'total_weeks'), 'Required key "TeachingBackupTimetable[total_weeks]" is missing from JSON.');
        assert(json.containsKey(r'observed_at_utc'), 'Required key "TeachingBackupTimetable[observed_at_utc]" is missing from JSON.');
        assert(json[r'observed_at_utc'] != null, 'Required key "TeachingBackupTimetable[observed_at_utc]" has a null value in JSON.');
        assert(json.containsKey(r'courses'), 'Required key "TeachingBackupTimetable[courses]" is missing from JSON.');
        assert(json[r'courses'] != null, 'Required key "TeachingBackupTimetable[courses]" has a null value in JSON.');
        assert(json.containsKey(r'lessons'), 'Required key "TeachingBackupTimetable[lessons]" is missing from JSON.');
        assert(json[r'lessons'] != null, 'Required key "TeachingBackupTimetable[lessons]" has a null value in JSON.');
        return true;
      }());

      return TeachingBackupTimetable(
        semesterCode: mapValueOfType<String>(json, r'semester_code')!,
        name: mapValueOfType<String>(json, r'name')!,
        isCurrent: mapValueOfType<bool>(json, r'is_current')!,
        startsOn: mapDateTime(json, r'starts_on', r'/^[0-9]{4}-[0-9]{2}-[0-9]{2}$/')!,
        totalWeeks: mapValueOfType<int>(json, r'total_weeks'),
        observedAtUtc: mapDateTime(json, r'observed_at_utc', r'')!,
        courses: TeachingBackupCourse.listFromJson(json[r'courses']),
        lessons: TeachingBackupLesson.listFromJson(json[r'lessons']),
      );
    }
    return null;
  }

  static List<TeachingBackupTimetable> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <TeachingBackupTimetable>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = TeachingBackupTimetable.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, TeachingBackupTimetable> mapFromJson(dynamic json) {
    final map = <String, TeachingBackupTimetable>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = TeachingBackupTimetable.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of TeachingBackupTimetable-objects as value to a dart map
  static Map<String, List<TeachingBackupTimetable>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<TeachingBackupTimetable>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = TeachingBackupTimetable.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'semester_code',
    'name',
    'is_current',
    'starts_on',
    'total_weeks',
    'observed_at_utc',
    'courses',
    'lessons',
  };
}

