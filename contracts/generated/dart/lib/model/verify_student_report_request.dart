//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class VerifyStudentReportRequest {
  /// Returns a new [VerifyStudentReportRequest] instance.
  VerifyStudentReportRequest({
    required this.reportCode,
  });

  /// A 12-digit legacy code or a 16-character uppercase alphanumeric code beginning A or X. Never log or include it in business backups.
  String reportCode;

  @override
  bool operator ==(Object other) => identical(this, other) || other is VerifyStudentReportRequest &&
    other.reportCode == reportCode;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (reportCode.hashCode);

  @override
  String toString() => 'VerifyStudentReportRequest[reportCode=$reportCode]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'report_code'] = this.reportCode;
    return json;
  }

  /// Returns a new [VerifyStudentReportRequest] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static VerifyStudentReportRequest? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'report_code'), 'Required key "VerifyStudentReportRequest[report_code]" is missing from JSON.');
        assert(json[r'report_code'] != null, 'Required key "VerifyStudentReportRequest[report_code]" has a null value in JSON.');
        return true;
      }());

      return VerifyStudentReportRequest(
        reportCode: mapValueOfType<String>(json, r'report_code')!,
      );
    }
    return null;
  }

  static List<VerifyStudentReportRequest> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <VerifyStudentReportRequest>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = VerifyStudentReportRequest.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, VerifyStudentReportRequest> mapFromJson(dynamic json) {
    final map = <String, VerifyStudentReportRequest>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = VerifyStudentReportRequest.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of VerifyStudentReportRequest-objects as value to a dart map
  static Map<String, List<VerifyStudentReportRequest>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<VerifyStudentReportRequest>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = VerifyStudentReportRequest.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'report_code',
  };
}

