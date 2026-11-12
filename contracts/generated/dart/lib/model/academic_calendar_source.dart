//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AcademicCalendarSource {
  /// Returns a new [AcademicCalendarSource] instance.
  AcademicCalendarSource({
    required this.url,
    required this.imageUrl,
    required this.publishedAt,
  });

  String url;

  String imageUrl;

  DateTime publishedAt;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AcademicCalendarSource &&
    other.url == url &&
    other.imageUrl == imageUrl &&
    other.publishedAt == publishedAt;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (url.hashCode) +
    (imageUrl.hashCode) +
    (publishedAt.hashCode);

  @override
  String toString() => 'AcademicCalendarSource[url=$url, imageUrl=$imageUrl, publishedAt=$publishedAt]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'url'] = this.url;
      json[r'image_url'] = this.imageUrl;
      json[r'published_at'] = _dateFormatter.format(this.publishedAt);
    return json;
  }

  /// Returns a new [AcademicCalendarSource] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AcademicCalendarSource? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'url'), 'Required key "AcademicCalendarSource[url]" is missing from JSON.');
        assert(json[r'url'] != null, 'Required key "AcademicCalendarSource[url]" has a null value in JSON.');
        assert(json.containsKey(r'image_url'), 'Required key "AcademicCalendarSource[image_url]" is missing from JSON.');
        assert(json[r'image_url'] != null, 'Required key "AcademicCalendarSource[image_url]" has a null value in JSON.');
        assert(json.containsKey(r'published_at'), 'Required key "AcademicCalendarSource[published_at]" is missing from JSON.');
        assert(json[r'published_at'] != null, 'Required key "AcademicCalendarSource[published_at]" has a null value in JSON.');
        return true;
      }());

      return AcademicCalendarSource(
        url: mapValueOfType<String>(json, r'url')!,
        imageUrl: mapValueOfType<String>(json, r'image_url')!,
        publishedAt: mapDateTime(json, r'published_at', r'')!,
      );
    }
    return null;
  }

  static List<AcademicCalendarSource> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AcademicCalendarSource>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AcademicCalendarSource.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AcademicCalendarSource> mapFromJson(dynamic json) {
    final map = <String, AcademicCalendarSource>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AcademicCalendarSource.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AcademicCalendarSource-objects as value to a dart map
  static Map<String, List<AcademicCalendarSource>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AcademicCalendarSource>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AcademicCalendarSource.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'url',
    'image_url',
    'published_at',
  };
}

