//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AcademicCalendar {
  /// Returns a new [AcademicCalendar] instance.
  AcademicCalendar({
    required this.academicYear,
    required this.version,
    required this.timeZone,
    required this.source_,
    required this.includesMakeupDayRules,
    this.notes = const [],
    this.terms = const [],
    required this.periodsSource,
    this.periods = const [],
    this.events = const [],
  });

  String academicYear;

  String version;

  AcademicCalendarTimeZoneEnum timeZone;

  AcademicCalendarSource source_;

  /// This dataset does not supply adjusted working days or makeup-class rules.
  bool includesMakeupDayRules;

  List<String> notes;

  List<AcademicCalendarTerm> terms;

  AcademicPeriodsSource periodsSource;

  List<AcademicPeriod> periods;

  List<AcademicCalendarEvent> events;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AcademicCalendar &&
    other.academicYear == academicYear &&
    other.version == version &&
    other.timeZone == timeZone &&
    other.source_ == source_ &&
    other.includesMakeupDayRules == includesMakeupDayRules &&
    _deepEquality.equals(other.notes, notes) &&
    _deepEquality.equals(other.terms, terms) &&
    other.periodsSource == periodsSource &&
    _deepEquality.equals(other.periods, periods) &&
    _deepEquality.equals(other.events, events);

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (academicYear.hashCode) +
    (version.hashCode) +
    (timeZone.hashCode) +
    (source_.hashCode) +
    (includesMakeupDayRules.hashCode) +
    (notes.hashCode) +
    (terms.hashCode) +
    (periodsSource.hashCode) +
    (periods.hashCode) +
    (events.hashCode);

  @override
  String toString() => 'AcademicCalendar[academicYear=$academicYear, version=$version, timeZone=$timeZone, source_=$source_, includesMakeupDayRules=$includesMakeupDayRules, notes=$notes, terms=$terms, periodsSource=$periodsSource, periods=$periods, events=$events]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'academic_year'] = this.academicYear;
      json[r'version'] = this.version;
      json[r'time_zone'] = this.timeZone;
      json[r'source'] = this.source_;
      json[r'includes_makeup_day_rules'] = this.includesMakeupDayRules;
      json[r'notes'] = this.notes;
      json[r'terms'] = this.terms;
      json[r'periods_source'] = this.periodsSource;
      json[r'periods'] = this.periods;
      json[r'events'] = this.events;
    return json;
  }

  /// Returns a new [AcademicCalendar] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AcademicCalendar? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'academic_year'), 'Required key "AcademicCalendar[academic_year]" is missing from JSON.');
        assert(json[r'academic_year'] != null, 'Required key "AcademicCalendar[academic_year]" has a null value in JSON.');
        assert(json.containsKey(r'version'), 'Required key "AcademicCalendar[version]" is missing from JSON.');
        assert(json[r'version'] != null, 'Required key "AcademicCalendar[version]" has a null value in JSON.');
        assert(json.containsKey(r'time_zone'), 'Required key "AcademicCalendar[time_zone]" is missing from JSON.');
        assert(json[r'time_zone'] != null, 'Required key "AcademicCalendar[time_zone]" has a null value in JSON.');
        assert(json.containsKey(r'source'), 'Required key "AcademicCalendar[source]" is missing from JSON.');
        assert(json[r'source'] != null, 'Required key "AcademicCalendar[source]" has a null value in JSON.');
        assert(json.containsKey(r'includes_makeup_day_rules'), 'Required key "AcademicCalendar[includes_makeup_day_rules]" is missing from JSON.');
        assert(json[r'includes_makeup_day_rules'] != null, 'Required key "AcademicCalendar[includes_makeup_day_rules]" has a null value in JSON.');
        assert(json.containsKey(r'notes'), 'Required key "AcademicCalendar[notes]" is missing from JSON.');
        assert(json[r'notes'] != null, 'Required key "AcademicCalendar[notes]" has a null value in JSON.');
        assert(json.containsKey(r'terms'), 'Required key "AcademicCalendar[terms]" is missing from JSON.');
        assert(json[r'terms'] != null, 'Required key "AcademicCalendar[terms]" has a null value in JSON.');
        assert(json.containsKey(r'periods_source'), 'Required key "AcademicCalendar[periods_source]" is missing from JSON.');
        assert(json[r'periods_source'] != null, 'Required key "AcademicCalendar[periods_source]" has a null value in JSON.');
        assert(json.containsKey(r'periods'), 'Required key "AcademicCalendar[periods]" is missing from JSON.');
        assert(json[r'periods'] != null, 'Required key "AcademicCalendar[periods]" has a null value in JSON.');
        assert(json.containsKey(r'events'), 'Required key "AcademicCalendar[events]" is missing from JSON.');
        assert(json[r'events'] != null, 'Required key "AcademicCalendar[events]" has a null value in JSON.');
        return true;
      }());

      return AcademicCalendar(
        academicYear: mapValueOfType<String>(json, r'academic_year')!,
        version: mapValueOfType<String>(json, r'version')!,
        timeZone: AcademicCalendarTimeZoneEnum.fromJson(json[r'time_zone'])!,
        source_: AcademicCalendarSource.fromJson(json[r'source'])!,
        includesMakeupDayRules: mapValueOfType<bool>(json, r'includes_makeup_day_rules')!,
        notes: json[r'notes'] is Iterable
            ? (json[r'notes'] as Iterable).cast<String>().toList(growable: false)
            : const [],
        terms: AcademicCalendarTerm.listFromJson(json[r'terms']),
        periodsSource: AcademicPeriodsSource.fromJson(json[r'periods_source'])!,
        periods: AcademicPeriod.listFromJson(json[r'periods']),
        events: AcademicCalendarEvent.listFromJson(json[r'events']),
      );
    }
    return null;
  }

  static List<AcademicCalendar> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AcademicCalendar>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AcademicCalendar.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AcademicCalendar> mapFromJson(dynamic json) {
    final map = <String, AcademicCalendar>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AcademicCalendar.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AcademicCalendar-objects as value to a dart map
  static Map<String, List<AcademicCalendar>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AcademicCalendar>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AcademicCalendar.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'academic_year',
    'version',
    'time_zone',
    'source',
    'includes_makeup_day_rules',
    'notes',
    'terms',
    'periods_source',
    'periods',
    'events',
  };
}


enum AcademicCalendarTimeZoneEnum {
  asiaSlashShanghai._(r'Asia/Shanghai'),
  ;

  /// Instantiate a new enum with the provided value.
  const AcademicCalendarTimeZoneEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [AcademicCalendarTimeZoneEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static AcademicCalendarTimeZoneEnum? fromJson(dynamic value) => AcademicCalendarTimeZoneEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [AcademicCalendarTimeZoneEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<AcademicCalendarTimeZoneEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AcademicCalendarTimeZoneEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AcademicCalendarTimeZoneEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [AcademicCalendarTimeZoneEnum] to String,
/// and [decode] dynamic data back to [AcademicCalendarTimeZoneEnum].
class AcademicCalendarTimeZoneEnumTypeTransformer {
  factory AcademicCalendarTimeZoneEnumTypeTransformer() => _instance ??= const AcademicCalendarTimeZoneEnumTypeTransformer._();

  const AcademicCalendarTimeZoneEnumTypeTransformer._();

  String encode(AcademicCalendarTimeZoneEnum data) => data._value;

  /// Returns the instance of [AcademicCalendarTimeZoneEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  AcademicCalendarTimeZoneEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data is AcademicCalendarTimeZoneEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'Asia/Shanghai': return AcademicCalendarTimeZoneEnum.asiaSlashShanghai;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static AcademicCalendarTimeZoneEnumTypeTransformer? _instance;
}


