//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AcademicPeriod {
  /// Returns a new [AcademicPeriod] instance.
  AcademicPeriod({
    required this.number,
    required this.startTime,
    required this.endTime,
  });

  /// Minimum value: 1
  /// Maximum value: 12
  int number;

  String startTime;

  String endTime;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AcademicPeriod &&
    other.number == number &&
    other.startTime == startTime &&
    other.endTime == endTime;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (number.hashCode) +
    (startTime.hashCode) +
    (endTime.hashCode);

  @override
  String toString() => 'AcademicPeriod[number=$number, startTime=$startTime, endTime=$endTime]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'number'] = this.number;
      json[r'start_time'] = this.startTime;
      json[r'end_time'] = this.endTime;
    return json;
  }

  /// Returns a new [AcademicPeriod] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AcademicPeriod? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'number'), 'Required key "AcademicPeriod[number]" is missing from JSON.');
        assert(json[r'number'] != null, 'Required key "AcademicPeriod[number]" has a null value in JSON.');
        assert(json.containsKey(r'start_time'), 'Required key "AcademicPeriod[start_time]" is missing from JSON.');
        assert(json[r'start_time'] != null, 'Required key "AcademicPeriod[start_time]" has a null value in JSON.');
        assert(json.containsKey(r'end_time'), 'Required key "AcademicPeriod[end_time]" is missing from JSON.');
        assert(json[r'end_time'] != null, 'Required key "AcademicPeriod[end_time]" has a null value in JSON.');
        return true;
      }());

      return AcademicPeriod(
        number: mapValueOfType<int>(json, r'number')!,
        startTime: mapValueOfType<String>(json, r'start_time')!,
        endTime: mapValueOfType<String>(json, r'end_time')!,
      );
    }
    return null;
  }

  static List<AcademicPeriod> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AcademicPeriod>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AcademicPeriod.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AcademicPeriod> mapFromJson(dynamic json) {
    final map = <String, AcademicPeriod>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AcademicPeriod.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AcademicPeriod-objects as value to a dart map
  static Map<String, List<AcademicPeriod>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AcademicPeriod>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AcademicPeriod.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'number',
    'start_time',
    'end_time',
  };
}

