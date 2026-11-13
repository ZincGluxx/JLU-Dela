abstract interface class ProfileGateway {
  Future<void> updateAccount({
    required String accessToken,
    String? username,
    String? displayName,
    String? password,
  });

  Future<void> verifyStudentReport({
    required String accessToken,
    required String reportCode,
  });
}
