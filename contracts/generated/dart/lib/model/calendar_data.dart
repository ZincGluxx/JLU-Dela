//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class CalendarData {
  /// Returns a new [CalendarData] instance.
  CalendarData({
    required this.from,
    required this.to,
    this.items = const [],
    this.sources = const [],
  });

  DateTime from;

  DateTime to;

  List<CalendarItem> items;

  /// State of each campus source contributing to this range.
  List<SourceStatus> sources;

  @override
  bool operator ==(Object other) => identical(this, other) || other is CalendarData &&
    other.from == from &&
    other.to == to &&
    _deepEquality.equals(other.items, items) &&
    _deepEquality.equals(other.sources, sources);

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (from.hashCode) +
    (to.hashCode) +
    (items.hashCode) +
    (sources.hashCode);

  @override
  String toString() => 'CalendarData[from=$from, to=$to, items=$items, sources=$sources]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'from'] = _dateFormatter.format(this.from);
      json[r'to'] = _dateFormatter.format(this.to);
      json[r'items'] = this.items;
      json[r'sources'] = this.sources;
    return json;
  }

  /// Returns a new [CalendarData] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static CalendarData? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'from'), 'Required key "CalendarData[from]" is missing from JSON.');
        assert(json[r'from'] != null, 'Required key "CalendarData[from]" has a null value in JSON.');
        assert(json.containsKey(r'to'), 'Required key "CalendarData[to]" is missing from JSON.');
        assert(json[r'to'] != null, 'Required key "CalendarData[to]" has a null value in JSON.');
        assert(json.containsKey(r'items'), 'Required key "CalendarData[items]" is missing from JSON.');
        assert(json[r'items'] != null, 'Required key "CalendarData[items]" has a null value in JSON.');
        assert(json.containsKey(r'sources'), 'Required key "CalendarData[sources]" is missing from JSON.');
        assert(json[r'sources'] != null, 'Required key "CalendarData[sources]" has a null value in JSON.');
        return true;
      }());

      return CalendarData(
        from: mapDateTime(json, r'from', r'')!,
        to: mapDateTime(json, r'to', r'')!,
        items: CalendarItem.listFromJson(json[r'items']),
        sources: SourceStatus.listFromJson(json[r'sources']),
      );
    }
    return null;
  }

  static List<CalendarData> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <CalendarData>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CalendarData.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, CalendarData> mapFromJson(dynamic json) {
    final map = <String, CalendarData>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = CalendarData.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of CalendarData-objects as value to a dart map
  static Map<String, List<CalendarData>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<CalendarData>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = CalendarData.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'from',
    'to',
    'items',
    'sources',
  };
}

