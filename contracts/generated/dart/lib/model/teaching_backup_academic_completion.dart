//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class TeachingBackupAcademicCompletion {
  /// Returns a new [TeachingBackupAcademicCompletion] instance.
  TeachingBackupAcademicCompletion({
    required this.selectionSemester,
    required this.currentSemester,
    required this.observedAtUtc,
    this.plans = const [],
  });

  String selectionSemester;

  String currentSemester;

  DateTime observedAtUtc;

  List<TeachingBackupAcademicPlan> plans;

  @override
  bool operator ==(Object other) => identical(this, other) || other is TeachingBackupAcademicCompletion &&
    other.selectionSemester == selectionSemester &&
    other.currentSemester == currentSemester &&
    other.observedAtUtc == observedAtUtc &&
    _deepEquality.equals(other.plans, plans);

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (selectionSemester.hashCode) +
    (currentSemester.hashCode) +
    (observedAtUtc.hashCode) +
    (plans.hashCode);

  @override
  String toString() => 'TeachingBackupAcademicCompletion[selectionSemester=$selectionSemester, currentSemester=$currentSemester, observedAtUtc=$observedAtUtc, plans=$plans]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'selection_semester'] = this.selectionSemester;
      json[r'current_semester'] = this.currentSemester;
      json[r'observed_at_utc'] = this.observedAtUtc.toUtc().toIso8601String();
      json[r'plans'] = this.plans;
    return json;
  }

  /// Returns a new [TeachingBackupAcademicCompletion] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static TeachingBackupAcademicCompletion? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'selection_semester'), 'Required key "TeachingBackupAcademicCompletion[selection_semester]" is missing from JSON.');
        assert(json[r'selection_semester'] != null, 'Required key "TeachingBackupAcademicCompletion[selection_semester]" has a null value in JSON.');
        assert(json.containsKey(r'current_semester'), 'Required key "TeachingBackupAcademicCompletion[current_semester]" is missing from JSON.');
        assert(json[r'current_semester'] != null, 'Required key "TeachingBackupAcademicCompletion[current_semester]" has a null value in JSON.');
        assert(json.containsKey(r'observed_at_utc'), 'Required key "TeachingBackupAcademicCompletion[observed_at_utc]" is missing from JSON.');
        assert(json[r'observed_at_utc'] != null, 'Required key "TeachingBackupAcademicCompletion[observed_at_utc]" has a null value in JSON.');
        assert(json.containsKey(r'plans'), 'Required key "TeachingBackupAcademicCompletion[plans]" is missing from JSON.');
        assert(json[r'plans'] != null, 'Required key "TeachingBackupAcademicCompletion[plans]" has a null value in JSON.');
        return true;
      }());

      return TeachingBackupAcademicCompletion(
        selectionSemester: mapValueOfType<String>(json, r'selection_semester')!,
        currentSemester: mapValueOfType<String>(json, r'current_semester')!,
        observedAtUtc: mapDateTime(json, r'observed_at_utc', r'')!,
        plans: TeachingBackupAcademicPlan.listFromJson(json[r'plans']),
      );
    }
    return null;
  }

  static List<TeachingBackupAcademicCompletion> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <TeachingBackupAcademicCompletion>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = TeachingBackupAcademicCompletion.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, TeachingBackupAcademicCompletion> mapFromJson(dynamic json) {
    final map = <String, TeachingBackupAcademicCompletion>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = TeachingBackupAcademicCompletion.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of TeachingBackupAcademicCompletion-objects as value to a dart map
  static Map<String, List<TeachingBackupAcademicCompletion>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<TeachingBackupAcademicCompletion>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = TeachingBackupAcademicCompletion.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'selection_semester',
    'current_semester',
    'observed_at_utc',
    'plans',
  };
}

