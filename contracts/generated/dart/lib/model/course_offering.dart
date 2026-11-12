//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class CourseOffering {
  /// Returns a new [CourseOffering] instance.
  CourseOffering({
    required this.id,
    required this.semesterId,
    required this.name,
    required this.teacher,
    this.sourceRefs = const [],
    required this.remark,
    this.retained = true,
  });

  String id;

  /// Owned workbench semester, or null when the source has no reliable mapping.
  String? semesterId;

  String name;

  /// Preserve the source display text when it contains multiple teachers.
  String? teacher;

  List<SourceRef> sourceRefs;

  String? remark;

  bool retained;

  @override
  bool operator ==(Object other) => identical(this, other) || other is CourseOffering &&
    other.id == id &&
    other.semesterId == semesterId &&
    other.name == name &&
    other.teacher == teacher &&
    _deepEquality.equals(other.sourceRefs, sourceRefs) &&
    other.remark == remark &&
    other.retained == retained;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (semesterId == null ? 0 : semesterId!.hashCode) +
    (name.hashCode) +
    (teacher == null ? 0 : teacher!.hashCode) +
    (sourceRefs.hashCode) +
    (remark == null ? 0 : remark!.hashCode) +
    (retained.hashCode);

  @override
  String toString() => 'CourseOffering[id=$id, semesterId=$semesterId, name=$name, teacher=$teacher, sourceRefs=$sourceRefs, remark=$remark, retained=$retained]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
    if (this.semesterId != null) {
      json[r'semester_id'] = this.semesterId;
    } else {
      json[r'semester_id'] = null;
    }
      json[r'name'] = this.name;
    if (this.teacher != null) {
      json[r'teacher'] = this.teacher;
    } else {
      json[r'teacher'] = null;
    }
      json[r'source_refs'] = this.sourceRefs;
    if (this.remark != null) {
      json[r'remark'] = this.remark;
    } else {
      json[r'remark'] = null;
    }
      json[r'retained'] = this.retained;
    return json;
  }

  /// Returns a new [CourseOffering] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static CourseOffering? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'id'), 'Required key "CourseOffering[id]" is missing from JSON.');
        assert(json[r'id'] != null, 'Required key "CourseOffering[id]" has a null value in JSON.');
        assert(json.containsKey(r'semester_id'), 'Required key "CourseOffering[semester_id]" is missing from JSON.');
        assert(json.containsKey(r'name'), 'Required key "CourseOffering[name]" is missing from JSON.');
        assert(json[r'name'] != null, 'Required key "CourseOffering[name]" has a null value in JSON.');
        assert(json.containsKey(r'teacher'), 'Required key "CourseOffering[teacher]" is missing from JSON.');
        assert(json.containsKey(r'source_refs'), 'Required key "CourseOffering[source_refs]" is missing from JSON.');
        assert(json[r'source_refs'] != null, 'Required key "CourseOffering[source_refs]" has a null value in JSON.');
        assert(json.containsKey(r'remark'), 'Required key "CourseOffering[remark]" is missing from JSON.');
        assert(json.containsKey(r'retained'), 'Required key "CourseOffering[retained]" is missing from JSON.');
        assert(json[r'retained'] != null, 'Required key "CourseOffering[retained]" has a null value in JSON.');
        return true;
      }());

      return CourseOffering(
        id: mapValueOfType<String>(json, r'id')!,
        semesterId: mapValueOfType<String>(json, r'semester_id'),
        name: mapValueOfType<String>(json, r'name')!,
        teacher: mapValueOfType<String>(json, r'teacher'),
        sourceRefs: SourceRef.listFromJson(json[r'source_refs']),
        remark: mapValueOfType<String>(json, r'remark'),
        retained: mapValueOfType<bool>(json, r'retained')!,
      );
    }
    return null;
  }

  static List<CourseOffering> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <CourseOffering>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CourseOffering.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, CourseOffering> mapFromJson(dynamic json) {
    final map = <String, CourseOffering>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = CourseOffering.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of CourseOffering-objects as value to a dart map
  static Map<String, List<CourseOffering>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<CourseOffering>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = CourseOffering.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'semester_id',
    'name',
    'teacher',
    'source_refs',
    'remark',
    'retained',
  };
}

