//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class TeachingBackupPeriodTime {
  /// Returns a new [TeachingBackupPeriodTime] instance.
  TeachingBackupPeriodTime({
    required this.campus,
    required this.period,
    required this.startMinute,
    required this.endMinute,
    required this.observedAtUtc,
  });

  String campus;

  /// Minimum value: 1
  /// Maximum value: 500
  int period;

  /// Minimum value: 0
  /// Maximum value: 1439
  int startMinute;

  /// Minimum value: 1
  /// Maximum value: 1440
  int endMinute;

  DateTime observedAtUtc;

  @override
  bool operator ==(Object other) => identical(this, other) || other is TeachingBackupPeriodTime &&
    other.campus == campus &&
    other.period == period &&
    other.startMinute == startMinute &&
    other.endMinute == endMinute &&
    other.observedAtUtc == observedAtUtc;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (campus.hashCode) +
    (period.hashCode) +
    (startMinute.hashCode) +
    (endMinute.hashCode) +
    (observedAtUtc.hashCode);

  @override
  String toString() => 'TeachingBackupPeriodTime[campus=$campus, period=$period, startMinute=$startMinute, endMinute=$endMinute, observedAtUtc=$observedAtUtc]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'campus'] = this.campus;
      json[r'period'] = this.period;
      json[r'start_minute'] = this.startMinute;
      json[r'end_minute'] = this.endMinute;
      json[r'observed_at_utc'] = this.observedAtUtc.toUtc().toIso8601String();
    return json;
  }

  /// Returns a new [TeachingBackupPeriodTime] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static TeachingBackupPeriodTime? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'campus'), 'Required key "TeachingBackupPeriodTime[campus]" is missing from JSON.');
        assert(json[r'campus'] != null, 'Required key "TeachingBackupPeriodTime[campus]" has a null value in JSON.');
        assert(json.containsKey(r'period'), 'Required key "TeachingBackupPeriodTime[period]" is missing from JSON.');
        assert(json[r'period'] != null, 'Required key "TeachingBackupPeriodTime[period]" has a null value in JSON.');
        assert(json.containsKey(r'start_minute'), 'Required key "TeachingBackupPeriodTime[start_minute]" is missing from JSON.');
        assert(json[r'start_minute'] != null, 'Required key "TeachingBackupPeriodTime[start_minute]" has a null value in JSON.');
        assert(json.containsKey(r'end_minute'), 'Required key "TeachingBackupPeriodTime[end_minute]" is missing from JSON.');
        assert(json[r'end_minute'] != null, 'Required key "TeachingBackupPeriodTime[end_minute]" has a null value in JSON.');
        assert(json.containsKey(r'observed_at_utc'), 'Required key "TeachingBackupPeriodTime[observed_at_utc]" is missing from JSON.');
        assert(json[r'observed_at_utc'] != null, 'Required key "TeachingBackupPeriodTime[observed_at_utc]" has a null value in JSON.');
        return true;
      }());

      return TeachingBackupPeriodTime(
        campus: mapValueOfType<String>(json, r'campus')!,
        period: mapValueOfType<int>(json, r'period')!,
        startMinute: mapValueOfType<int>(json, r'start_minute')!,
        endMinute: mapValueOfType<int>(json, r'end_minute')!,
        observedAtUtc: mapDateTime(json, r'observed_at_utc', r'')!,
      );
    }
    return null;
  }

  static List<TeachingBackupPeriodTime> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <TeachingBackupPeriodTime>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = TeachingBackupPeriodTime.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, TeachingBackupPeriodTime> mapFromJson(dynamic json) {
    final map = <String, TeachingBackupPeriodTime>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = TeachingBackupPeriodTime.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of TeachingBackupPeriodTime-objects as value to a dart map
  static Map<String, List<TeachingBackupPeriodTime>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<TeachingBackupPeriodTime>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = TeachingBackupPeriodTime.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'campus',
    'period',
    'start_minute',
    'end_minute',
    'observed_at_utc',
  };
}

