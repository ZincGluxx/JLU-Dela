String? validateNewUsername(String? value) {
  final match = value == null
      ? null
      : RegExp(r'[a-z0-9]{6,10}').matchAsPrefix(value);
  if (value == null || match == null || match.end != value.length) {
    return '用户名须为 6–10 位小写字母或数字';
  }
  return null;
}

String? validateNewPassword(String? value) {
  if (value == null ||
      value.runes.length < 8 ||
      value.runes.length > 16 ||
      !RegExp(r'[A-Z]').hasMatch(value) ||
      !RegExp(r'[a-z]').hasMatch(value) ||
      !RegExp(r'[0-9]').hasMatch(value)) {
    return '密码须为 8–16 个字符，包含大写字母、小写字母和数字';
  }
  return null;
}
