//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class TeachingBackupPayload {
  /// Returns a new [TeachingBackupPayload] instance.
  TeachingBackupPayload({
    required this.format,
    required this.formatVersion,
    required this.exportedAtUtc,
    this.timetables = const Optional.present(const []),
    this.periodTimes = const Optional.present(const []),
    this.coursePreferences = const Optional.present(const []),
    this.academicCompletion = const Optional.absent(),
  });

  TeachingBackupPayloadFormatEnum format;

  TeachingBackupPayloadFormatVersionEnum formatVersion;

  DateTime exportedAtUtc;

  Optional<List<TeachingBackupTimetable>?> timetables;

  Optional<List<TeachingBackupPeriodTime>?> periodTimes;

  Optional<List<TeachingBackupCoursePreference>?> coursePreferences;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  Optional<TeachingBackupAcademicCompletion?> academicCompletion;

  @override
  bool operator ==(Object other) => identical(this, other) || other is TeachingBackupPayload &&
    other.format == format &&
    other.formatVersion == formatVersion &&
    other.exportedAtUtc == exportedAtUtc &&
    _deepEquality.equals(other.timetables, timetables) &&
    _deepEquality.equals(other.periodTimes, periodTimes) &&
    _deepEquality.equals(other.coursePreferences, coursePreferences) &&
    other.academicCompletion == academicCompletion;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (format.hashCode) +
    (formatVersion.hashCode) +
    (exportedAtUtc.hashCode) +
    (timetables.hashCode) +
    (periodTimes.hashCode) +
    (coursePreferences.hashCode) +
    (academicCompletion == null ? 0 : academicCompletion!.hashCode);

  @override
  String toString() => 'TeachingBackupPayload[format=$format, formatVersion=$formatVersion, exportedAtUtc=$exportedAtUtc, timetables=$timetables, periodTimes=$periodTimes, coursePreferences=$coursePreferences, academicCompletion=$academicCompletion]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'format'] = this.format;
      json[r'format_version'] = this.formatVersion;
      json[r'exported_at_utc'] = this.exportedAtUtc.toUtc().toIso8601String();
    if (this.timetables.isPresent) {
      final value = this.timetables.value;
      json[r'timetables'] = value;
    }
    if (this.periodTimes.isPresent) {
      final value = this.periodTimes.value;
      json[r'period_times'] = value;
    }
    if (this.coursePreferences.isPresent) {
      final value = this.coursePreferences.value;
      json[r'course_preferences'] = value;
    }
    if (this.academicCompletion.isPresent) {
      final value = this.academicCompletion.value;
      json[r'academic_completion'] = value;
    }
    return json;
  }

  /// Returns a new [TeachingBackupPayload] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static TeachingBackupPayload? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'format'), 'Required key "TeachingBackupPayload[format]" is missing from JSON.');
        assert(json[r'format'] != null, 'Required key "TeachingBackupPayload[format]" has a null value in JSON.');
        assert(json.containsKey(r'format_version'), 'Required key "TeachingBackupPayload[format_version]" is missing from JSON.');
        assert(json[r'format_version'] != null, 'Required key "TeachingBackupPayload[format_version]" has a null value in JSON.');
        assert(json.containsKey(r'exported_at_utc'), 'Required key "TeachingBackupPayload[exported_at_utc]" is missing from JSON.');
        assert(json[r'exported_at_utc'] != null, 'Required key "TeachingBackupPayload[exported_at_utc]" has a null value in JSON.');
        return true;
      }());

      return TeachingBackupPayload(
        format: TeachingBackupPayloadFormatEnum.fromJson(json[r'format'])!,
        formatVersion: TeachingBackupPayloadFormatVersionEnum.fromJson(json[r'format_version'])!,
        exportedAtUtc: mapDateTime(json, r'exported_at_utc', r'')!,
        timetables: json.containsKey(r'timetables') ? Optional.present(TeachingBackupTimetable.listFromJson(json[r'timetables'])) : const Optional.absent(),
        periodTimes: json.containsKey(r'period_times') ? Optional.present(TeachingBackupPeriodTime.listFromJson(json[r'period_times'])) : const Optional.absent(),
        coursePreferences: json.containsKey(r'course_preferences') ? Optional.present(TeachingBackupCoursePreference.listFromJson(json[r'course_preferences'])) : const Optional.absent(),
        academicCompletion: json.containsKey(r'academic_completion') ? Optional.present(TeachingBackupAcademicCompletion.fromJson(json[r'academic_completion'])) : const Optional.absent(),
      );
    }
    return null;
  }

  static List<TeachingBackupPayload> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <TeachingBackupPayload>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = TeachingBackupPayload.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, TeachingBackupPayload> mapFromJson(dynamic json) {
    final map = <String, TeachingBackupPayload>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = TeachingBackupPayload.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of TeachingBackupPayload-objects as value to a dart map
  static Map<String, List<TeachingBackupPayload>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<TeachingBackupPayload>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = TeachingBackupPayload.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'format',
    'format_version',
    'exported_at_utc',
  };
}


enum TeachingBackupPayloadFormatEnum {
  jluDelaTeachingBackup._(r'jlu_dela_teaching_backup'),
  ;

  /// Instantiate a new enum with the provided value.
  const TeachingBackupPayloadFormatEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [TeachingBackupPayloadFormatEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static TeachingBackupPayloadFormatEnum? fromJson(dynamic value) => TeachingBackupPayloadFormatEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [TeachingBackupPayloadFormatEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<TeachingBackupPayloadFormatEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <TeachingBackupPayloadFormatEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = TeachingBackupPayloadFormatEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [TeachingBackupPayloadFormatEnum] to String,
/// and [decode] dynamic data back to [TeachingBackupPayloadFormatEnum].
class TeachingBackupPayloadFormatEnumTypeTransformer {
  factory TeachingBackupPayloadFormatEnumTypeTransformer() => _instance ??= const TeachingBackupPayloadFormatEnumTypeTransformer._();

  const TeachingBackupPayloadFormatEnumTypeTransformer._();

  String encode(TeachingBackupPayloadFormatEnum data) => data._value;

  /// Returns the instance of [TeachingBackupPayloadFormatEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  TeachingBackupPayloadFormatEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data is TeachingBackupPayloadFormatEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'jlu_dela_teaching_backup': return TeachingBackupPayloadFormatEnum.jluDelaTeachingBackup;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static TeachingBackupPayloadFormatEnumTypeTransformer? _instance;
}



enum TeachingBackupPayloadFormatVersionEnum {
  number1._(1),
  ;

  /// Instantiate a new enum with the provided value.
  const TeachingBackupPayloadFormatVersionEnum._(this._value);

  /// The underlying value of this enum member.
  final int _value;

  @override
  String toString() => _value.toString();

  /// Encodes this enum as a value suitable for JSON.
  int toJson() => _value;

  /// Returns the instance of [TeachingBackupPayloadFormatVersionEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static TeachingBackupPayloadFormatVersionEnum? fromJson(dynamic value) => TeachingBackupPayloadFormatVersionEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [TeachingBackupPayloadFormatVersionEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<TeachingBackupPayloadFormatVersionEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <TeachingBackupPayloadFormatVersionEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = TeachingBackupPayloadFormatVersionEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [TeachingBackupPayloadFormatVersionEnum] to int,
/// and [decode] dynamic data back to [TeachingBackupPayloadFormatVersionEnum].
class TeachingBackupPayloadFormatVersionEnumTypeTransformer {
  factory TeachingBackupPayloadFormatVersionEnumTypeTransformer() => _instance ??= const TeachingBackupPayloadFormatVersionEnumTypeTransformer._();

  const TeachingBackupPayloadFormatVersionEnumTypeTransformer._();

  int encode(TeachingBackupPayloadFormatVersionEnum data) => data._value;

  /// Returns the instance of [TeachingBackupPayloadFormatVersionEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  TeachingBackupPayloadFormatVersionEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data is TeachingBackupPayloadFormatVersionEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case 1: return TeachingBackupPayloadFormatVersionEnum.number1;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static TeachingBackupPayloadFormatVersionEnumTypeTransformer? _instance;
}


