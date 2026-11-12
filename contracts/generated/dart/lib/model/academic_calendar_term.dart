//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AcademicCalendarTerm {
  /// Returns a new [AcademicCalendarTerm] instance.
  AcademicCalendarTerm({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.teachingWeeks,
  });

  String id;

  String name;

  /// Inclusive university-wide teaching start.
  DateTime startDate;

  /// Inclusive university-wide teaching end.
  DateTime endDate;

  /// Minimum value: 1
  int teachingWeeks;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AcademicCalendarTerm &&
    other.id == id &&
    other.name == name &&
    other.startDate == startDate &&
    other.endDate == endDate &&
    other.teachingWeeks == teachingWeeks;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (name.hashCode) +
    (startDate.hashCode) +
    (endDate.hashCode) +
    (teachingWeeks.hashCode);

  @override
  String toString() => 'AcademicCalendarTerm[id=$id, name=$name, startDate=$startDate, endDate=$endDate, teachingWeeks=$teachingWeeks]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'name'] = this.name;
      json[r'start_date'] = _dateFormatter.format(this.startDate);
      json[r'end_date'] = _dateFormatter.format(this.endDate);
      json[r'teaching_weeks'] = this.teachingWeeks;
    return json;
  }

  /// Returns a new [AcademicCalendarTerm] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AcademicCalendarTerm? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'id'), 'Required key "AcademicCalendarTerm[id]" is missing from JSON.');
        assert(json[r'id'] != null, 'Required key "AcademicCalendarTerm[id]" has a null value in JSON.');
        assert(json.containsKey(r'name'), 'Required key "AcademicCalendarTerm[name]" is missing from JSON.');
        assert(json[r'name'] != null, 'Required key "AcademicCalendarTerm[name]" has a null value in JSON.');
        assert(json.containsKey(r'start_date'), 'Required key "AcademicCalendarTerm[start_date]" is missing from JSON.');
        assert(json[r'start_date'] != null, 'Required key "AcademicCalendarTerm[start_date]" has a null value in JSON.');
        assert(json.containsKey(r'end_date'), 'Required key "AcademicCalendarTerm[end_date]" is missing from JSON.');
        assert(json[r'end_date'] != null, 'Required key "AcademicCalendarTerm[end_date]" has a null value in JSON.');
        assert(json.containsKey(r'teaching_weeks'), 'Required key "AcademicCalendarTerm[teaching_weeks]" is missing from JSON.');
        assert(json[r'teaching_weeks'] != null, 'Required key "AcademicCalendarTerm[teaching_weeks]" has a null value in JSON.');
        return true;
      }());

      return AcademicCalendarTerm(
        id: mapValueOfType<String>(json, r'id')!,
        name: mapValueOfType<String>(json, r'name')!,
        startDate: mapDateTime(json, r'start_date', r'')!,
        endDate: mapDateTime(json, r'end_date', r'')!,
        teachingWeeks: mapValueOfType<int>(json, r'teaching_weeks')!,
      );
    }
    return null;
  }

  static List<AcademicCalendarTerm> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AcademicCalendarTerm>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AcademicCalendarTerm.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AcademicCalendarTerm> mapFromJson(dynamic json) {
    final map = <String, AcademicCalendarTerm>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AcademicCalendarTerm.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AcademicCalendarTerm-objects as value to a dart map
  static Map<String, List<AcademicCalendarTerm>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AcademicCalendarTerm>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AcademicCalendarTerm.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'name',
    'start_date',
    'end_date',
    'teaching_weeks',
  };
}

