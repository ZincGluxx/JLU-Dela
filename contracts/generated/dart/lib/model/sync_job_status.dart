//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


enum SyncJobStatus {
  queued._(r'queued'),
  running._(r'running'),
  succeeded._(r'succeeded'),
  failed._(r'failed'),
  ;

  /// Instantiate a new enum with the provided value.
  const SyncJobStatus._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [SyncJobStatus] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static SyncJobStatus? fromJson(dynamic value) => SyncJobStatusTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [SyncJobStatus]
  /// that were successfully decoded from the passed [JSON][json].
  static List<SyncJobStatus> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SyncJobStatus>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SyncJobStatus.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [SyncJobStatus] to String,
/// and [decode] dynamic data back to [SyncJobStatus].
class SyncJobStatusTypeTransformer {
  factory SyncJobStatusTypeTransformer() => _instance ??= const SyncJobStatusTypeTransformer._();

  const SyncJobStatusTypeTransformer._();

  /// Encodes this enum as a value suitable for JSON.
  String encode(SyncJobStatus data) => data._value;

  /// Returns the instance of [SyncJobStatus] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  SyncJobStatus? decode(dynamic data, {bool allowNull = true}) {
    if (data is SyncJobStatus) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'queued': return SyncJobStatus.queued;
        case r'running': return SyncJobStatus.running;
        case r'succeeded': return SyncJobStatus.succeeded;
        case r'failed': return SyncJobStatus.failed;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static SyncJobStatusTypeTransformer? _instance;
}

