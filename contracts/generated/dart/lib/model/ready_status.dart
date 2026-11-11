//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ReadyStatus {
  /// Returns a new [ReadyStatus] instance.
  ReadyStatus({
    required this.status,
    required this.schemaVersion,
  });

  ReadyStatusStatusEnum status;

  /// Version stored in the service_meta table by the migration chain.
  String schemaVersion;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ReadyStatus &&
    other.status == status &&
    other.schemaVersion == schemaVersion;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (status.hashCode) +
    (schemaVersion.hashCode);

  @override
  String toString() => 'ReadyStatus[status=$status, schemaVersion=$schemaVersion]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'status'] = this.status;
      json[r'schema_version'] = this.schemaVersion;
    return json;
  }

  /// Returns a new [ReadyStatus] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ReadyStatus? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'status'), 'Required key "ReadyStatus[status]" is missing from JSON.');
        assert(json[r'status'] != null, 'Required key "ReadyStatus[status]" has a null value in JSON.');
        assert(json.containsKey(r'schema_version'), 'Required key "ReadyStatus[schema_version]" is missing from JSON.');
        assert(json[r'schema_version'] != null, 'Required key "ReadyStatus[schema_version]" has a null value in JSON.');
        return true;
      }());

      return ReadyStatus(
        status: ReadyStatusStatusEnum.fromJson(json[r'status'])!,
        schemaVersion: mapValueOfType<String>(json, r'schema_version')!,
      );
    }
    return null;
  }

  static List<ReadyStatus> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ReadyStatus>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ReadyStatus.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ReadyStatus> mapFromJson(dynamic json) {
    final map = <String, ReadyStatus>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ReadyStatus.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ReadyStatus-objects as value to a dart map
  static Map<String, List<ReadyStatus>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ReadyStatus>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ReadyStatus.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'status',
    'schema_version',
  };
}


enum ReadyStatusStatusEnum {
  ready._(r'ready'),
  ;

  /// Instantiate a new enum with the provided value.
  const ReadyStatusStatusEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [ReadyStatusStatusEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static ReadyStatusStatusEnum? fromJson(dynamic value) => ReadyStatusStatusEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [ReadyStatusStatusEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<ReadyStatusStatusEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ReadyStatusStatusEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ReadyStatusStatusEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [ReadyStatusStatusEnum] to String,
/// and [decode] dynamic data back to [ReadyStatusStatusEnum].
class ReadyStatusStatusEnumTypeTransformer {
  factory ReadyStatusStatusEnumTypeTransformer() => _instance ??= const ReadyStatusStatusEnumTypeTransformer._();

  const ReadyStatusStatusEnumTypeTransformer._();

  String encode(ReadyStatusStatusEnum data) => data._value;

  /// Returns the instance of [ReadyStatusStatusEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  ReadyStatusStatusEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data is ReadyStatusStatusEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'ready': return ReadyStatusStatusEnum.ready;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static ReadyStatusStatusEnumTypeTransformer? _instance;
}


