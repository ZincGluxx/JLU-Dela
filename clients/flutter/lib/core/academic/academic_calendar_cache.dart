import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

abstract interface class AcademicCalendarCache {
  Future<String?> read(String academicYear);
  Future<void> write(String academicYear, String contents);
}

class FileAcademicCalendarCache implements AcademicCalendarCache {
  FileAcademicCalendarCache(this.directory);

  final Directory directory;

  static Future<FileAcademicCalendarCache> applicationSupport() async {
    final support = await getApplicationSupportDirectory();
    return FileAcademicCalendarCache(
      Directory(p.join(support.path, 'jlu_dela', 'academic-calendar')),
    );
  }

  File _file(String academicYear) {
    if (!RegExp(r'^\d{4}-\d{4}$').hasMatch(academicYear)) {
      throw ArgumentError.value(academicYear, 'academicYear');
    }
    return File(p.join(directory.path, '$academicYear.json'));
  }

  @override
  Future<String?> read(String academicYear) async {
    final file = _file(academicYear);
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  @override
  Future<void> write(String academicYear, String contents) async {
    final file = _file(academicYear);
    await directory.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(contents, flush: true);
    await temporary.rename(file.path);
  }
}
