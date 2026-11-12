import 'package:jlu_dela_api/api.dart';

import '../../core/api/api_failure.dart';

ApiFailure? asApiFailure(Object error) {
  if (error is ApiFailure) {
    return error;
  }
  if (error is ApiException) {
    return mapApiException(error);
  }
  return null;
}

int rateLimitSeconds(ApiFailure failure) {
  final seconds = failure.retryAfter?.inSeconds ?? 60;
  return seconds < 1 ? 1 : seconds;
}

String loginFailureMessage(ApiFailure failure) {
  if (failure.code == 'INVALID_CREDENTIALS') {
    return '账号或密码不正确。';
  }
  return switch (failure.kind) {
    ApiFailureKind.network => '无法连接服务，请检查网络后重试。',
    ApiFailureKind.timeout => '连接服务超时，请稍后重试。',
    ApiFailureKind.protocol => '服务响应格式无法识别，请稍后重试。',
    ApiFailureKind.server =>
      failure.code == 'VALIDATION_FAILED' ? '登录信息格式不正确，请检查后重试。' : '登录失败，请稍后重试。',
  };
}

String activationFailureMessage(ApiFailure failure) {
  if (failure.code == 'INVALID_INVITE') {
    return '邀请码无效、已过期或已使用，请联系管理员重新获取。';
  }
  return switch (failure.kind) {
    ApiFailureKind.network => '无法连接服务，请检查网络后重试。',
    ApiFailureKind.timeout => '连接服务超时，请稍后重试。',
    ApiFailureKind.protocol => '服务响应格式无法识别，请稍后重试。',
    ApiFailureKind.server =>
      failure.code == 'VALIDATION_FAILED'
          ? '邀请码或密码格式不正确，请检查后重试。'
          : '激活失败，请稍后重试。',
  };
}
