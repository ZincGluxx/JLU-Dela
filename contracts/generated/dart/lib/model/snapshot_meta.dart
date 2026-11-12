//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SnapshotMeta {
  /// Returns a new [SnapshotMeta] instance.
  SnapshotMeta({
    required this.status,
    required this.lastSuccessAt,
    required this.lastAttemptAt,
    required this.observedAt,
    required this.lastErrorCode,
    this.coverage = const {},
  });

  SnapshotMetaStatusEnum status;

  /// Server time when a complete snapshot for this scope was successfully saved, or null if none.
  DateTime? lastSuccessAt;

  DateTime? lastAttemptAt;

  /// Source content observation time, distinct from server save time.
  DateTime? observedAt;

  /// SOURCE_AUTH_REQUIRED, SOURCE_NETWORK_ERROR, SOURCE_TIMEOUT, SOURCE_PROTOCOL_ERROR or another stable code; network and protocol errors do not imply lost authorization.
  String? lastErrorCode;

  /// Draft source scope, pending A and consumer review. Semesters use an empty object for the user's source-wide semester list. Courses use an empty object or semester_id for a semester filter. Schedule uses semester_id, from and to (campus dates matching the query). Pagination and retained are result filters, not collection scopes. 
  Map<String, Object> coverage;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SnapshotMeta &&
    other.status == status &&
    other.lastSuccessAt == lastSuccessAt &&
    other.lastAttemptAt == lastAttemptAt &&
    other.observedAt == observedAt &&
    other.lastErrorCode == lastErrorCode &&
    _deepEquality.equals(other.coverage, coverage);

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (status.hashCode) +
    (lastSuccessAt == null ? 0 : lastSuccessAt!.hashCode) +
    (lastAttemptAt == null ? 0 : lastAttemptAt!.hashCode) +
    (observedAt == null ? 0 : observedAt!.hashCode) +
    (lastErrorCode == null ? 0 : lastErrorCode!.hashCode) +
    (coverage.hashCode);

  @override
  String toString() => 'SnapshotMeta[status=$status, lastSuccessAt=$lastSuccessAt, lastAttemptAt=$lastAttemptAt, observedAt=$observedAt, lastErrorCode=$lastErrorCode, coverage=$coverage]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'status'] = this.status;
    if (this.lastSuccessAt != null) {
      json[r'last_success_at'] = _isEpochMarker(r'/Z$/')
        ? this.lastSuccessAt!.millisecondsSinceEpoch
        : this.lastSuccessAt!.toUtc().toIso8601String();
    } else {
      json[r'last_success_at'] = null;
    }
    if (this.lastAttemptAt != null) {
      json[r'last_attempt_at'] = _isEpochMarker(r'/Z$/')
        ? this.lastAttemptAt!.millisecondsSinceEpoch
        : this.lastAttemptAt!.toUtc().toIso8601String();
    } else {
      json[r'last_attempt_at'] = null;
    }
    if (this.observedAt != null) {
      json[r'observed_at'] = _isEpochMarker(r'/Z$/')
        ? this.observedAt!.millisecondsSinceEpoch
        : this.observedAt!.toUtc().toIso8601String();
    } else {
      json[r'observed_at'] = null;
    }
    if (this.lastErrorCode != null) {
      json[r'last_error_code'] = this.lastErrorCode;
    } else {
      json[r'last_error_code'] = null;
    }
      json[r'coverage'] = this.coverage;
    return json;
  }

  /// Returns a new [SnapshotMeta] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SnapshotMeta? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'status'), 'Required key "SnapshotMeta[status]" is missing from JSON.');
        assert(json[r'status'] != null, 'Required key "SnapshotMeta[status]" has a null value in JSON.');
        assert(json.containsKey(r'last_success_at'), 'Required key "SnapshotMeta[last_success_at]" is missing from JSON.');
        assert(json.containsKey(r'last_attempt_at'), 'Required key "SnapshotMeta[last_attempt_at]" is missing from JSON.');
        assert(json.containsKey(r'observed_at'), 'Required key "SnapshotMeta[observed_at]" is missing from JSON.');
        assert(json.containsKey(r'last_error_code'), 'Required key "SnapshotMeta[last_error_code]" is missing from JSON.');
        assert(json.containsKey(r'coverage'), 'Required key "SnapshotMeta[coverage]" is missing from JSON.');
        assert(json[r'coverage'] != null, 'Required key "SnapshotMeta[coverage]" has a null value in JSON.');
        return true;
      }());

      return SnapshotMeta(
        status: SnapshotMetaStatusEnum.fromJson(json[r'status'])!,
        lastSuccessAt: mapDateTime(json, r'last_success_at', r'/Z$/'),
        lastAttemptAt: mapDateTime(json, r'last_attempt_at', r'/Z$/'),
        observedAt: mapDateTime(json, r'observed_at', r'/Z$/'),
        lastErrorCode: mapValueOfType<String>(json, r'last_error_code'),
        coverage: mapCastOfType<String, Object>(json, r'coverage')!,
      );
    }
    return null;
  }

  static List<SnapshotMeta> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SnapshotMeta>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SnapshotMeta.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SnapshotMeta> mapFromJson(dynamic json) {
    final map = <String, SnapshotMeta>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SnapshotMeta.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SnapshotMeta-objects as value to a dart map
  static Map<String, List<SnapshotMeta>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SnapshotMeta>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = SnapshotMeta.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'status',
    'last_success_at',
    'last_attempt_at',
    'observed_at',
    'last_error_code',
    'coverage',
  };
}


enum SnapshotMetaStatusEnum {
  neverSynced._(r'never_synced'),
  current._(r'current'),
  stale._(r'stale'),
  ;

  /// Instantiate a new enum with the provided value.
  const SnapshotMetaStatusEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [SnapshotMetaStatusEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static SnapshotMetaStatusEnum? fromJson(dynamic value) => SnapshotMetaStatusEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [SnapshotMetaStatusEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<SnapshotMetaStatusEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SnapshotMetaStatusEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SnapshotMetaStatusEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [SnapshotMetaStatusEnum] to String,
/// and [decode] dynamic data back to [SnapshotMetaStatusEnum].
class SnapshotMetaStatusEnumTypeTransformer {
  factory SnapshotMetaStatusEnumTypeTransformer() => _instance ??= const SnapshotMetaStatusEnumTypeTransformer._();

  const SnapshotMetaStatusEnumTypeTransformer._();

  String encode(SnapshotMetaStatusEnum data) => data._value;

  /// Returns the instance of [SnapshotMetaStatusEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  SnapshotMetaStatusEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data is SnapshotMetaStatusEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'never_synced': return SnapshotMetaStatusEnum.neverSynced;
        case r'current': return SnapshotMetaStatusEnum.current;
        case r'stale': return SnapshotMetaStatusEnum.stale;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static SnapshotMetaStatusEnumTypeTransformer? _instance;
}


