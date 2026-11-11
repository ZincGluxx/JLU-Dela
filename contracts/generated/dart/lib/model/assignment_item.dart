//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AssignmentItem {
  /// Returns a new [AssignmentItem] instance.
  AssignmentItem({
    required this.kind,
    required this.id,
    required this.assignmentId,
    this.courseOfferingId = const Optional.absent(),
    required this.title,
    this.dueAt = const Optional.absent(),
    required this.dueKind,
    this.timingText = const Optional.absent(),
    this.sourceStatus = const Optional.absent(),
    this.readAt = const Optional.absent(),
    this.mutedAt = const Optional.absent(),
  });

  AssignmentItemKindEnum kind;

  /// `assignment:<assignment_id>`
  String id;

  String assignmentId;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  Optional<String?> courseOfferingId;

  String title;

  /// May be set only when `due_kind` is `exact` or `date_only`.
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  Optional<DateTime?> dueAt;

  AssignmentItemDueKindEnum dueKind;

  /// Source wording such as \"3 days left\". Kept verbatim; never converted into a timestamp.
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  Optional<String?> timingText;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  Optional<String?> sourceStatus;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  Optional<DateTime?> readAt;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  Optional<DateTime?> mutedAt;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AssignmentItem &&
    other.kind == kind &&
    other.id == id &&
    other.assignmentId == assignmentId &&
    other.courseOfferingId == courseOfferingId &&
    other.title == title &&
    other.dueAt == dueAt &&
    other.dueKind == dueKind &&
    other.timingText == timingText &&
    other.sourceStatus == sourceStatus &&
    other.readAt == readAt &&
    other.mutedAt == mutedAt;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (kind.hashCode) +
    (id.hashCode) +
    (assignmentId.hashCode) +
    (courseOfferingId == null ? 0 : courseOfferingId!.hashCode) +
    (title.hashCode) +
    (dueAt == null ? 0 : dueAt!.hashCode) +
    (dueKind.hashCode) +
    (timingText == null ? 0 : timingText!.hashCode) +
    (sourceStatus == null ? 0 : sourceStatus!.hashCode) +
    (readAt == null ? 0 : readAt!.hashCode) +
    (mutedAt == null ? 0 : mutedAt!.hashCode);

  @override
  String toString() => 'AssignmentItem[kind=$kind, id=$id, assignmentId=$assignmentId, courseOfferingId=$courseOfferingId, title=$title, dueAt=$dueAt, dueKind=$dueKind, timingText=$timingText, sourceStatus=$sourceStatus, readAt=$readAt, mutedAt=$mutedAt]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'kind'] = this.kind;
      json[r'id'] = this.id;
      json[r'assignment_id'] = this.assignmentId;
    if (this.courseOfferingId.isPresent) {
      final value = this.courseOfferingId.value;
      json[r'course_offering_id'] = value;
    }
      json[r'title'] = this.title;
    if (this.dueAt.isPresent) {
      final value = this.dueAt.value;
      json[r'due_at'] = value == null ? null : value.toUtc().toIso8601String();
    }
      json[r'due_kind'] = this.dueKind;
    if (this.timingText.isPresent) {
      final value = this.timingText.value;
      json[r'timing_text'] = value;
    }
    if (this.sourceStatus.isPresent) {
      final value = this.sourceStatus.value;
      json[r'source_status'] = value;
    }
    if (this.readAt.isPresent) {
      final value = this.readAt.value;
      json[r'read_at'] = value == null ? null : value.toUtc().toIso8601String();
    }
    if (this.mutedAt.isPresent) {
      final value = this.mutedAt.value;
      json[r'muted_at'] = value == null ? null : value.toUtc().toIso8601String();
    }
    return json;
  }

  /// Returns a new [AssignmentItem] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AssignmentItem? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'kind'), 'Required key "AssignmentItem[kind]" is missing from JSON.');
        assert(json[r'kind'] != null, 'Required key "AssignmentItem[kind]" has a null value in JSON.');
        assert(json.containsKey(r'id'), 'Required key "AssignmentItem[id]" is missing from JSON.');
        assert(json[r'id'] != null, 'Required key "AssignmentItem[id]" has a null value in JSON.');
        assert(json.containsKey(r'assignment_id'), 'Required key "AssignmentItem[assignment_id]" is missing from JSON.');
        assert(json[r'assignment_id'] != null, 'Required key "AssignmentItem[assignment_id]" has a null value in JSON.');
        assert(json.containsKey(r'title'), 'Required key "AssignmentItem[title]" is missing from JSON.');
        assert(json[r'title'] != null, 'Required key "AssignmentItem[title]" has a null value in JSON.');
        assert(json.containsKey(r'due_kind'), 'Required key "AssignmentItem[due_kind]" is missing from JSON.');
        assert(json[r'due_kind'] != null, 'Required key "AssignmentItem[due_kind]" has a null value in JSON.');
        return true;
      }());

      return AssignmentItem(
        kind: AssignmentItemKindEnum.fromJson(json[r'kind'])!,
        id: mapValueOfType<String>(json, r'id')!,
        assignmentId: mapValueOfType<String>(json, r'assignment_id')!,
        courseOfferingId: json.containsKey(r'course_offering_id') ? Optional.present(mapValueOfType<String>(json, r'course_offering_id')) : const Optional.absent(),
        title: mapValueOfType<String>(json, r'title')!,
        dueAt: json.containsKey(r'due_at') ? Optional.present(mapDateTime(json, r'due_at', r'')) : const Optional.absent(),
        dueKind: AssignmentItemDueKindEnum.fromJson(json[r'due_kind'])!,
        timingText: json.containsKey(r'timing_text') ? Optional.present(mapValueOfType<String>(json, r'timing_text')) : const Optional.absent(),
        sourceStatus: json.containsKey(r'source_status') ? Optional.present(mapValueOfType<String>(json, r'source_status')) : const Optional.absent(),
        readAt: json.containsKey(r'read_at') ? Optional.present(mapDateTime(json, r'read_at', r'')) : const Optional.absent(),
        mutedAt: json.containsKey(r'muted_at') ? Optional.present(mapDateTime(json, r'muted_at', r'')) : const Optional.absent(),
      );
    }
    return null;
  }

  static List<AssignmentItem> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AssignmentItem>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AssignmentItem.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AssignmentItem> mapFromJson(dynamic json) {
    final map = <String, AssignmentItem>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AssignmentItem.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AssignmentItem-objects as value to a dart map
  static Map<String, List<AssignmentItem>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AssignmentItem>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AssignmentItem.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'kind',
    'id',
    'assignment_id',
    'title',
    'due_kind',
  };
}


enum AssignmentItemKindEnum {
  assignment._(r'assignment'),
  ;

  /// Instantiate a new enum with the provided value.
  const AssignmentItemKindEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [AssignmentItemKindEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static AssignmentItemKindEnum? fromJson(dynamic value) => AssignmentItemKindEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [AssignmentItemKindEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<AssignmentItemKindEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AssignmentItemKindEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AssignmentItemKindEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [AssignmentItemKindEnum] to String,
/// and [decode] dynamic data back to [AssignmentItemKindEnum].
class AssignmentItemKindEnumTypeTransformer {
  factory AssignmentItemKindEnumTypeTransformer() => _instance ??= const AssignmentItemKindEnumTypeTransformer._();

  const AssignmentItemKindEnumTypeTransformer._();

  String encode(AssignmentItemKindEnum data) => data._value;

  /// Returns the instance of [AssignmentItemKindEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  AssignmentItemKindEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data is AssignmentItemKindEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'assignment': return AssignmentItemKindEnum.assignment;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static AssignmentItemKindEnumTypeTransformer? _instance;
}



enum AssignmentItemDueKindEnum {
  exact._(r'exact'),
  dateOnly._(r'date_only'),
  relative._(r'relative'),
  unknown._(r'unknown'),
  ;

  /// Instantiate a new enum with the provided value.
  const AssignmentItemDueKindEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [AssignmentItemDueKindEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static AssignmentItemDueKindEnum? fromJson(dynamic value) => AssignmentItemDueKindEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [AssignmentItemDueKindEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<AssignmentItemDueKindEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AssignmentItemDueKindEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AssignmentItemDueKindEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [AssignmentItemDueKindEnum] to String,
/// and [decode] dynamic data back to [AssignmentItemDueKindEnum].
class AssignmentItemDueKindEnumTypeTransformer {
  factory AssignmentItemDueKindEnumTypeTransformer() => _instance ??= const AssignmentItemDueKindEnumTypeTransformer._();

  const AssignmentItemDueKindEnumTypeTransformer._();

  String encode(AssignmentItemDueKindEnum data) => data._value;

  /// Returns the instance of [AssignmentItemDueKindEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  AssignmentItemDueKindEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data is AssignmentItemDueKindEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'exact': return AssignmentItemDueKindEnum.exact;
        case r'date_only': return AssignmentItemDueKindEnum.dateOnly;
        case r'relative': return AssignmentItemDueKindEnum.relative;
        case r'unknown': return AssignmentItemDueKindEnum.unknown;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static AssignmentItemDueKindEnumTypeTransformer? _instance;
}


