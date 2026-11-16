//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class TeachingBackupCoursePreference {
  /// Returns a new [TeachingBackupCoursePreference] instance.
  TeachingBackupCoursePreference({
    required this.courseRef,
    required this.remark,
    required this.retained,
  });

  TeachingBackupSourceRef courseRef;

  String? remark;

  bool retained;

  @override
  bool operator ==(Object other) => identical(this, other) || other is TeachingBackupCoursePreference &&
    other.courseRef == courseRef &&
    other.remark == remark &&
    other.retained == retained;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (courseRef.hashCode) +
    (remark == null ? 0 : remark!.hashCode) +
    (retained.hashCode);

  @override
  String toString() => 'TeachingBackupCoursePreference[courseRef=$courseRef, remark=$remark, retained=$retained]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'course_ref'] = this.courseRef;
    if (this.remark != null) {
      json[r'remark'] = this.remark;
    } else {
      json[r'remark'] = null;
    }
      json[r'retained'] = this.retained;
    return json;
  }

  /// Returns a new [TeachingBackupCoursePreference] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static TeachingBackupCoursePreference? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'course_ref'), 'Required key "TeachingBackupCoursePreference[course_ref]" is missing from JSON.');
        assert(json[r'course_ref'] != null, 'Required key "TeachingBackupCoursePreference[course_ref]" has a null value in JSON.');
        assert(json.containsKey(r'remark'), 'Required key "TeachingBackupCoursePreference[remark]" is missing from JSON.');
        assert(json.containsKey(r'retained'), 'Required key "TeachingBackupCoursePreference[retained]" is missing from JSON.');
        assert(json[r'retained'] != null, 'Required key "TeachingBackupCoursePreference[retained]" has a null value in JSON.');
        return true;
      }());

      return TeachingBackupCoursePreference(
        courseRef: TeachingBackupSourceRef.fromJson(json[r'course_ref'])!,
        remark: mapValueOfType<String>(json, r'remark'),
        retained: mapValueOfType<bool>(json, r'retained')!,
      );
    }
    return null;
  }

  static List<TeachingBackupCoursePreference> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <TeachingBackupCoursePreference>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = TeachingBackupCoursePreference.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, TeachingBackupCoursePreference> mapFromJson(dynamic json) {
    final map = <String, TeachingBackupCoursePreference>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = TeachingBackupCoursePreference.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of TeachingBackupCoursePreference-objects as value to a dart map
  static Map<String, List<TeachingBackupCoursePreference>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<TeachingBackupCoursePreference>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = TeachingBackupCoursePreference.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'course_ref',
    'remark',
    'retained',
  };
}

