import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/auth/account_gateway.dart';
import '../../core/auth/session_controller.dart';
import 'auth_failure_message.dart';

class PhoneLoginForm extends StatefulWidget {
  const PhoneLoginForm({
    super.key,
    required this.gateway,
    required this.session,
  });
  final PhoneAccountGateway gateway;
  final SessionController session;

  @override
  State<PhoneLoginForm> createState() => _PhoneLoginFormState();
}

class _PhoneLoginFormState extends State<PhoneLoginForm> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _form = GlobalKey<FormState>();
  Timer? _timer;
  DateTime? _retryAt;
  DateTime? _expiresAt;
  bool _sending = false;
  bool _devMode = false;
  bool _submitting = false;
  String? _error;
  String? _sentPhone;

  int get _wait {
    final remaining = _retryAt?.difference(DateTime.now()).inMilliseconds ?? 0;
    return remaining > 0 ? (remaining / 1000).ceil() : 0;
  }

  String? _validatePhone(String? value) =>
      RegExp(r'^(\+86)?1[3-9][0-9]{9}$').hasMatch(value?.trim() ?? '')
      ? null
      : '请输入 11 位手机号';

  void _countdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() {});
      if (_wait == 0) timer.cancel();
    });
  }

  Future<void> _send() async {
    if (_sending || _wait > 0 || _validatePhone(_phone.text) != null) {
      _form.currentState!.validate();
      return;
    }
    final phone = _phone.text;
    setState(() {
      _sending = true;
      _devMode = false;
      _error = null;
    });
    try {
      final result = await widget.gateway.sendPhoneCode(phone);
      if (!mounted) return;
      setState(() {
        _sentPhone = phone;
        _devMode = result.devMode;
        _retryAt = DateTime.now().add(Duration(seconds: result.retryAfter));
        _expiresAt = DateTime.now().add(Duration(seconds: result.expiresIn));
      });
      _countdown();
    } catch (error) {
      if (!mounted) return;
      final failure = asApiFailure(error);
      setState(() {
        _error = switch (failure?.code) {
          'SMS_UNAVAILABLE' => '短信服务未配置，暂时无法发送验证码。',
          'RATE_LIMITED' => '发送过于频繁，请等待后重试。',
          _ => '验证码发送失败，请稍后重试。',
        };
        if (failure?.code == 'RATE_LIMITED') {
          _retryAt = DateTime.now().add(
            Duration(seconds: rateLimitSeconds(failure!)),
          );
        }
      });
      _countdown();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _submit() async {
    if (_submitting || !_form.currentState!.validate()) return;
    if (_sentPhone == _phone.text &&
        _expiresAt?.isBefore(DateTime.now()) == true) {
      setState(() {
        _error = '验证码已过期，请重新发送。';
        _retryAt = null;
      });
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final credentials = await widget.gateway.loginWithPhone(
        phone: _phone.text,
        smsCode: _code.text,
      );
      if (!mounted) return;
      await widget.session.signIn(credentials);
    } catch (error) {
      if (!mounted) return;
      final failure = asApiFailure(error);
      setState(() {
        _error = switch (failure?.code) {
          'INVALID_SMS_CODE' => '验证码不正确，请重新输入。',
          'SMS_CODE_EXPIRED' => '验证码已过期，请重新发送。',
          _ => '登录失败，请检查网络后重试。',
        };
        if (failure?.code == 'SMS_CODE_EXPIRED') _retryAt = null;
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            key: const Key('phone-field'),
            controller: _phone,
            enabled: !_sending && !_submitting,
            keyboardType: TextInputType.phone,
            validator: _validatePhone,
            autofillHints: const [AutofillHints.telephoneNumberNational],
            decoration: const InputDecoration(
              labelText: '手机号',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            key: const Key('sms-code-field'),
            controller: _code,
            enabled: !_submitting,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            decoration: const InputDecoration(
              labelText: '短信验证码',
              border: OutlineInputBorder(),
            ),
            validator: (value) => RegExp(r'^[0-9]{6}$').hasMatch(value ?? '')
                ? null
                : '请输入 6 位验证码',
            onFieldSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            key: const Key('send-phone-code'),
            onPressed: _sending || _submitting || _wait > 0 ? null : _send,
            child: Text(
              _sending
                  ? '正在发送…'
                  : _wait > 0
                  ? '$_wait 秒后重新发送'
                  : _sentPhone == null
                  ? '发送验证码'
                  : '重新发送验证码',
            ),
          ),
          if (_devMode)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(
                '本地开发模式：未发送短信，请使用开发验证码。',
                key: Key('phone-development-notice'),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(
                _error!,
                key: const Key('phone-login-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            key: const Key('phone-login-submit'),
            onPressed: _submitting || _sending ? null : _submit,
            child: Text(_submitting ? '正在登录…' : '登录'),
          ),
        ],
      ),
    );
  }
}
