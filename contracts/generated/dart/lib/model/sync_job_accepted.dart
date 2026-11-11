//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SyncJobAccepted {
  /// Returns a new [SyncJobAccepted] instance.
  SyncJobAccepted({
    required this.id,
    required this.source_,
    required this.resource,
    this.scope = const {},
    required this.status,
    required this.attempts,
    required this.createdAt,
    required this.startedAt,
    required this.finishedAt,
    required this.updatedAt,
    required this.error,
    required this.complete,
    required this.snapshotVersion,
    required this.reused,
  });

  /// Opaque job id. Clients only compare it for equality.
  String id;

  String source_;

  String resource;

  /// Canonical scope echoed from the request.
  Map<String, Object> scope;

  SyncJobStatus status;

  /// Minimum value: 0
  int attempts;

  DateTime createdAt;

  DateTime? startedAt;

  DateTime? finishedAt;

  DateTime updatedAt;

  SyncJobError? error;

  /// Whether the adapter committed a complete snapshot. Null until the job succeeds.
  bool? complete;

  /// Opaque version reported by the adapter. Clients only compare it for equality.
  int? snapshotVersion;

  /// True when an active job already existed for this user, source, resource and scope.
  bool reused;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SyncJobAccepted &&
    other.id == id &&
    other.source_ == source_ &&
    other.resource == resource &&
    _deepEquality.equals(other.scope, scope) &&
    other.status == status &&
    other.attempts == attempts &&
    other.createdAt == createdAt &&
    other.startedAt == startedAt &&
    other.finishedAt == finishedAt &&
    other.updatedAt == updatedAt &&
    other.error == error &&
    other.complete == complete &&
    other.snapshotVersion == snapshotVersion &&
    other.reused == reused;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (source_.hashCode) +
    (resource.hashCode) +
    (scope.hashCode) +
    (status.hashCode) +
    (attempts.hashCode) +
    (createdAt.hashCode) +
    (startedAt == null ? 0 : startedAt!.hashCode) +
    (finishedAt == null ? 0 : finishedAt!.hashCode) +
    (updatedAt.hashCode) +
    (error == null ? 0 : error!.hashCode) +
    (complete == null ? 0 : complete!.hashCode) +
    (snapshotVersion == null ? 0 : snapshotVersion!.hashCode) +
    (reused.hashCode);

  @override
  String toString() => 'SyncJobAccepted[id=$id, source_=$source_, resource=$resource, scope=$scope, status=$status, attempts=$attempts, createdAt=$createdAt, startedAt=$startedAt, finishedAt=$finishedAt, updatedAt=$updatedAt, error=$error, complete=$complete, snapshotVersion=$snapshotVersion, reused=$reused]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'source'] = this.source_;
      json[r'resource'] = this.resource;
      json[r'scope'] = this.scope;
      json[r'status'] = this.status;
      json[r'attempts'] = this.attempts;
      json[r'created_at'] = this.createdAt.toUtc().toIso8601String();
    if (this.startedAt != null) {
      json[r'started_at'] = this.startedAt!.toUtc().toIso8601String();
    } else {
      json[r'started_at'] = null;
    }
    if (this.finishedAt != null) {
      json[r'finished_at'] = this.finishedAt!.toUtc().toIso8601String();
    } else {
      json[r'finished_at'] = null;
    }
      json[r'updated_at'] = this.updatedAt.toUtc().toIso8601String();
    if (this.error != null) {
      json[r'error'] = this.error;
    } else {
      json[r'error'] = null;
    }
    if (this.complete != null) {
      json[r'complete'] = this.complete;
    } else {
      json[r'complete'] = null;
    }
    if (this.snapshotVersion != null) {
      json[r'snapshot_version'] = this.snapshotVersion;
    } else {
      json[r'snapshot_version'] = null;
    }
      json[r'reused'] = this.reused;
    return json;
  }

  /// Returns a new [SyncJobAccepted] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SyncJobAccepted? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'id'), 'Required key "SyncJobAccepted[id]" is missing from JSON.');
        assert(json[r'id'] != null, 'Required key "SyncJobAccepted[id]" has a null value in JSON.');
        assert(json.containsKey(r'source'), 'Required key "SyncJobAccepted[source]" is missing from JSON.');
        assert(json[r'source'] != null, 'Required key "SyncJobAccepted[source]" has a null value in JSON.');
        assert(json.containsKey(r'resource'), 'Required key "SyncJobAccepted[resource]" is missing from JSON.');
        assert(json[r'resource'] != null, 'Required key "SyncJobAccepted[resource]" has a null value in JSON.');
        assert(json.containsKey(r'scope'), 'Required key "SyncJobAccepted[scope]" is missing from JSON.');
        assert(json[r'scope'] != null, 'Required key "SyncJobAccepted[scope]" has a null value in JSON.');
        assert(json.containsKey(r'status'), 'Required key "SyncJobAccepted[status]" is missing from JSON.');
        assert(json[r'status'] != null, 'Required key "SyncJobAccepted[status]" has a null value in JSON.');
        assert(json.containsKey(r'attempts'), 'Required key "SyncJobAccepted[attempts]" is missing from JSON.');
        assert(json[r'attempts'] != null, 'Required key "SyncJobAccepted[attempts]" has a null value in JSON.');
        assert(json.containsKey(r'created_at'), 'Required key "SyncJobAccepted[created_at]" is missing from JSON.');
        assert(json[r'created_at'] != null, 'Required key "SyncJobAccepted[created_at]" has a null value in JSON.');
        assert(json.containsKey(r'started_at'), 'Required key "SyncJobAccepted[started_at]" is missing from JSON.');
        assert(json.containsKey(r'finished_at'), 'Required key "SyncJobAccepted[finished_at]" is missing from JSON.');
        assert(json.containsKey(r'updated_at'), 'Required key "SyncJobAccepted[updated_at]" is missing from JSON.');
        assert(json[r'updated_at'] != null, 'Required key "SyncJobAccepted[updated_at]" has a null value in JSON.');
        assert(json.containsKey(r'error'), 'Required key "SyncJobAccepted[error]" is missing from JSON.');
        assert(json.containsKey(r'complete'), 'Required key "SyncJobAccepted[complete]" is missing from JSON.');
        assert(json.containsKey(r'snapshot_version'), 'Required key "SyncJobAccepted[snapshot_version]" is missing from JSON.');
        assert(json.containsKey(r'reused'), 'Required key "SyncJobAccepted[reused]" is missing from JSON.');
        assert(json[r'reused'] != null, 'Required key "SyncJobAccepted[reused]" has a null value in JSON.');
        return true;
      }());

      return SyncJobAccepted(
        id: mapValueOfType<String>(json, r'id')!,
        source_: mapValueOfType<String>(json, r'source')!,
        resource: mapValueOfType<String>(json, r'resource')!,
        scope: mapCastOfType<String, Object>(json, r'scope')!,
        status: SyncJobStatus.fromJson(json[r'status'])!,
        attempts: mapValueOfType<int>(json, r'attempts')!,
        createdAt: mapDateTime(json, r'created_at', r'')!,
        startedAt: mapDateTime(json, r'started_at', r''),
        finishedAt: mapDateTime(json, r'finished_at', r''),
        updatedAt: mapDateTime(json, r'updated_at', r'')!,
        error: SyncJobError.fromJson(json[r'error']),
        complete: mapValueOfType<bool>(json, r'complete'),
        snapshotVersion: mapValueOfType<int>(json, r'snapshot_version'),
        reused: mapValueOfType<bool>(json, r'reused')!,
      );
    }
    return null;
  }

  static List<SyncJobAccepted> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SyncJobAccepted>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SyncJobAccepted.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SyncJobAccepted> mapFromJson(dynamic json) {
    final map = <String, SyncJobAccepted>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SyncJobAccepted.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SyncJobAccepted-objects as value to a dart map
  static Map<String, List<SyncJobAccepted>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SyncJobAccepted>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = SyncJobAccepted.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'source',
    'resource',
    'scope',
    'status',
    'attempts',
    'created_at',
    'started_at',
    'finished_at',
    'updated_at',
    'error',
    'complete',
    'snapshot_version',
    'reused',
  };
}

