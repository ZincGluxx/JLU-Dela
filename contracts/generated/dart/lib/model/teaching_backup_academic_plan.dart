//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class TeachingBackupAcademicPlan {
  /// Returns a new [TeachingBackupAcademicPlan] instance.
  TeachingBackupAcademicPlan({
    required this.id,
    required this.name,
    required this.studyType,
    required this.calculatedAtSchool,
    required this.requiredCredits,
    required this.earnedCredits,
    required this.selectedCredits,
    this.groups = const [],
  });

  /// School plan identifier, not a device-generated UUID.
  String id;

  String name;

  String? studyType;

  /// Original school calculation text, not an RFC3339 timestamp or local export time.
  String? calculatedAtSchool;

  String? requiredCredits;

  String? earnedCredits;

  String? selectedCredits;

  List<TeachingBackupAcademicGroup> groups;

  @override
  bool operator ==(Object other) => identical(this, other) || other is TeachingBackupAcademicPlan &&
    other.id == id &&
    other.name == name &&
    other.studyType == studyType &&
    other.calculatedAtSchool == calculatedAtSchool &&
    other.requiredCredits == requiredCredits &&
    other.earnedCredits == earnedCredits &&
    other.selectedCredits == selectedCredits &&
    _deepEquality.equals(other.groups, groups);

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (name.hashCode) +
    (studyType == null ? 0 : studyType!.hashCode) +
    (calculatedAtSchool == null ? 0 : calculatedAtSchool!.hashCode) +
    (requiredCredits == null ? 0 : requiredCredits!.hashCode) +
    (earnedCredits == null ? 0 : earnedCredits!.hashCode) +
    (selectedCredits == null ? 0 : selectedCredits!.hashCode) +
    (groups.hashCode);

  @override
  String toString() => 'TeachingBackupAcademicPlan[id=$id, name=$name, studyType=$studyType, calculatedAtSchool=$calculatedAtSchool, requiredCredits=$requiredCredits, earnedCredits=$earnedCredits, selectedCredits=$selectedCredits, groups=$groups]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'name'] = this.name;
    if (this.studyType != null) {
      json[r'study_type'] = this.studyType;
    } else {
      json[r'study_type'] = null;
    }
    if (this.calculatedAtSchool != null) {
      json[r'calculated_at_school'] = this.calculatedAtSchool;
    } else {
      json[r'calculated_at_school'] = null;
    }
    if (this.requiredCredits != null) {
      json[r'required_credits'] = this.requiredCredits;
    } else {
      json[r'required_credits'] = null;
    }
    if (this.earnedCredits != null) {
      json[r'earned_credits'] = this.earnedCredits;
    } else {
      json[r'earned_credits'] = null;
    }
    if (this.selectedCredits != null) {
      json[r'selected_credits'] = this.selectedCredits;
    } else {
      json[r'selected_credits'] = null;
    }
      json[r'groups'] = this.groups;
    return json;
  }

  /// Returns a new [TeachingBackupAcademicPlan] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static TeachingBackupAcademicPlan? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'id'), 'Required key "TeachingBackupAcademicPlan[id]" is missing from JSON.');
        assert(json[r'id'] != null, 'Required key "TeachingBackupAcademicPlan[id]" has a null value in JSON.');
        assert(json.containsKey(r'name'), 'Required key "TeachingBackupAcademicPlan[name]" is missing from JSON.');
        assert(json[r'name'] != null, 'Required key "TeachingBackupAcademicPlan[name]" has a null value in JSON.');
        assert(json.containsKey(r'study_type'), 'Required key "TeachingBackupAcademicPlan[study_type]" is missing from JSON.');
        assert(json.containsKey(r'calculated_at_school'), 'Required key "TeachingBackupAcademicPlan[calculated_at_school]" is missing from JSON.');
        assert(json.containsKey(r'required_credits'), 'Required key "TeachingBackupAcademicPlan[required_credits]" is missing from JSON.');
        assert(json.containsKey(r'earned_credits'), 'Required key "TeachingBackupAcademicPlan[earned_credits]" is missing from JSON.');
        assert(json.containsKey(r'selected_credits'), 'Required key "TeachingBackupAcademicPlan[selected_credits]" is missing from JSON.');
        assert(json.containsKey(r'groups'), 'Required key "TeachingBackupAcademicPlan[groups]" is missing from JSON.');
        assert(json[r'groups'] != null, 'Required key "TeachingBackupAcademicPlan[groups]" has a null value in JSON.');
        return true;
      }());

      return TeachingBackupAcademicPlan(
        id: mapValueOfType<String>(json, r'id')!,
        name: mapValueOfType<String>(json, r'name')!,
        studyType: mapValueOfType<String>(json, r'study_type'),
        calculatedAtSchool: mapValueOfType<String>(json, r'calculated_at_school'),
        requiredCredits: mapValueOfType<String>(json, r'required_credits'),
        earnedCredits: mapValueOfType<String>(json, r'earned_credits'),
        selectedCredits: mapValueOfType<String>(json, r'selected_credits'),
        groups: TeachingBackupAcademicGroup.listFromJson(json[r'groups']),
      );
    }
    return null;
  }

  static List<TeachingBackupAcademicPlan> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <TeachingBackupAcademicPlan>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = TeachingBackupAcademicPlan.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, TeachingBackupAcademicPlan> mapFromJson(dynamic json) {
    final map = <String, TeachingBackupAcademicPlan>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = TeachingBackupAcademicPlan.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of TeachingBackupAcademicPlan-objects as value to a dart map
  static Map<String, List<TeachingBackupAcademicPlan>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<TeachingBackupAcademicPlan>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = TeachingBackupAcademicPlan.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'name',
    'study_type',
    'calculated_at_school',
    'required_credits',
    'earned_credits',
    'selected_credits',
    'groups',
  };
}

