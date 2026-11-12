//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AcademicPeriodsSource {
  /// Returns a new [AcademicPeriodsSource] instance.
  AcademicPeriodsSource({
    required this.url,
    required this.publishedAt,
    required this.effectiveFromTerm,
  });

  String url;

  /// Null because the official period page has no verified publication date.
  DateTime? publishedAt;

  String effectiveFromTerm;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AcademicPeriodsSource &&
    other.url == url &&
    other.publishedAt == publishedAt &&
    other.effectiveFromTerm == effectiveFromTerm;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (url.hashCode) +
    (publishedAt == null ? 0 : publishedAt!.hashCode) +
    (effectiveFromTerm.hashCode);

  @override
  String toString() => 'AcademicPeriodsSource[url=$url, publishedAt=$publishedAt, effectiveFromTerm=$effectiveFromTerm]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'url'] = this.url;
    if (this.publishedAt != null) {
      json[r'published_at'] = _dateFormatter.format(this.publishedAt!);
    } else {
      json[r'published_at'] = null;
    }
      json[r'effective_from_term'] = this.effectiveFromTerm;
    return json;
  }

  /// Returns a new [AcademicPeriodsSource] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AcademicPeriodsSource? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'url'), 'Required key "AcademicPeriodsSource[url]" is missing from JSON.');
        assert(json[r'url'] != null, 'Required key "AcademicPeriodsSource[url]" has a null value in JSON.');
        assert(json.containsKey(r'published_at'), 'Required key "AcademicPeriodsSource[published_at]" is missing from JSON.');
        assert(json.containsKey(r'effective_from_term'), 'Required key "AcademicPeriodsSource[effective_from_term]" is missing from JSON.');
        assert(json[r'effective_from_term'] != null, 'Required key "AcademicPeriodsSource[effective_from_term]" has a null value in JSON.');
        return true;
      }());

      return AcademicPeriodsSource(
        url: mapValueOfType<String>(json, r'url')!,
        publishedAt: mapDateTime(json, r'published_at', r''),
        effectiveFromTerm: mapValueOfType<String>(json, r'effective_from_term')!,
      );
    }
    return null;
  }

  static List<AcademicPeriodsSource> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AcademicPeriodsSource>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AcademicPeriodsSource.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AcademicPeriodsSource> mapFromJson(dynamic json) {
    final map = <String, AcademicPeriodsSource>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AcademicPeriodsSource.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AcademicPeriodsSource-objects as value to a dart map
  static Map<String, List<AcademicPeriodsSource>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AcademicPeriodsSource>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AcademicPeriodsSource.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'url',
    'published_at',
    'effective_from_term',
  };
}

