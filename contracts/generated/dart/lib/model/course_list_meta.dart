//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class CourseListMeta {
  /// Returns a new [CourseListMeta] instance.
  CourseListMeta({
    required this.requestId,
    required this.nextCursor,
    required this.hasMore,
    this.sourceSnapshots = const [],
  });

  /// Identifier shared by the response body and the server log entry.
  String requestId;

  /// Opaque cursor bound to the current filters, or null when there are no more items.
  String? nextCursor;

  bool hasMore;

  /// Draft per-source states pending A/C/E review; exactly the filtered source, otherwise jlu_iedu then chaoxing, with no duplicates.
  List<SourceSnapshot> sourceSnapshots;

  @override
  bool operator ==(Object other) => identical(this, other) || other is CourseListMeta &&
    other.requestId == requestId &&
    other.nextCursor == nextCursor &&
    other.hasMore == hasMore &&
    _deepEquality.equals(other.sourceSnapshots, sourceSnapshots);

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (requestId.hashCode) +
    (nextCursor == null ? 0 : nextCursor!.hashCode) +
    (hasMore.hashCode) +
    (sourceSnapshots.hashCode);

  @override
  String toString() => 'CourseListMeta[requestId=$requestId, nextCursor=$nextCursor, hasMore=$hasMore, sourceSnapshots=$sourceSnapshots]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'request_id'] = this.requestId;
    if (this.nextCursor != null) {
      json[r'next_cursor'] = this.nextCursor;
    } else {
      json[r'next_cursor'] = null;
    }
      json[r'has_more'] = this.hasMore;
      json[r'source_snapshots'] = this.sourceSnapshots;
    return json;
  }

  /// Returns a new [CourseListMeta] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static CourseListMeta? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'request_id'), 'Required key "CourseListMeta[request_id]" is missing from JSON.');
        assert(json[r'request_id'] != null, 'Required key "CourseListMeta[request_id]" has a null value in JSON.');
        assert(json.containsKey(r'next_cursor'), 'Required key "CourseListMeta[next_cursor]" is missing from JSON.');
        assert(json.containsKey(r'has_more'), 'Required key "CourseListMeta[has_more]" is missing from JSON.');
        assert(json[r'has_more'] != null, 'Required key "CourseListMeta[has_more]" has a null value in JSON.');
        assert(json.containsKey(r'source_snapshots'), 'Required key "CourseListMeta[source_snapshots]" is missing from JSON.');
        assert(json[r'source_snapshots'] != null, 'Required key "CourseListMeta[source_snapshots]" has a null value in JSON.');
        return true;
      }());

      return CourseListMeta(
        requestId: mapValueOfType<String>(json, r'request_id')!,
        nextCursor: mapValueOfType<String>(json, r'next_cursor'),
        hasMore: mapValueOfType<bool>(json, r'has_more')!,
        sourceSnapshots: SourceSnapshot.listFromJson(json[r'source_snapshots']),
      );
    }
    return null;
  }

  static List<CourseListMeta> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <CourseListMeta>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CourseListMeta.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, CourseListMeta> mapFromJson(dynamic json) {
    final map = <String, CourseListMeta>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = CourseListMeta.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of CourseListMeta-objects as value to a dart map
  static Map<String, List<CourseListMeta>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<CourseListMeta>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = CourseListMeta.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'request_id',
    'next_cursor',
    'has_more',
    'source_snapshots',
  };
}

