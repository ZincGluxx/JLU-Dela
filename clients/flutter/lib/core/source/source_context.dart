import 'campus_login.dart';
import 'source_portal.dart';
import 'source_session.dart';

class SourceContext {
  const SourceContext({
    required this.sessions,
    required this.http,
    required this.campusLogin,
    required this.browser,
  });

  final SourceSessionRegistry sessions;
  final SourceHttpClient http;
  final CampusLogin campusLogin;
  final SourcePageOpener browser;
}
