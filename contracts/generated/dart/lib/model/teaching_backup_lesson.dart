//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class TeachingBackupLesson {
  /// Returns a new [TeachingBackupLesson] instance.
  TeachingBackupLesson({
    required this.courseRef,
    required this.title,
    required this.startsAtUtc,
    required this.endsAtUtc,
    required this.location,
    required this.periodStart,
    required this.periodEnd,
    required this.weekday,
    required this.weekNumber,
    required this.note,
  });

  TeachingBackupSourceRef courseRef;

  String title;

  DateTime startsAtUtc;

  DateTime endsAtUtc;

  String? location;

  /// Minimum value: 1
  /// Maximum value: 500
  int? periodStart;

  /// Minimum value: 1
  /// Maximum value: 500
  int? periodEnd;

  /// Minimum value: 1
  /// Maximum value: 7
  int weekday;

  /// Minimum value: 1
  /// Maximum value: 104
  int weekNumber;

  String? note;

  @override
  bool operator ==(Object other) => identical(this, other) || other is TeachingBackupLesson &&
    other.courseRef == courseRef &&
    other.title == title &&
    other.startsAtUtc == startsAtUtc &&
    other.endsAtUtc == endsAtUtc &&
    other.location == location &&
    other.periodStart == periodStart &&
    other.periodEnd == periodEnd &&
    other.weekday == weekday &&
    other.weekNumber == weekNumber &&
    other.note == note;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (courseRef.hashCode) +
    (title.hashCode) +
    (startsAtUtc.hashCode) +
    (endsAtUtc.hashCode) +
    (location == null ? 0 : location!.hashCode) +
    (periodStart == null ? 0 : periodStart!.hashCode) +
    (periodEnd == null ? 0 : periodEnd!.hashCode) +
    (weekday.hashCode) +
    (weekNumber.hashCode) +
    (note == null ? 0 : note!.hashCode);

  @override
  String toString() => 'TeachingBackupLesson[courseRef=$courseRef, title=$title, startsAtUtc=$startsAtUtc, endsAtUtc=$endsAtUtc, location=$location, periodStart=$periodStart, periodEnd=$periodEnd, weekday=$weekday, weekNumber=$weekNumber, note=$note]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'course_ref'] = this.courseRef;
      json[r'title'] = this.title;
      json[r'starts_at_utc'] = this.startsAtUtc.toUtc().toIso8601String();
      json[r'ends_at_utc'] = this.endsAtUtc.toUtc().toIso8601String();
    if (this.location != null) {
      json[r'location'] = this.location;
    } else {
      json[r'location'] = null;
    }
    if (this.periodStart != null) {
      json[r'period_start'] = this.periodStart;
    } else {
      json[r'period_start'] = null;
    }
    if (this.periodEnd != null) {
      json[r'period_end'] = this.periodEnd;
    } else {
      json[r'period_end'] = null;
    }
      json[r'weekday'] = this.weekday;
      json[r'week_number'] = this.weekNumber;
    if (this.note != null) {
      json[r'note'] = this.note;
    } else {
      json[r'note'] = null;
    }
    return json;
  }

  /// Returns a new [TeachingBackupLesson] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static TeachingBackupLesson? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'course_ref'), 'Required key "TeachingBackupLesson[course_ref]" is missing from JSON.');
        assert(json[r'course_ref'] != null, 'Required key "TeachingBackupLesson[course_ref]" has a null value in JSON.');
        assert(json.containsKey(r'title'), 'Required key "TeachingBackupLesson[title]" is missing from JSON.');
        assert(json[r'title'] != null, 'Required key "TeachingBackupLesson[title]" has a null value in JSON.');
        assert(json.containsKey(r'starts_at_utc'), 'Required key "TeachingBackupLesson[starts_at_utc]" is missing from JSON.');
        assert(json[r'starts_at_utc'] != null, 'Required key "TeachingBackupLesson[starts_at_utc]" has a null value in JSON.');
        assert(json.containsKey(r'ends_at_utc'), 'Required key "TeachingBackupLesson[ends_at_utc]" is missing from JSON.');
        assert(json[r'ends_at_utc'] != null, 'Required key "TeachingBackupLesson[ends_at_utc]" has a null value in JSON.');
        assert(json.containsKey(r'location'), 'Required key "TeachingBackupLesson[location]" is missing from JSON.');
        assert(json.containsKey(r'period_start'), 'Required key "TeachingBackupLesson[period_start]" is missing from JSON.');
        assert(json.containsKey(r'period_end'), 'Required key "TeachingBackupLesson[period_end]" is missing from JSON.');
        assert(json.containsKey(r'weekday'), 'Required key "TeachingBackupLesson[weekday]" is missing from JSON.');
        assert(json[r'weekday'] != null, 'Required key "TeachingBackupLesson[weekday]" has a null value in JSON.');
        assert(json.containsKey(r'week_number'), 'Required key "TeachingBackupLesson[week_number]" is missing from JSON.');
        assert(json[r'week_number'] != null, 'Required key "TeachingBackupLesson[week_number]" has a null value in JSON.');
        assert(json.containsKey(r'note'), 'Required key "TeachingBackupLesson[note]" is missing from JSON.');
        return true;
      }());

      return TeachingBackupLesson(
        courseRef: TeachingBackupSourceRef.fromJson(json[r'course_ref'])!,
        title: mapValueOfType<String>(json, r'title')!,
        startsAtUtc: mapDateTime(json, r'starts_at_utc', r'')!,
        endsAtUtc: mapDateTime(json, r'ends_at_utc', r'')!,
        location: mapValueOfType<String>(json, r'location'),
        periodStart: mapValueOfType<int>(json, r'period_start'),
        periodEnd: mapValueOfType<int>(json, r'period_end'),
        weekday: mapValueOfType<int>(json, r'weekday')!,
        weekNumber: mapValueOfType<int>(json, r'week_number')!,
        note: mapValueOfType<String>(json, r'note'),
      );
    }
    return null;
  }

  static List<TeachingBackupLesson> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <TeachingBackupLesson>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = TeachingBackupLesson.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, TeachingBackupLesson> mapFromJson(dynamic json) {
    final map = <String, TeachingBackupLesson>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = TeachingBackupLesson.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of TeachingBackupLesson-objects as value to a dart map
  static Map<String, List<TeachingBackupLesson>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<TeachingBackupLesson>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = TeachingBackupLesson.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'course_ref',
    'title',
    'starts_at_utc',
    'ends_at_utc',
    'location',
    'period_start',
    'period_end',
    'weekday',
    'week_number',
    'note',
  };
}

