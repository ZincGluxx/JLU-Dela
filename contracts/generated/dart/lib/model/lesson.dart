//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class Lesson {
  /// Returns a new [Lesson] instance.
  Lesson({
    required this.id,
    required this.courseOfferingId,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required this.location,
    required this.periodStart,
    required this.periodEnd,
  });

  String id;

  String courseOfferingId;

  /// Source course name for the calendar lesson title.
  String title;

  DateTime startsAt;

  DateTime endsAt;

  String? location;

  /// Minimum value: 1
  int? periodStart;

  /// Minimum value: 1
  int? periodEnd;

  @override
  bool operator ==(Object other) => identical(this, other) || other is Lesson &&
    other.id == id &&
    other.courseOfferingId == courseOfferingId &&
    other.title == title &&
    other.startsAt == startsAt &&
    other.endsAt == endsAt &&
    other.location == location &&
    other.periodStart == periodStart &&
    other.periodEnd == periodEnd;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (courseOfferingId.hashCode) +
    (title.hashCode) +
    (startsAt.hashCode) +
    (endsAt.hashCode) +
    (location == null ? 0 : location!.hashCode) +
    (periodStart == null ? 0 : periodStart!.hashCode) +
    (periodEnd == null ? 0 : periodEnd!.hashCode);

  @override
  String toString() => 'Lesson[id=$id, courseOfferingId=$courseOfferingId, title=$title, startsAt=$startsAt, endsAt=$endsAt, location=$location, periodStart=$periodStart, periodEnd=$periodEnd]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'course_offering_id'] = this.courseOfferingId;
      json[r'title'] = this.title;
      json[r'starts_at'] = _isEpochMarker(r'/Z$/')
        ? this.startsAt.millisecondsSinceEpoch
        : this.startsAt.toUtc().toIso8601String();
      json[r'ends_at'] = _isEpochMarker(r'/Z$/')
        ? this.endsAt.millisecondsSinceEpoch
        : this.endsAt.toUtc().toIso8601String();
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
    return json;
  }

  /// Returns a new [Lesson] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static Lesson? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'id'), 'Required key "Lesson[id]" is missing from JSON.');
        assert(json[r'id'] != null, 'Required key "Lesson[id]" has a null value in JSON.');
        assert(json.containsKey(r'course_offering_id'), 'Required key "Lesson[course_offering_id]" is missing from JSON.');
        assert(json[r'course_offering_id'] != null, 'Required key "Lesson[course_offering_id]" has a null value in JSON.');
        assert(json.containsKey(r'title'), 'Required key "Lesson[title]" is missing from JSON.');
        assert(json[r'title'] != null, 'Required key "Lesson[title]" has a null value in JSON.');
        assert(json.containsKey(r'starts_at'), 'Required key "Lesson[starts_at]" is missing from JSON.');
        assert(json[r'starts_at'] != null, 'Required key "Lesson[starts_at]" has a null value in JSON.');
        assert(json.containsKey(r'ends_at'), 'Required key "Lesson[ends_at]" is missing from JSON.');
        assert(json[r'ends_at'] != null, 'Required key "Lesson[ends_at]" has a null value in JSON.');
        assert(json.containsKey(r'location'), 'Required key "Lesson[location]" is missing from JSON.');
        assert(json.containsKey(r'period_start'), 'Required key "Lesson[period_start]" is missing from JSON.');
        assert(json.containsKey(r'period_end'), 'Required key "Lesson[period_end]" is missing from JSON.');
        return true;
      }());

      return Lesson(
        id: mapValueOfType<String>(json, r'id')!,
        courseOfferingId: mapValueOfType<String>(json, r'course_offering_id')!,
        title: mapValueOfType<String>(json, r'title')!,
        startsAt: mapDateTime(json, r'starts_at', r'/Z$/')!,
        endsAt: mapDateTime(json, r'ends_at', r'/Z$/')!,
        location: mapValueOfType<String>(json, r'location'),
        periodStart: mapValueOfType<int>(json, r'period_start'),
        periodEnd: mapValueOfType<int>(json, r'period_end'),
      );
    }
    return null;
  }

  static List<Lesson> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <Lesson>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = Lesson.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, Lesson> mapFromJson(dynamic json) {
    final map = <String, Lesson>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = Lesson.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of Lesson-objects as value to a dart map
  static Map<String, List<Lesson>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<Lesson>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = Lesson.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'course_offering_id',
    'title',
    'starts_at',
    'ends_at',
    'location',
    'period_start',
    'period_end',
  };
}

