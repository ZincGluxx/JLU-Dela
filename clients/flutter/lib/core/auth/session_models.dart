enum SessionPhase { restoring, authenticated, signedOut, unavailable }

enum SignInOutcome { signedIn, cancelled }

class SessionCredentials {
  const SessionCredentials({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  final String accessToken;
  final String refreshToken;
  final int expiresIn;

  @override
  String toString() {
    return 'SessionCredentials(accessToken: <redacted>, '
        'refreshToken: <redacted>, expiresIn: $expiresIn)';
  }
}

enum SessionRefreshResult {
  refreshed,
  signedOut,
  unavailable,
  networkFailure,
  cancelled,
}

class SignOutResult {
  const SignOutResult({required this.remoteRevoked, this.message});

  final bool remoteRevoked;
  final String? message;

  @override
  String toString() {
    return 'SignOutResult(remoteRevoked: $remoteRevoked, message: $message)';
  }
}
