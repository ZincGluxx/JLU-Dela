//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class BackupNote {
  /// Returns a new [BackupNote] instance.
  BackupNote({
    required this.id,
    required this.title,
    required this.body,
    required this.courseOfferingId,
    required this.lessonId,
    required this.replaySource,
    required this.replayId,
    required this.replayTitle,
    required this.positionMs,
    required this.createdAt,
    required this.updatedAt,
  });

  String id;

  String title;

  String body;

  /// Preserved local course reference; restore does not fabricate source courses.
  String? courseOfferingId;

  String? lessonId;

  String? replaySource;

  String? replayId;

  String? replayTitle;

  /// Minimum value: 0
  int? positionMs;

  DateTime createdAt;

  DateTime updatedAt;

  @override
  bool operator ==(Object other) => identical(this, other) || other is BackupNote &&
    other.id == id &&
    other.title == title &&
    other.body == body &&
    other.courseOfferingId == courseOfferingId &&
    other.lessonId == lessonId &&
    other.replaySource == replaySource &&
    other.replayId == replayId &&
    other.replayTitle == replayTitle &&
    other.positionMs == positionMs &&
    other.createdAt == createdAt &&
    other.updatedAt == updatedAt;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (title.hashCode) +
    (body.hashCode) +
    (courseOfferingId == null ? 0 : courseOfferingId!.hashCode) +
    (lessonId == null ? 0 : lessonId!.hashCode) +
    (replaySource == null ? 0 : replaySource!.hashCode) +
    (replayId == null ? 0 : replayId!.hashCode) +
    (replayTitle == null ? 0 : replayTitle!.hashCode) +
    (positionMs == null ? 0 : positionMs!.hashCode) +
    (createdAt.hashCode) +
    (updatedAt.hashCode);

  @override
  String toString() => 'BackupNote[id=$id, title=$title, body=$body, courseOfferingId=$courseOfferingId, lessonId=$lessonId, replaySource=$replaySource, replayId=$replayId, replayTitle=$replayTitle, positionMs=$positionMs, createdAt=$createdAt, updatedAt=$updatedAt]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'title'] = this.title;
      json[r'body'] = this.body;
    if (this.courseOfferingId != null) {
      json[r'course_offering_id'] = this.courseOfferingId;
    } else {
      json[r'course_offering_id'] = null;
    }
    if (this.lessonId != null) {
      json[r'lesson_id'] = this.lessonId;
    } else {
      json[r'lesson_id'] = null;
    }
    if (this.replaySource != null) {
      json[r'replay_source'] = this.replaySource;
    } else {
      json[r'replay_source'] = null;
    }
    if (this.replayId != null) {
      json[r'replay_id'] = this.replayId;
    } else {
      json[r'replay_id'] = null;
    }
    if (this.replayTitle != null) {
      json[r'replay_title'] = this.replayTitle;
    } else {
      json[r'replay_title'] = null;
    }
    if (this.positionMs != null) {
      json[r'position_ms'] = this.positionMs;
    } else {
      json[r'position_ms'] = null;
    }
      json[r'created_at'] = this.createdAt.toUtc().toIso8601String();
      json[r'updated_at'] = this.updatedAt.toUtc().toIso8601String();
    return json;
  }

  /// Returns a new [BackupNote] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static BackupNote? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'id'), 'Required key "BackupNote[id]" is missing from JSON.');
        assert(json[r'id'] != null, 'Required key "BackupNote[id]" has a null value in JSON.');
        assert(json.containsKey(r'title'), 'Required key "BackupNote[title]" is missing from JSON.');
        assert(json[r'title'] != null, 'Required key "BackupNote[title]" has a null value in JSON.');
        assert(json.containsKey(r'body'), 'Required key "BackupNote[body]" is missing from JSON.');
        assert(json[r'body'] != null, 'Required key "BackupNote[body]" has a null value in JSON.');
        assert(json.containsKey(r'course_offering_id'), 'Required key "BackupNote[course_offering_id]" is missing from JSON.');
        assert(json.containsKey(r'lesson_id'), 'Required key "BackupNote[lesson_id]" is missing from JSON.');
        assert(json.containsKey(r'replay_source'), 'Required key "BackupNote[replay_source]" is missing from JSON.');
        assert(json.containsKey(r'replay_id'), 'Required key "BackupNote[replay_id]" is missing from JSON.');
        assert(json.containsKey(r'replay_title'), 'Required key "BackupNote[replay_title]" is missing from JSON.');
        assert(json.containsKey(r'position_ms'), 'Required key "BackupNote[position_ms]" is missing from JSON.');
        assert(json.containsKey(r'created_at'), 'Required key "BackupNote[created_at]" is missing from JSON.');
        assert(json[r'created_at'] != null, 'Required key "BackupNote[created_at]" has a null value in JSON.');
        assert(json.containsKey(r'updated_at'), 'Required key "BackupNote[updated_at]" is missing from JSON.');
        assert(json[r'updated_at'] != null, 'Required key "BackupNote[updated_at]" has a null value in JSON.');
        return true;
      }());

      return BackupNote(
        id: mapValueOfType<String>(json, r'id')!,
        title: mapValueOfType<String>(json, r'title')!,
        body: mapValueOfType<String>(json, r'body')!,
        courseOfferingId: mapValueOfType<String>(json, r'course_offering_id'),
        lessonId: mapValueOfType<String>(json, r'lesson_id'),
        replaySource: mapValueOfType<String>(json, r'replay_source'),
        replayId: mapValueOfType<String>(json, r'replay_id'),
        replayTitle: mapValueOfType<String>(json, r'replay_title'),
        positionMs: mapValueOfType<int>(json, r'position_ms'),
        createdAt: mapDateTime(json, r'created_at', r'')!,
        updatedAt: mapDateTime(json, r'updated_at', r'')!,
      );
    }
    return null;
  }

  static List<BackupNote> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <BackupNote>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = BackupNote.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, BackupNote> mapFromJson(dynamic json) {
    final map = <String, BackupNote>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = BackupNote.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of BackupNote-objects as value to a dart map
  static Map<String, List<BackupNote>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<BackupNote>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = BackupNote.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'title',
    'body',
    'course_offering_id',
    'lesson_id',
    'replay_source',
    'replay_id',
    'replay_title',
    'position_ms',
    'created_at',
    'updated_at',
  };
}

