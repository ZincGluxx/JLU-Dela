import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/auth/account_gateway.dart';
import '../../core/auth/session_controller.dart';
import '../../core/auth/session_models.dart';
import 'auth_failure_message.dart';

class ActivatePage extends StatefulWidget {
  const ActivatePage({
    super.key,
    required this.session,
    required this.accountGateway,
  });

  final SessionController session;
  final AccountGateway accountGateway;

  @override
  State<ActivatePage> createState() => _ActivatePageState();
}

class _ActivatePageState extends State<ActivatePage> {
  final _formKey = GlobalKey<FormState>();
  final _inviteController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _inviteFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool _submitting = false;
  String? _errorText;
  int _operation = 0;

  @override
  void dispose() {
    _operation++;
    _inviteController.clear();
    _passwordController.clear();
    _confirmController.clear();
    _inviteController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _inviteFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) {
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

    final inviteToken = _inviteController.text.trim();
    final password = _passwordController.text;

    try {
      final credentials = await widget.accountGateway.activate(
        inviteToken: inviteToken,
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
    _inviteController.clear();
    _passwordController.clear();
    _confirmController.clear();
    setState(() {
      _submitting = false;
    });
    Navigator.of(context).maybePop();
  }

  void _applyFailure(Object error) {
    _passwordController.clear();
    _confirmController.clear();
    _passwordFocusNode.requestFocus();

    final failure = asApiFailure(error);
    setState(() {
      _submitting = false;
      _errorText = failure == null
          ? '激活失败，请稍后重试。'
          : activationFailureMessage(failure);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: const Text('激活工作台账号'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontal = constraints.maxWidth >= AppBreakpoints.cardGrid
              ? AppSpacing.xxl
              : AppSpacing.lg;
          return SingleChildScrollView(
            key: const Key('activate-page'),
            padding: EdgeInsets.fromLTRB(
              horizontal,
              AppSpacing.lg,
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
                          Text(
                            '设置密码并激活账号',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          const Text(
                            '邀请码由管理员一次性发放，激活后立即失效。',
                            style: TextStyle(color: AppTheme.muted),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          TextFormField(
                            key: const Key('activate-invite-field'),
                            controller: _inviteController,
                            focusNode: _inviteFocusNode,
                            enabled: !_submitting,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: '邀请码',
                              hintText: 'inv_…',
                              prefixIcon: Icon(Icons.vpn_key_outlined),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return '请输入邀请码';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextFormField(
                            key: const Key('activate-password-field'),
                            controller: _passwordController,
                            focusNode: _passwordFocusNode,
                            enabled: !_submitting,
                            obscureText: true,
                            enableSuggestions: false,
                            autocorrect: false,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: '新密码',
                              helperText: '12–128 个字符，且不能与登录名相同',
                              prefixIcon: Icon(Icons.password_outlined),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              final length = value?.runes.length ?? 0;
                              if (length < 12 || length > 128) {
                                return '密码长度需为 12–128 个字符';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextFormField(
                            key: const Key('activate-confirm-field'),
                            controller: _confirmController,
                            enabled: !_submitting,
                            obscureText: true,
                            enableSuggestions: false,
                            autocorrect: false,
                            textInputAction: TextInputAction.done,
                            decoration: const InputDecoration(
                              labelText: '确认密码',
                              prefixIcon: Icon(Icons.password_outlined),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '请再次输入密码';
                              }
                              if (value != _passwordController.text) {
                                return '两次输入的密码不一致';
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) => _submit(),
                          ),
                          if (_errorText != null) ...[
                            const SizedBox(height: AppSpacing.md),
                            Container(
                              key: const Key('activate-error'),
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
                                      _errorText!,
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
                            key: const Key('activate-submit'),
                            onPressed: _submitting ? null : _submit,
                            child: _submitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('激活并登录'),
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
      ),
    );
  }
}
