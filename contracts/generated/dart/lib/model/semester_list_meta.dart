//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SemesterListMeta {
  /// Returns a new [SemesterListMeta] instance.
  SemesterListMeta({
    required this.requestId,
    required this.nextCursor,
    required this.hasMore,
    required this.currentSemesterId,
    required this.snapshot,
  });

  /// Identifier shared by the response body and the server log entry.
  String requestId;

  /// Opaque cursor bound to the current filters, or null when there are no more items.
  String? nextCursor;

  bool hasMore;

  /// Current semester established by source evidence, or null. It need not be on this page.
  String? currentSemesterId;

  SnapshotMeta snapshot;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SemesterListMeta &&
    other.requestId == requestId &&
    other.nextCursor == nextCursor &&
    other.hasMore == hasMore &&
    other.currentSemesterId == currentSemesterId &&
    other.snapshot == snapshot;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (requestId.hashCode) +
    (nextCursor == null ? 0 : nextCursor!.hashCode) +
    (hasMore.hashCode) +
    (currentSemesterId == null ? 0 : currentSemesterId!.hashCode) +
    (snapshot.hashCode);

  @override
  String toString() => 'SemesterListMeta[requestId=$requestId, nextCursor=$nextCursor, hasMore=$hasMore, currentSemesterId=$currentSemesterId, snapshot=$snapshot]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'request_id'] = this.requestId;
    if (this.nextCursor != null) {
      json[r'next_cursor'] = this.nextCursor;
    } else {
      json[r'next_cursor'] = null;
    }
      json[r'has_more'] = this.hasMore;
    if (this.currentSemesterId != null) {
      json[r'current_semester_id'] = this.currentSemesterId;
    } else {
      json[r'current_semester_id'] = null;
    }
      json[r'snapshot'] = this.snapshot;
    return json;
  }

  /// Returns a new [SemesterListMeta] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SemesterListMeta? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'request_id'), 'Required key "SemesterListMeta[request_id]" is missing from JSON.');
        assert(json[r'request_id'] != null, 'Required key "SemesterListMeta[request_id]" has a null value in JSON.');
        assert(json.containsKey(r'next_cursor'), 'Required key "SemesterListMeta[next_cursor]" is missing from JSON.');
        assert(json.containsKey(r'has_more'), 'Required key "SemesterListMeta[has_more]" is missing from JSON.');
        assert(json[r'has_more'] != null, 'Required key "SemesterListMeta[has_more]" has a null value in JSON.');
        assert(json.containsKey(r'current_semester_id'), 'Required key "SemesterListMeta[current_semester_id]" is missing from JSON.');
        assert(json.containsKey(r'snapshot'), 'Required key "SemesterListMeta[snapshot]" is missing from JSON.');
        assert(json[r'snapshot'] != null, 'Required key "SemesterListMeta[snapshot]" has a null value in JSON.');
        return true;
      }());

      return SemesterListMeta(
        requestId: mapValueOfType<String>(json, r'request_id')!,
        nextCursor: mapValueOfType<String>(json, r'next_cursor'),
        hasMore: mapValueOfType<bool>(json, r'has_more')!,
        currentSemesterId: mapValueOfType<String>(json, r'current_semester_id'),
        snapshot: SnapshotMeta.fromJson(json[r'snapshot'])!,
      );
    }
    return null;
  }

  static List<SemesterListMeta> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SemesterListMeta>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SemesterListMeta.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SemesterListMeta> mapFromJson(dynamic json) {
    final map = <String, SemesterListMeta>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SemesterListMeta.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SemesterListMeta-objects as value to a dart map
  static Map<String, List<SemesterListMeta>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SemesterListMeta>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = SemesterListMeta.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'request_id',
    'next_cursor',
    'has_more',
    'current_semester_id',
    'snapshot',
  };
}

