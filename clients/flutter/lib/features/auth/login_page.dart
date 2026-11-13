import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/auth/account_gateway.dart';
import '../../core/auth/session_controller.dart';
import '../../core/auth/session_models.dart';
import 'activate_page.dart';
import 'auth_failure_message.dart';
import 'phone_login_form.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.session,
    required this.accountGateway,
  });

  final SessionController session;
  final AccountGateway accountGateway;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();

  bool _submitting = false;
  bool _passwordLogin = false;
  String? _errorText;
  int _retryAfterSeconds = 0;
  int _operation = 0;
  Timer? _retryTimer;

  @override
  void dispose() {
    _operation++;
    _retryTimer?.cancel();
    _passwordController.clear();
    _loginController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || _retryAfterSeconds > 0) {
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final operation = ++_operation;
    setState(() {
      _submitting = true;
      _errorText = null;
    });

    final login = _loginController.text.trim();
    final password = _passwordController.text;

    try {
      final credentials = await widget.accountGateway.login(
        login: login,
        password: password,
      );
      if (!mounted || operation != _operation) {
        return;
      }
      final outcome = await widget.session.signIn(credentials);
      if (!mounted || operation != _operation) {
        return;
      }
      if (outcome != SignInOutcome.signedIn) {
        return;
      }
    } catch (error) {
      if (!mounted || operation != _operation) {
        return;
      }
      _applyFailure(error);
      return;
    }

    if (!mounted || operation != _operation) {
      return;
    }
    _retryTimer?.cancel();
    _passwordController.clear();
    setState(() {
      _submitting = false;
      _retryAfterSeconds = 0;
      _errorText = null;
    });
  }

  void _applyFailure(Object error) {
    _passwordController.clear();
    _passwordFocusNode.requestFocus();

    final failure = asApiFailure(error);
    if (failure == null) {
      setState(() {
        _submitting = false;
        _retryAfterSeconds = 0;
        _errorText = '登录失败，请稍后重试。';
      });
      return;
    }

    final rateLimited = failure.code == 'RATE_LIMITED';
    setState(() {
      _submitting = false;
      _retryAfterSeconds = rateLimited ? rateLimitSeconds(failure) : 0;
      _errorText = rateLimited ? null : loginFailureMessage(failure);
    });
    if (rateLimited) {
      _startRetryCountdown();
    }
  }

  void _startRetryCountdown() {
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _retryAfterSeconds -= 1;
        if (_retryAfterSeconds <= 0) {
          _retryAfterSeconds = 0;
          timer.cancel();
        }
      });
    });
  }

  void _openActivation() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ActivatePage(
          session: widget.session,
          accountGateway: widget.accountGateway,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errorText = _retryAfterSeconds > 0
        ? '尝试次数过多，请在 $_retryAfterSeconds 秒后重试。'
        : _errorText;

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = constraints.maxWidth >= AppBreakpoints.cardGrid
            ? AppSpacing.xxl
            : AppSpacing.lg;
        return SingleChildScrollView(
          key: const Key('login-page'),
          padding: EdgeInsets.fromLTRB(
            horizontal,
            AppSpacing.xl,
            horizontal,
            AppSpacing.xxl,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Material(
                color: theme.colorScheme.surface,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.surfaceRadius),
                  side: const BorderSide(color: AppTheme.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(
                          Icons.lock_open_outlined,
                          size: 36,
                          color: AppTheme.primary,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          '登录工作台',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        const Text(
                          '使用手机号登录工作台。',
                          style: TextStyle(color: AppTheme.muted),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        if (!_passwordLogin &&
                            widget.accountGateway is PhoneAccountGateway)
                          PhoneLoginForm(
                            gateway:
                                widget.accountGateway as PhoneAccountGateway,
                            session: widget.session,
                          ),
                        if (_passwordLogin ||
                            widget.accountGateway is! PhoneAccountGateway) ...[
                          TextFormField(
                            key: const Key('login-field'),
                            controller: _loginController,
                            enabled: !_submitting,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.username],
                            decoration: const InputDecoration(
                              labelText: '登录名',
                              hintText: '例如 e2e.user',
                              prefixIcon: Icon(Icons.person_outline),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              final login = value?.trim() ?? '';
                              if (login.isEmpty) {
                                return '请输入登录名';
                              }
                              if (login.length < 4 || login.length > 64) {
                                return '登录名应为 4–64 个字符';
                              }
                              if (!RegExp(
                                r'^[a-zA-Z0-9._-]+$',
                              ).hasMatch(login)) {
                                return '登录名只能包含字母、数字、点、下划线和连字符';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextFormField(
                            key: const Key('login-password-field'),
                            controller: _passwordController,
                            focusNode: _passwordFocusNode,
                            enabled: !_submitting,
                            obscureText: true,
                            enableSuggestions: false,
                            autocorrect: false,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            decoration: const InputDecoration(
                              labelText: '密码',
                              prefixIcon: Icon(Icons.password_outlined),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '请输入密码';
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) => _submit(),
                          ),
                          if (errorText != null) ...[
                            const SizedBox(height: AppSpacing.md),
                            Container(
                              key: const Key('login-error'),
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.errorContainer,
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.sm,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    size: 20,
                                    color: theme.colorScheme.onErrorContainer,
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Text(
                                      errorText,
                                      style: TextStyle(
                                        color:
                                            theme.colorScheme.onErrorContainer,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.lg),
                          FilledButton(
                            key: const Key('login-submit'),
                            onPressed: _submitting || _retryAfterSeconds > 0
                                ? null
                                : _submit,
                            child: _submitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    _retryAfterSeconds > 0
                                        ? '请等待 $_retryAfterSeconds 秒'
                                        : '登录',
                                  ),
                          ),
                        ],
                        if (widget.accountGateway is PhoneAccountGateway)
                          TextButton(
                            key: const Key('login-method-toggle'),
                            onPressed: _submitting
                                ? null
                                : () => setState(
                                    () => _passwordLogin = !_passwordLogin,
                                  ),
                            child: Text(_passwordLogin ? '手机号登录' : '账号密码登录'),
                          ),
                        const SizedBox(height: AppSpacing.sm),
                        TextButton.icon(
                          key: const Key('login-activate-entry'),
                          onPressed: _submitting ? null : _openActivation,
                          icon: const Icon(Icons.key_outlined),
                          label: const Text('用邀请码激活'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
