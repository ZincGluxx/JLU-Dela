//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class TeachingBackupSourceRef {
  /// Returns a new [TeachingBackupSourceRef] instance.
  TeachingBackupSourceRef({
    required this.source_,
    required this.sourceScope,
    required this.sourceId,
  });

  TeachingBackupSourceRefSource_Enum source_;

  String sourceScope;

  String sourceId;

  @override
  bool operator ==(Object other) => identical(this, other) || other is TeachingBackupSourceRef &&
    other.source_ == source_ &&
    other.sourceScope == sourceScope &&
    other.sourceId == sourceId;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (source_.hashCode) +
    (sourceScope.hashCode) +
    (sourceId.hashCode);

  @override
  String toString() => 'TeachingBackupSourceRef[source_=$source_, sourceScope=$sourceScope, sourceId=$sourceId]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'source'] = this.source_;
      json[r'source_scope'] = this.sourceScope;
      json[r'source_id'] = this.sourceId;
    return json;
  }

  /// Returns a new [TeachingBackupSourceRef] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static TeachingBackupSourceRef? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'source'), 'Required key "TeachingBackupSourceRef[source]" is missing from JSON.');
        assert(json[r'source'] != null, 'Required key "TeachingBackupSourceRef[source]" has a null value in JSON.');
        assert(json.containsKey(r'source_scope'), 'Required key "TeachingBackupSourceRef[source_scope]" is missing from JSON.');
        assert(json[r'source_scope'] != null, 'Required key "TeachingBackupSourceRef[source_scope]" has a null value in JSON.');
        assert(json.containsKey(r'source_id'), 'Required key "TeachingBackupSourceRef[source_id]" is missing from JSON.');
        assert(json[r'source_id'] != null, 'Required key "TeachingBackupSourceRef[source_id]" has a null value in JSON.');
        return true;
      }());

      return TeachingBackupSourceRef(
        source_: TeachingBackupSourceRefSource_Enum.fromJson(json[r'source'])!,
        sourceScope: mapValueOfType<String>(json, r'source_scope')!,
        sourceId: mapValueOfType<String>(json, r'source_id')!,
      );
    }
    return null;
  }

  static List<TeachingBackupSourceRef> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <TeachingBackupSourceRef>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = TeachingBackupSourceRef.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, TeachingBackupSourceRef> mapFromJson(dynamic json) {
    final map = <String, TeachingBackupSourceRef>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = TeachingBackupSourceRef.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of TeachingBackupSourceRef-objects as value to a dart map
  static Map<String, List<TeachingBackupSourceRef>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<TeachingBackupSourceRef>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = TeachingBackupSourceRef.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'source',
    'source_scope',
    'source_id',
  };
}


enum TeachingBackupSourceRefSource_Enum {
  jluIedu._(r'jlu_iedu'),
  ;

  /// Instantiate a new enum with the provided value.
  const TeachingBackupSourceRefSource_Enum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [TeachingBackupSourceRefSource_Enum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static TeachingBackupSourceRefSource_Enum? fromJson(dynamic value) => TeachingBackupSourceRefSource_EnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [TeachingBackupSourceRefSource_Enum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<TeachingBackupSourceRefSource_Enum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <TeachingBackupSourceRefSource_Enum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = TeachingBackupSourceRefSource_Enum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [TeachingBackupSourceRefSource_Enum] to String,
/// and [decode] dynamic data back to [TeachingBackupSourceRefSource_Enum].
class TeachingBackupSourceRefSource_EnumTypeTransformer {
  factory TeachingBackupSourceRefSource_EnumTypeTransformer() => _instance ??= const TeachingBackupSourceRefSource_EnumTypeTransformer._();

  const TeachingBackupSourceRefSource_EnumTypeTransformer._();

  String encode(TeachingBackupSourceRefSource_Enum data) => data._value;

  /// Returns the instance of [TeachingBackupSourceRefSource_Enum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  TeachingBackupSourceRefSource_Enum? decode(dynamic data, {bool allowNull = true}) {
    if (data is TeachingBackupSourceRefSource_Enum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'jlu_iedu': return TeachingBackupSourceRefSource_Enum.jluIedu;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static TeachingBackupSourceRefSource_EnumTypeTransformer? _instance;
}


