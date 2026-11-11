//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SourceStatus {
  /// Returns a new [SourceStatus] instance.
  SourceStatus({
    required this.source_,
    required this.status,
    this.lastSuccessAt = const Optional.absent(),
  });

  SourceStatusSource_Enum source_;

  SourceStatusStatusEnum status;

  /// Null before the first successful sync.
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  Optional<DateTime?> lastSuccessAt;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SourceStatus &&
    other.source_ == source_ &&
    other.status == status &&
    other.lastSuccessAt == lastSuccessAt;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (source_.hashCode) +
    (status.hashCode) +
    (lastSuccessAt == null ? 0 : lastSuccessAt!.hashCode);

  @override
  String toString() => 'SourceStatus[source_=$source_, status=$status, lastSuccessAt=$lastSuccessAt]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'source'] = this.source_;
      json[r'status'] = this.status;
    if (this.lastSuccessAt.isPresent) {
      final value = this.lastSuccessAt.value;
      json[r'last_success_at'] = value == null ? null : value.toUtc().toIso8601String();
    }
    return json;
  }

  /// Returns a new [SourceStatus] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SourceStatus? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'source'), 'Required key "SourceStatus[source]" is missing from JSON.');
        assert(json[r'source'] != null, 'Required key "SourceStatus[source]" has a null value in JSON.');
        assert(json.containsKey(r'status'), 'Required key "SourceStatus[status]" is missing from JSON.');
        assert(json[r'status'] != null, 'Required key "SourceStatus[status]" has a null value in JSON.');
        return true;
      }());

      return SourceStatus(
        source_: SourceStatusSource_Enum.fromJson(json[r'source'])!,
        status: SourceStatusStatusEnum.fromJson(json[r'status'])!,
        lastSuccessAt: json.containsKey(r'last_success_at') ? Optional.present(mapDateTime(json, r'last_success_at', r'')) : const Optional.absent(),
      );
    }
    return null;
  }

  static List<SourceStatus> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SourceStatus>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SourceStatus.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SourceStatus> mapFromJson(dynamic json) {
    final map = <String, SourceStatus>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SourceStatus.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SourceStatus-objects as value to a dart map
  static Map<String, List<SourceStatus>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SourceStatus>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = SourceStatus.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'source',
    'status',
  };
}


enum SourceStatusSource_Enum {
  jluIedu._(r'jlu_iedu'),
  chaoxing._(r'chaoxing'),
  jluOa._(r'jlu_oa'),
  jluIlearn._(r'jlu_ilearn'),
  ;

  /// Instantiate a new enum with the provided value.
  const SourceStatusSource_Enum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [SourceStatusSource_Enum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static SourceStatusSource_Enum? fromJson(dynamic value) => SourceStatusSource_EnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [SourceStatusSource_Enum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<SourceStatusSource_Enum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SourceStatusSource_Enum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SourceStatusSource_Enum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [SourceStatusSource_Enum] to String,
/// and [decode] dynamic data back to [SourceStatusSource_Enum].
class SourceStatusSource_EnumTypeTransformer {
  factory SourceStatusSource_EnumTypeTransformer() => _instance ??= const SourceStatusSource_EnumTypeTransformer._();

  const SourceStatusSource_EnumTypeTransformer._();

  String encode(SourceStatusSource_Enum data) => data._value;

  /// Returns the instance of [SourceStatusSource_Enum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  SourceStatusSource_Enum? decode(dynamic data, {bool allowNull = true}) {
    if (data is SourceStatusSource_Enum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'jlu_iedu': return SourceStatusSource_Enum.jluIedu;
        case r'chaoxing': return SourceStatusSource_Enum.chaoxing;
        case r'jlu_oa': return SourceStatusSource_Enum.jluOa;
        case r'jlu_ilearn': return SourceStatusSource_Enum.jluIlearn;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static SourceStatusSource_EnumTypeTransformer? _instance;
}



enum SourceStatusStatusEnum {
  connected._(r'connected'),
  authRequired._(r'auth_required'),
  disconnected._(r'disconnected'),
  ;

  /// Instantiate a new enum with the provided value.
  const SourceStatusStatusEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [SourceStatusStatusEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static SourceStatusStatusEnum? fromJson(dynamic value) => SourceStatusStatusEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [SourceStatusStatusEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<SourceStatusStatusEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SourceStatusStatusEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SourceStatusStatusEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [SourceStatusStatusEnum] to String,
/// and [decode] dynamic data back to [SourceStatusStatusEnum].
class SourceStatusStatusEnumTypeTransformer {
  factory SourceStatusStatusEnumTypeTransformer() => _instance ??= const SourceStatusStatusEnumTypeTransformer._();

  const SourceStatusStatusEnumTypeTransformer._();

  String encode(SourceStatusStatusEnum data) => data._value;

  /// Returns the instance of [SourceStatusStatusEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  SourceStatusStatusEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data is SourceStatusStatusEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'connected': return SourceStatusStatusEnum.connected;
        case r'auth_required': return SourceStatusStatusEnum.authRequired;
        case r'disconnected': return SourceStatusStatusEnum.disconnected;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static SourceStatusStatusEnumTypeTransformer? _instance;
}


