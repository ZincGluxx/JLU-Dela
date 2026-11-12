import 'package:flutter/widgets.dart';

import '../core/models/source.dart';
import '../core/source/campus_login.dart';
import '../core/source/source_session.dart';

class DeviceCampusLogin implements CampusLogin {
  const DeviceCampusLogin({required this.sessions});

  final SourceSessionRegistry sessions;

  @override
  Future<CampusLoginResult> connect(
    BuildContext context,
    SourceKind source,
  ) async {
    return const CampusLoginResult(connected: false, message: '设备端校园登录尚未接入');
  }
}
