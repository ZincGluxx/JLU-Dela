//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class Semester {
  /// Returns a new [Semester] instance.
  Semester({
    required this.id,
    required this.name,
    required this.startsOn,
    required this.endsOn,
    required this.timezone,
    required this.sourceRef,
  });

  String id;

  /// Nonempty semester display name from the source.
  String name;

  /// School-defined teaching-week origin; unknown is null, never the collection date or an assumed Monday.
  DateTime? startsOn;

  DateTime? endsOn;

  SemesterTimezoneEnum timezone;

  /// Verified teaching source identity; semesters in this draft come from jlu_iedu.
  SourceRef sourceRef;

  @override
  bool operator ==(Object other) => identical(this, other) || other is Semester &&
    other.id == id &&
    other.name == name &&
    other.startsOn == startsOn &&
    other.endsOn == endsOn &&
    other.timezone == timezone &&
    other.sourceRef == sourceRef;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (name.hashCode) +
    (startsOn == null ? 0 : startsOn!.hashCode) +
    (endsOn == null ? 0 : endsOn!.hashCode) +
    (timezone.hashCode) +
    (sourceRef.hashCode);

  @override
  String toString() => 'Semester[id=$id, name=$name, startsOn=$startsOn, endsOn=$endsOn, timezone=$timezone, sourceRef=$sourceRef]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'name'] = this.name;
    if (this.startsOn != null) {
      json[r'starts_on'] = _dateFormatter.format(this.startsOn!);
    } else {
      json[r'starts_on'] = null;
    }
    if (this.endsOn != null) {
      json[r'ends_on'] = _dateFormatter.format(this.endsOn!);
    } else {
      json[r'ends_on'] = null;
    }
      json[r'timezone'] = this.timezone;
      json[r'source_ref'] = this.sourceRef;
    return json;
  }

  /// Returns a new [Semester] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static Semester? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'id'), 'Required key "Semester[id]" is missing from JSON.');
        assert(json[r'id'] != null, 'Required key "Semester[id]" has a null value in JSON.');
        assert(json.containsKey(r'name'), 'Required key "Semester[name]" is missing from JSON.');
        assert(json[r'name'] != null, 'Required key "Semester[name]" has a null value in JSON.');
        assert(json.containsKey(r'starts_on'), 'Required key "Semester[starts_on]" is missing from JSON.');
        assert(json.containsKey(r'ends_on'), 'Required key "Semester[ends_on]" is missing from JSON.');
        assert(json.containsKey(r'timezone'), 'Required key "Semester[timezone]" is missing from JSON.');
        assert(json[r'timezone'] != null, 'Required key "Semester[timezone]" has a null value in JSON.');
        assert(json.containsKey(r'source_ref'), 'Required key "Semester[source_ref]" is missing from JSON.');
        assert(json[r'source_ref'] != null, 'Required key "Semester[source_ref]" has a null value in JSON.');
        return true;
      }());

      return Semester(
        id: mapValueOfType<String>(json, r'id')!,
        name: mapValueOfType<String>(json, r'name')!,
        startsOn: mapDateTime(json, r'starts_on', r''),
        endsOn: mapDateTime(json, r'ends_on', r''),
        timezone: SemesterTimezoneEnum.fromJson(json[r'timezone'])!,
        sourceRef: SourceRef.fromJson(json[r'source_ref'])!,
      );
    }
    return null;
  }

  static List<Semester> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <Semester>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = Semester.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, Semester> mapFromJson(dynamic json) {
    final map = <String, Semester>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = Semester.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of Semester-objects as value to a dart map
  static Map<String, List<Semester>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<Semester>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = Semester.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'name',
    'starts_on',
    'ends_on',
    'timezone',
    'source_ref',
  };
}


enum SemesterTimezoneEnum {
  asiaSlashShanghai._(r'Asia/Shanghai'),
  ;

  /// Instantiate a new enum with the provided value.
  const SemesterTimezoneEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [SemesterTimezoneEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static SemesterTimezoneEnum? fromJson(dynamic value) => SemesterTimezoneEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [SemesterTimezoneEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<SemesterTimezoneEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SemesterTimezoneEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SemesterTimezoneEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [SemesterTimezoneEnum] to String,
/// and [decode] dynamic data back to [SemesterTimezoneEnum].
class SemesterTimezoneEnumTypeTransformer {
  factory SemesterTimezoneEnumTypeTransformer() => _instance ??= const SemesterTimezoneEnumTypeTransformer._();

  const SemesterTimezoneEnumTypeTransformer._();

  String encode(SemesterTimezoneEnum data) => data._value;

  /// Returns the instance of [SemesterTimezoneEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  SemesterTimezoneEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data is SemesterTimezoneEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'Asia/Shanghai': return SemesterTimezoneEnum.asiaSlashShanghai;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static SemesterTimezoneEnumTypeTransformer? _instance;
}


