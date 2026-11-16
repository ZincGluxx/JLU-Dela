//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class TeachingBackupAcademicGroup {
  /// Returns a new [TeachingBackupAcademicGroup] instance.
  TeachingBackupAcademicGroup({
    required this.id,
    required this.parentId,
    required this.name,
    required this.kind,
    required this.requiredCredits,
    required this.earnedCredits,
    required this.selectedCredits,
    required this.courseNature,
    required this.requiredCourses,
    required this.earnedCourses,
    required this.requiredGroups,
    required this.earnedGroups,
    required this.choiceGroups,
  });

  String id;

  String? parentId;

  String name;

  String kind;

  String requiredCredits;

  String earnedCredits;

  String selectedCredits;

  String? courseNature;

  /// Minimum value: 0
  /// Maximum value: 1000000
  int? requiredCourses;

  /// Minimum value: 0
  /// Maximum value: 1000000
  int? earnedCourses;

  /// Minimum value: 0
  /// Maximum value: 1000000
  int? requiredGroups;

  /// Minimum value: 0
  /// Maximum value: 1000000
  int? earnedGroups;

  /// Minimum value: 0
  /// Maximum value: 1000000
  int? choiceGroups;

  @override
  bool operator ==(Object other) => identical(this, other) || other is TeachingBackupAcademicGroup &&
    other.id == id &&
    other.parentId == parentId &&
    other.name == name &&
    other.kind == kind &&
    other.requiredCredits == requiredCredits &&
    other.earnedCredits == earnedCredits &&
    other.selectedCredits == selectedCredits &&
    other.courseNature == courseNature &&
    other.requiredCourses == requiredCourses &&
    other.earnedCourses == earnedCourses &&
    other.requiredGroups == requiredGroups &&
    other.earnedGroups == earnedGroups &&
    other.choiceGroups == choiceGroups;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (parentId == null ? 0 : parentId!.hashCode) +
    (name.hashCode) +
    (kind.hashCode) +
    (requiredCredits.hashCode) +
    (earnedCredits.hashCode) +
    (selectedCredits.hashCode) +
    (courseNature == null ? 0 : courseNature!.hashCode) +
    (requiredCourses == null ? 0 : requiredCourses!.hashCode) +
    (earnedCourses == null ? 0 : earnedCourses!.hashCode) +
    (requiredGroups == null ? 0 : requiredGroups!.hashCode) +
    (earnedGroups == null ? 0 : earnedGroups!.hashCode) +
    (choiceGroups == null ? 0 : choiceGroups!.hashCode);

  @override
  String toString() => 'TeachingBackupAcademicGroup[id=$id, parentId=$parentId, name=$name, kind=$kind, requiredCredits=$requiredCredits, earnedCredits=$earnedCredits, selectedCredits=$selectedCredits, courseNature=$courseNature, requiredCourses=$requiredCourses, earnedCourses=$earnedCourses, requiredGroups=$requiredGroups, earnedGroups=$earnedGroups, choiceGroups=$choiceGroups]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
    if (this.parentId != null) {
      json[r'parent_id'] = this.parentId;
    } else {
      json[r'parent_id'] = null;
    }
      json[r'name'] = this.name;
      json[r'kind'] = this.kind;
      json[r'required_credits'] = this.requiredCredits;
      json[r'earned_credits'] = this.earnedCredits;
      json[r'selected_credits'] = this.selectedCredits;
    if (this.courseNature != null) {
      json[r'course_nature'] = this.courseNature;
    } else {
      json[r'course_nature'] = null;
    }
    if (this.requiredCourses != null) {
      json[r'required_courses'] = this.requiredCourses;
    } else {
      json[r'required_courses'] = null;
    }
    if (this.earnedCourses != null) {
      json[r'earned_courses'] = this.earnedCourses;
    } else {
      json[r'earned_courses'] = null;
    }
    if (this.requiredGroups != null) {
      json[r'required_groups'] = this.requiredGroups;
    } else {
      json[r'required_groups'] = null;
    }
    if (this.earnedGroups != null) {
      json[r'earned_groups'] = this.earnedGroups;
    } else {
      json[r'earned_groups'] = null;
    }
    if (this.choiceGroups != null) {
      json[r'choice_groups'] = this.choiceGroups;
    } else {
      json[r'choice_groups'] = null;
    }
    return json;
  }

  /// Returns a new [TeachingBackupAcademicGroup] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static TeachingBackupAcademicGroup? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'id'), 'Required key "TeachingBackupAcademicGroup[id]" is missing from JSON.');
        assert(json[r'id'] != null, 'Required key "TeachingBackupAcademicGroup[id]" has a null value in JSON.');
        assert(json.containsKey(r'parent_id'), 'Required key "TeachingBackupAcademicGroup[parent_id]" is missing from JSON.');
        assert(json.containsKey(r'name'), 'Required key "TeachingBackupAcademicGroup[name]" is missing from JSON.');
        assert(json[r'name'] != null, 'Required key "TeachingBackupAcademicGroup[name]" has a null value in JSON.');
        assert(json.containsKey(r'kind'), 'Required key "TeachingBackupAcademicGroup[kind]" is missing from JSON.');
        assert(json[r'kind'] != null, 'Required key "TeachingBackupAcademicGroup[kind]" has a null value in JSON.');
        assert(json.containsKey(r'required_credits'), 'Required key "TeachingBackupAcademicGroup[required_credits]" is missing from JSON.');
        assert(json[r'required_credits'] != null, 'Required key "TeachingBackupAcademicGroup[required_credits]" has a null value in JSON.');
        assert(json.containsKey(r'earned_credits'), 'Required key "TeachingBackupAcademicGroup[earned_credits]" is missing from JSON.');
        assert(json[r'earned_credits'] != null, 'Required key "TeachingBackupAcademicGroup[earned_credits]" has a null value in JSON.');
        assert(json.containsKey(r'selected_credits'), 'Required key "TeachingBackupAcademicGroup[selected_credits]" is missing from JSON.');
        assert(json[r'selected_credits'] != null, 'Required key "TeachingBackupAcademicGroup[selected_credits]" has a null value in JSON.');
        assert(json.containsKey(r'course_nature'), 'Required key "TeachingBackupAcademicGroup[course_nature]" is missing from JSON.');
        assert(json.containsKey(r'required_courses'), 'Required key "TeachingBackupAcademicGroup[required_courses]" is missing from JSON.');
        assert(json.containsKey(r'earned_courses'), 'Required key "TeachingBackupAcademicGroup[earned_courses]" is missing from JSON.');
        assert(json.containsKey(r'required_groups'), 'Required key "TeachingBackupAcademicGroup[required_groups]" is missing from JSON.');
        assert(json.containsKey(r'earned_groups'), 'Required key "TeachingBackupAcademicGroup[earned_groups]" is missing from JSON.');
        assert(json.containsKey(r'choice_groups'), 'Required key "TeachingBackupAcademicGroup[choice_groups]" is missing from JSON.');
        return true;
      }());

      return TeachingBackupAcademicGroup(
        id: mapValueOfType<String>(json, r'id')!,
        parentId: mapValueOfType<String>(json, r'parent_id'),
        name: mapValueOfType<String>(json, r'name')!,
        kind: mapValueOfType<String>(json, r'kind')!,
        requiredCredits: mapValueOfType<String>(json, r'required_credits')!,
        earnedCredits: mapValueOfType<String>(json, r'earned_credits')!,
        selectedCredits: mapValueOfType<String>(json, r'selected_credits')!,
        courseNature: mapValueOfType<String>(json, r'course_nature'),
        requiredCourses: mapValueOfType<int>(json, r'required_courses'),
        earnedCourses: mapValueOfType<int>(json, r'earned_courses'),
        requiredGroups: mapValueOfType<int>(json, r'required_groups'),
        earnedGroups: mapValueOfType<int>(json, r'earned_groups'),
        choiceGroups: mapValueOfType<int>(json, r'choice_groups'),
      );
    }
    return null;
  }

  static List<TeachingBackupAcademicGroup> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <TeachingBackupAcademicGroup>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = TeachingBackupAcademicGroup.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, TeachingBackupAcademicGroup> mapFromJson(dynamic json) {
    final map = <String, TeachingBackupAcademicGroup>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = TeachingBackupAcademicGroup.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of TeachingBackupAcademicGroup-objects as value to a dart map
  static Map<String, List<TeachingBackupAcademicGroup>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<TeachingBackupAcademicGroup>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = TeachingBackupAcademicGroup.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'parent_id',
    'name',
    'kind',
    'required_credits',
    'earned_credits',
    'selected_credits',
    'course_nature',
    'required_courses',
    'earned_courses',
    'required_groups',
    'earned_groups',
    'choice_groups',
  };
}

