import '../models/source.dart';

class CampusLoginResult {
  const CampusLoginResult({required this.connected, this.message});

  final bool connected;
  final String? message;
}

abstract interface class CampusLogin {
  Future<CampusLoginResult> connect(SourceKind source);
}

class UnsupportedCampusLogin implements CampusLogin {
  const UnsupportedCampusLogin();

  @override
  Future<CampusLoginResult> connect(SourceKind source) async {
    return const CampusLoginResult(connected: false, message: '设备端校园登录尚未接入');
  }
}

class FakeCampusLogin implements CampusLogin {
  FakeCampusLogin({this.connected = true, this.message});

  final bool connected;
  final String? message;
  final List<SourceKind> attempted = [];

  @override
  Future<CampusLoginResult> connect(SourceKind source) async {
    attempted.add(source);
    return CampusLoginResult(connected: connected, message: message);
  }
}
