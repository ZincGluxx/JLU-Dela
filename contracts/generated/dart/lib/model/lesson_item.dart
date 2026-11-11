//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class LessonItem {
  /// Returns a new [LessonItem] instance.
  LessonItem({
    required this.kind,
    required this.id,
    required this.lessonId,
    required this.courseOfferingId,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    this.location = const Optional.absent(),
    this.periodStart = const Optional.absent(),
    this.periodEnd = const Optional.absent(),
  });

  LessonItemKindEnum kind;

  /// `lesson:<lesson_id>:<starts_at>`, unique per occurrence of a course.
  String id;

  String lessonId;

  String courseOfferingId;

  String title;

  DateTime startsAt;

  DateTime endsAt;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  Optional<String?> location;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  Optional<int?> periodStart;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  Optional<int?> periodEnd;

  @override
  bool operator ==(Object other) => identical(this, other) || other is LessonItem &&
    other.kind == kind &&
    other.id == id &&
    other.lessonId == lessonId &&
    other.courseOfferingId == courseOfferingId &&
    other.title == title &&
    other.startsAt == startsAt &&
    other.endsAt == endsAt &&
    other.location == location &&
    other.periodStart == periodStart &&
    other.periodEnd == periodEnd;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (kind.hashCode) +
    (id.hashCode) +
    (lessonId.hashCode) +
    (courseOfferingId.hashCode) +
    (title.hashCode) +
    (startsAt.hashCode) +
    (endsAt.hashCode) +
    (location == null ? 0 : location!.hashCode) +
    (periodStart == null ? 0 : periodStart!.hashCode) +
    (periodEnd == null ? 0 : periodEnd!.hashCode);

  @override
  String toString() => 'LessonItem[kind=$kind, id=$id, lessonId=$lessonId, courseOfferingId=$courseOfferingId, title=$title, startsAt=$startsAt, endsAt=$endsAt, location=$location, periodStart=$periodStart, periodEnd=$periodEnd]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'kind'] = this.kind;
      json[r'id'] = this.id;
      json[r'lesson_id'] = this.lessonId;
      json[r'course_offering_id'] = this.courseOfferingId;
      json[r'title'] = this.title;
      json[r'starts_at'] = this.startsAt.toUtc().toIso8601String();
      json[r'ends_at'] = this.endsAt.toUtc().toIso8601String();
    if (this.location.isPresent) {
      final value = this.location.value;
      json[r'location'] = value;
    }
    if (this.periodStart.isPresent) {
      final value = this.periodStart.value;
      json[r'period_start'] = value;
    }
    if (this.periodEnd.isPresent) {
      final value = this.periodEnd.value;
      json[r'period_end'] = value;
    }
    return json;
  }

  /// Returns a new [LessonItem] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static LessonItem? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'kind'), 'Required key "LessonItem[kind]" is missing from JSON.');
        assert(json[r'kind'] != null, 'Required key "LessonItem[kind]" has a null value in JSON.');
        assert(json.containsKey(r'id'), 'Required key "LessonItem[id]" is missing from JSON.');
        assert(json[r'id'] != null, 'Required key "LessonItem[id]" has a null value in JSON.');
        assert(json.containsKey(r'lesson_id'), 'Required key "LessonItem[lesson_id]" is missing from JSON.');
        assert(json[r'lesson_id'] != null, 'Required key "LessonItem[lesson_id]" has a null value in JSON.');
        assert(json.containsKey(r'course_offering_id'), 'Required key "LessonItem[course_offering_id]" is missing from JSON.');
        assert(json[r'course_offering_id'] != null, 'Required key "LessonItem[course_offering_id]" has a null value in JSON.');
        assert(json.containsKey(r'title'), 'Required key "LessonItem[title]" is missing from JSON.');
        assert(json[r'title'] != null, 'Required key "LessonItem[title]" has a null value in JSON.');
        assert(json.containsKey(r'starts_at'), 'Required key "LessonItem[starts_at]" is missing from JSON.');
        assert(json[r'starts_at'] != null, 'Required key "LessonItem[starts_at]" has a null value in JSON.');
        assert(json.containsKey(r'ends_at'), 'Required key "LessonItem[ends_at]" is missing from JSON.');
        assert(json[r'ends_at'] != null, 'Required key "LessonItem[ends_at]" has a null value in JSON.');
        return true;
      }());

      return LessonItem(
        kind: LessonItemKindEnum.fromJson(json[r'kind'])!,
        id: mapValueOfType<String>(json, r'id')!,
        lessonId: mapValueOfType<String>(json, r'lesson_id')!,
        courseOfferingId: mapValueOfType<String>(json, r'course_offering_id')!,
        title: mapValueOfType<String>(json, r'title')!,
        startsAt: mapDateTime(json, r'starts_at', r'')!,
        endsAt: mapDateTime(json, r'ends_at', r'')!,
        location: json.containsKey(r'location') ? Optional.present(mapValueOfType<String>(json, r'location')) : const Optional.absent(),
        periodStart: json.containsKey(r'period_start') ? Optional.present(json[r'period_start'] == null ? null : int.parse('${json[r'period_start']}')) : const Optional.absent(),
        periodEnd: json.containsKey(r'period_end') ? Optional.present(json[r'period_end'] == null ? null : int.parse('${json[r'period_end']}')) : const Optional.absent(),
      );
    }
    return null;
  }

  static List<LessonItem> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <LessonItem>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = LessonItem.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, LessonItem> mapFromJson(dynamic json) {
    final map = <String, LessonItem>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = LessonItem.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of LessonItem-objects as value to a dart map
  static Map<String, List<LessonItem>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<LessonItem>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = LessonItem.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'kind',
    'id',
    'lesson_id',
    'course_offering_id',
    'title',
    'starts_at',
    'ends_at',
  };
}


enum LessonItemKindEnum {
  lesson._(r'lesson'),
  ;

  /// Instantiate a new enum with the provided value.
  const LessonItemKindEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [LessonItemKindEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static LessonItemKindEnum? fromJson(dynamic value) => LessonItemKindEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [LessonItemKindEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<LessonItemKindEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <LessonItemKindEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = LessonItemKindEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [LessonItemKindEnum] to String,
/// and [decode] dynamic data back to [LessonItemKindEnum].
class LessonItemKindEnumTypeTransformer {
  factory LessonItemKindEnumTypeTransformer() => _instance ??= const LessonItemKindEnumTypeTransformer._();

  const LessonItemKindEnumTypeTransformer._();

  String encode(LessonItemKindEnum data) => data._value;

  /// Returns the instance of [LessonItemKindEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  LessonItemKindEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data is LessonItemKindEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'lesson': return LessonItemKindEnum.lesson;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static LessonItemKindEnumTypeTransformer? _instance;
}


