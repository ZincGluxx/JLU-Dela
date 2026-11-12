//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SourceSnapshot {
  /// Returns a new [SourceSnapshot] instance.
  SourceSnapshot({
    required this.source_,
    required this.snapshot,
  });

  TeachingSource source_;

  SnapshotMeta snapshot;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SourceSnapshot &&
    other.source_ == source_ &&
    other.snapshot == snapshot;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (source_.hashCode) +
    (snapshot.hashCode);

  @override
  String toString() => 'SourceSnapshot[source_=$source_, snapshot=$snapshot]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'source'] = this.source_;
      json[r'snapshot'] = this.snapshot;
    return json;
  }

  /// Returns a new [SourceSnapshot] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SourceSnapshot? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'source'), 'Required key "SourceSnapshot[source]" is missing from JSON.');
        assert(json[r'source'] != null, 'Required key "SourceSnapshot[source]" has a null value in JSON.');
        assert(json.containsKey(r'snapshot'), 'Required key "SourceSnapshot[snapshot]" is missing from JSON.');
        assert(json[r'snapshot'] != null, 'Required key "SourceSnapshot[snapshot]" has a null value in JSON.');
        return true;
      }());

      return SourceSnapshot(
        source_: TeachingSource.fromJson(json[r'source'])!,
        snapshot: SnapshotMeta.fromJson(json[r'snapshot'])!,
      );
    }
    return null;
  }

  static List<SourceSnapshot> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SourceSnapshot>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SourceSnapshot.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SourceSnapshot> mapFromJson(dynamic json) {
    final map = <String, SourceSnapshot>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SourceSnapshot.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SourceSnapshot-objects as value to a dart map
  static Map<String, List<SourceSnapshot>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SourceSnapshot>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = SourceSnapshot.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'source',
    'snapshot',
  };
}

