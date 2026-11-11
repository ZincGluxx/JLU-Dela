//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class LiveStatus {
  /// Returns a new [LiveStatus] instance.
  LiveStatus({
    required this.status,
  });

  LiveStatusStatusEnum status;

  @override
  bool operator ==(Object other) => identical(this, other) || other is LiveStatus &&
    other.status == status;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (status.hashCode);

  @override
  String toString() => 'LiveStatus[status=$status]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'status'] = this.status;
    return json;
  }

  /// Returns a new [LiveStatus] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static LiveStatus? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'status'), 'Required key "LiveStatus[status]" is missing from JSON.');
        assert(json[r'status'] != null, 'Required key "LiveStatus[status]" has a null value in JSON.');
        return true;
      }());

      return LiveStatus(
        status: LiveStatusStatusEnum.fromJson(json[r'status'])!,
      );
    }
    return null;
  }

  static List<LiveStatus> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <LiveStatus>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = LiveStatus.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, LiveStatus> mapFromJson(dynamic json) {
    final map = <String, LiveStatus>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = LiveStatus.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of LiveStatus-objects as value to a dart map
  static Map<String, List<LiveStatus>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<LiveStatus>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = LiveStatus.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'status',
  };
}


enum LiveStatusStatusEnum {
  ok._(r'ok'),
  ;

  /// Instantiate a new enum with the provided value.
  const LiveStatusStatusEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [LiveStatusStatusEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static LiveStatusStatusEnum? fromJson(dynamic value) => LiveStatusStatusEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [LiveStatusStatusEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<LiveStatusStatusEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <LiveStatusStatusEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = LiveStatusStatusEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [LiveStatusStatusEnum] to String,
/// and [decode] dynamic data back to [LiveStatusStatusEnum].
class LiveStatusStatusEnumTypeTransformer {
  factory LiveStatusStatusEnumTypeTransformer() => _instance ??= const LiveStatusStatusEnumTypeTransformer._();

  const LiveStatusStatusEnumTypeTransformer._();

  String encode(LiveStatusStatusEnum data) => data._value;

  /// Returns the instance of [LiveStatusStatusEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  LiveStatusStatusEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data is LiveStatusStatusEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'ok': return LiveStatusStatusEnum.ok;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static LiveStatusStatusEnumTypeTransformer? _instance;
}


