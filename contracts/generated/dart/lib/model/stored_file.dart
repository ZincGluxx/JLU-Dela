//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class StoredFile {
  /// Returns a new [StoredFile] instance.
  StoredFile({
    required this.id,
    required this.uploaderId,
    required this.originalName,
    required this.sizeBytes,
    required this.mediaType,
    required this.createdAt,
  });

  String id;

  String uploaderId;

  /// Original filename; at most 255 Unicode scalars, without control characters.
  String originalName;

  /// Minimum value: 1
  int sizeBytes;

  String mediaType;

  /// UTC RFC 3339 timestamp with a Z suffix.
  DateTime createdAt;

  @override
  bool operator ==(Object other) => identical(this, other) || other is StoredFile &&
    other.id == id &&
    other.uploaderId == uploaderId &&
    other.originalName == originalName &&
    other.sizeBytes == sizeBytes &&
    other.mediaType == mediaType &&
    other.createdAt == createdAt;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (uploaderId.hashCode) +
    (originalName.hashCode) +
    (sizeBytes.hashCode) +
    (mediaType.hashCode) +
    (createdAt.hashCode);

  @override
  String toString() => 'StoredFile[id=$id, uploaderId=$uploaderId, originalName=$originalName, sizeBytes=$sizeBytes, mediaType=$mediaType, createdAt=$createdAt]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'uploader_id'] = this.uploaderId;
      json[r'original_name'] = this.originalName;
      json[r'size_bytes'] = this.sizeBytes;
      json[r'media_type'] = this.mediaType;
      json[r'created_at'] = _isEpochMarker(r'/Z$/')
        ? this.createdAt.millisecondsSinceEpoch
        : this.createdAt.toUtc().toIso8601String();
    return json;
  }

  /// Returns a new [StoredFile] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static StoredFile? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'id'), 'Required key "StoredFile[id]" is missing from JSON.');
        assert(json[r'id'] != null, 'Required key "StoredFile[id]" has a null value in JSON.');
        assert(json.containsKey(r'uploader_id'), 'Required key "StoredFile[uploader_id]" is missing from JSON.');
        assert(json[r'uploader_id'] != null, 'Required key "StoredFile[uploader_id]" has a null value in JSON.');
        assert(json.containsKey(r'original_name'), 'Required key "StoredFile[original_name]" is missing from JSON.');
        assert(json[r'original_name'] != null, 'Required key "StoredFile[original_name]" has a null value in JSON.');
        assert(json.containsKey(r'size_bytes'), 'Required key "StoredFile[size_bytes]" is missing from JSON.');
        assert(json[r'size_bytes'] != null, 'Required key "StoredFile[size_bytes]" has a null value in JSON.');
        assert(json.containsKey(r'media_type'), 'Required key "StoredFile[media_type]" is missing from JSON.');
        assert(json[r'media_type'] != null, 'Required key "StoredFile[media_type]" has a null value in JSON.');
        assert(json.containsKey(r'created_at'), 'Required key "StoredFile[created_at]" is missing from JSON.');
        assert(json[r'created_at'] != null, 'Required key "StoredFile[created_at]" has a null value in JSON.');
        return true;
      }());

      return StoredFile(
        id: mapValueOfType<String>(json, r'id')!,
        uploaderId: mapValueOfType<String>(json, r'uploader_id')!,
        originalName: mapValueOfType<String>(json, r'original_name')!,
        sizeBytes: mapValueOfType<int>(json, r'size_bytes')!,
        mediaType: mapValueOfType<String>(json, r'media_type')!,
        createdAt: mapDateTime(json, r'created_at', r'/Z$/')!,
      );
    }
    return null;
  }

  static List<StoredFile> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <StoredFile>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = StoredFile.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, StoredFile> mapFromJson(dynamic json) {
    final map = <String, StoredFile>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = StoredFile.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of StoredFile-objects as value to a dart map
  static Map<String, List<StoredFile>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<StoredFile>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = StoredFile.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'uploader_id',
    'original_name',
    'size_bytes',
    'media_type',
    'created_at',
  };
}

