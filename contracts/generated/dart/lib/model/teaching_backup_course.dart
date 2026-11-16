//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class TeachingBackupCourse {
  /// Returns a new [TeachingBackupCourse] instance.
  TeachingBackupCourse({
    required this.courseRef,
    required this.name,
    required this.teacher,
  });

  TeachingBackupSourceRef courseRef;

  String name;

  String? teacher;

  @override
  bool operator ==(Object other) => identical(this, other) || other is TeachingBackupCourse &&
    other.courseRef == courseRef &&
    other.name == name &&
    other.teacher == teacher;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (courseRef.hashCode) +
    (name.hashCode) +
    (teacher == null ? 0 : teacher!.hashCode);

  @override
  String toString() => 'TeachingBackupCourse[courseRef=$courseRef, name=$name, teacher=$teacher]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'course_ref'] = this.courseRef;
      json[r'name'] = this.name;
    if (this.teacher != null) {
      json[r'teacher'] = this.teacher;
    } else {
      json[r'teacher'] = null;
    }
    return json;
  }

  /// Returns a new [TeachingBackupCourse] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static TeachingBackupCourse? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'course_ref'), 'Required key "TeachingBackupCourse[course_ref]" is missing from JSON.');
        assert(json[r'course_ref'] != null, 'Required key "TeachingBackupCourse[course_ref]" has a null value in JSON.');
        assert(json.containsKey(r'name'), 'Required key "TeachingBackupCourse[name]" is missing from JSON.');
        assert(json[r'name'] != null, 'Required key "TeachingBackupCourse[name]" has a null value in JSON.');
        assert(json.containsKey(r'teacher'), 'Required key "TeachingBackupCourse[teacher]" is missing from JSON.');
        return true;
      }());

      return TeachingBackupCourse(
        courseRef: TeachingBackupSourceRef.fromJson(json[r'course_ref'])!,
        name: mapValueOfType<String>(json, r'name')!,
        teacher: mapValueOfType<String>(json, r'teacher'),
      );
    }
    return null;
  }

  static List<TeachingBackupCourse> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <TeachingBackupCourse>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = TeachingBackupCourse.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, TeachingBackupCourse> mapFromJson(dynamic json) {
    final map = <String, TeachingBackupCourse>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = TeachingBackupCourse.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of TeachingBackupCourse-objects as value to a dart map
  static Map<String, List<TeachingBackupCourse>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<TeachingBackupCourse>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = TeachingBackupCourse.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'course_ref',
    'name',
    'teacher',
  };
}

