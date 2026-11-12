//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AcademicCalendarEvent {
  /// Returns a new [AcademicCalendarEvent] instance.
  AcademicCalendarEvent({
    required this.id,
    required this.title,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.termId,
  });

  String id;

  String title;

  AcademicCalendarEventTypeEnum type;

  /// Inclusive start date in Asia/Shanghai.
  DateTime startDate;

  /// Inclusive end date in Asia/Shanghai.
  DateTime endDate;

  String? termId;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AcademicCalendarEvent &&
    other.id == id &&
    other.title == title &&
    other.type == type &&
    other.startDate == startDate &&
    other.endDate == endDate &&
    other.termId == termId;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (title.hashCode) +
    (type.hashCode) +
    (startDate.hashCode) +
    (endDate.hashCode) +
    (termId == null ? 0 : termId!.hashCode);

  @override
  String toString() => 'AcademicCalendarEvent[id=$id, title=$title, type=$type, startDate=$startDate, endDate=$endDate, termId=$termId]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'title'] = this.title;
      json[r'type'] = this.type;
      json[r'start_date'] = _dateFormatter.format(this.startDate);
      json[r'end_date'] = _dateFormatter.format(this.endDate);
    if (this.termId != null) {
      json[r'term_id'] = this.termId;
    } else {
      json[r'term_id'] = null;
    }
    return json;
  }

  /// Returns a new [AcademicCalendarEvent] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AcademicCalendarEvent? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'id'), 'Required key "AcademicCalendarEvent[id]" is missing from JSON.');
        assert(json[r'id'] != null, 'Required key "AcademicCalendarEvent[id]" has a null value in JSON.');
        assert(json.containsKey(r'title'), 'Required key "AcademicCalendarEvent[title]" is missing from JSON.');
        assert(json[r'title'] != null, 'Required key "AcademicCalendarEvent[title]" has a null value in JSON.');
        assert(json.containsKey(r'type'), 'Required key "AcademicCalendarEvent[type]" is missing from JSON.');
        assert(json[r'type'] != null, 'Required key "AcademicCalendarEvent[type]" has a null value in JSON.');
        assert(json.containsKey(r'start_date'), 'Required key "AcademicCalendarEvent[start_date]" is missing from JSON.');
        assert(json[r'start_date'] != null, 'Required key "AcademicCalendarEvent[start_date]" has a null value in JSON.');
        assert(json.containsKey(r'end_date'), 'Required key "AcademicCalendarEvent[end_date]" is missing from JSON.');
        assert(json[r'end_date'] != null, 'Required key "AcademicCalendarEvent[end_date]" has a null value in JSON.');
        assert(json.containsKey(r'term_id'), 'Required key "AcademicCalendarEvent[term_id]" is missing from JSON.');
        return true;
      }());

      return AcademicCalendarEvent(
        id: mapValueOfType<String>(json, r'id')!,
        title: mapValueOfType<String>(json, r'title')!,
        type: AcademicCalendarEventTypeEnum.fromJson(json[r'type'])!,
        startDate: mapDateTime(json, r'start_date', r'')!,
        endDate: mapDateTime(json, r'end_date', r'')!,
        termId: mapValueOfType<String>(json, r'term_id'),
      );
    }
    return null;
  }

  static List<AcademicCalendarEvent> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AcademicCalendarEvent>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AcademicCalendarEvent.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AcademicCalendarEvent> mapFromJson(dynamic json) {
    final map = <String, AcademicCalendarEvent>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AcademicCalendarEvent.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AcademicCalendarEvent-objects as value to a dart map
  static Map<String, List<AcademicCalendarEvent>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AcademicCalendarEvent>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AcademicCalendarEvent.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'title',
    'type',
    'start_date',
    'end_date',
    'term_id',
  };
}


enum AcademicCalendarEventTypeEnum {
  teaching._(r'teaching'),
  exam._(r'exam'),
  winterBreak._(r'winter_break'),
  summerBreak._(r'summer_break'),
  orientation._(r'orientation'),
  freshmanTeachingStart._(r'freshman_teaching_start'),
  holiday._(r'holiday'),
  ;

  /// Instantiate a new enum with the provided value.
  const AcademicCalendarEventTypeEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [AcademicCalendarEventTypeEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static AcademicCalendarEventTypeEnum? fromJson(dynamic value) => AcademicCalendarEventTypeEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [AcademicCalendarEventTypeEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<AcademicCalendarEventTypeEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AcademicCalendarEventTypeEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AcademicCalendarEventTypeEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [AcademicCalendarEventTypeEnum] to String,
/// and [decode] dynamic data back to [AcademicCalendarEventTypeEnum].
class AcademicCalendarEventTypeEnumTypeTransformer {
  factory AcademicCalendarEventTypeEnumTypeTransformer() => _instance ??= const AcademicCalendarEventTypeEnumTypeTransformer._();

  const AcademicCalendarEventTypeEnumTypeTransformer._();

  String encode(AcademicCalendarEventTypeEnum data) => data._value;

  /// Returns the instance of [AcademicCalendarEventTypeEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  AcademicCalendarEventTypeEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data is AcademicCalendarEventTypeEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'teaching': return AcademicCalendarEventTypeEnum.teaching;
        case r'exam': return AcademicCalendarEventTypeEnum.exam;
        case r'winter_break': return AcademicCalendarEventTypeEnum.winterBreak;
        case r'summer_break': return AcademicCalendarEventTypeEnum.summerBreak;
        case r'orientation': return AcademicCalendarEventTypeEnum.orientation;
        case r'freshman_teaching_start': return AcademicCalendarEventTypeEnum.freshmanTeachingStart;
        case r'holiday': return AcademicCalendarEventTypeEnum.holiday;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static AcademicCalendarEventTypeEnumTypeTransformer? _instance;
}


