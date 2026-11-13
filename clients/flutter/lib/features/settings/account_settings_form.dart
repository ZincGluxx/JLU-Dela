import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/auth/account_validation.dart';
import '../../core/auth/session_controller.dart';
import '../auth/auth_failure_message.dart';

class AccountSettingsForm extends StatefulWidget {
  const AccountSettingsForm({super.key, required this.session});
  final SessionController session;

  @override
  State<AccountSettingsForm> createState() => _AccountSettingsFormState();
}

class _AccountSettingsFormState extends State<AccountSettingsForm> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _nickname = TextEditingController();
  final _password = TextEditingController();
  final _report = TextEditingController();
  bool _saving = false;
  bool _verifying = false;
  String? _usernameError;
  String? _accountMessage;
  String? _reportMessage;

  @override
  void initState() {
    super.initState();
    _username.text = widget.session.currentUser?.username.orElse(null) ?? '';
    _nickname.text = widget.session.currentUser?.displayName ?? '';
  }

  Future<void> _save() async {
    setState(() {
      _usernameError = null;
      _accountMessage = null;
    });
    if (!_form.currentState!.validate()) return;
    final revision = widget.session.sessionRevision;
    setState(() => _saving = true);
    try {
      final user = widget.session.currentUser!;
      final updated = await widget.session.updateAccount(
        username: _username.text == (user.username.orElse(null) ?? '')
            ? null
            : _username.text,
        displayName: _nickname.text == user.displayName ? null : _nickname.text,
        password: _password.text.isEmpty ? null : _password.text,
      );
      if (!mounted || revision != widget.session.sessionRevision) return;
      _password.clear();
      setState(() => _accountMessage = updated ? '账号设置已保存。' : '会话已变化，请重新操作。');
    } catch (error) {
      if (!mounted || revision != widget.session.sessionRevision) return;
      final failure = asApiFailure(error);
      setState(() {
        if (failure?.code == 'USERNAME_TAKEN') {
          _usernameError = '用户名已被使用，请更换';
        } else {
          _accountMessage = '保存失败，请检查网络后重试。';
        }
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _verify() async {
    if (_report.text.isEmpty) {
      setState(() => _reportMessage = '请输入学信网在线验证报告验证码。');
      return;
    }
    final revision = widget.session.sessionRevision;
    setState(() {
      _verifying = true;
      _reportMessage = null;
    });
    try {
      final updated = await widget.session.verifyStudentReport(_report.text);
      if (!mounted || revision != widget.session.sessionRevision) return;
      _report.clear();
      setState(
        () =>
            _reportMessage = updated ? '吉林大学学籍报告已核验，学院信息已更新。' : '会话已变化，请重新操作。',
      );
    } catch (error) {
      if (!mounted || revision != widget.session.sessionRevision) return;
      final failure = asApiFailure(error);
      setState(
        () => _reportMessage = switch (failure?.code) {
          'STUDENT_REPORT_INVALID' => '报告验证码无效，请检查后重试。',
          'STUDENT_REPORT_RESTRICTED' => '学信网暂时限制服务端查询，请稍后重试。',
          'STUDENT_REPORT_PARSE_FAILED' => '暂时无法识别该报告，请稍后重试。',
          'STUDENT_NOT_ELIGIBLE' => '报告中的学校不是吉林大学。',
          'STUDENT_VERIFICATION_UNAVAILABLE' => '当前学籍报告核验暂不可用，请稍后重试。',
          _ => '核验失败，请稍后重试。',
        },
      );
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  void dispose() {
    _username.dispose();
    _nickname.dispose();
    _password.dispose();
    _report.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.session.currentUser!;
    final busy = _saving || _verifying;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.md),
        Text('账号设置', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Text('用户名：${user.username.orElse(null) ?? '未设置'}'),
        Text('密码：${user.passwordSet.orElse(false) == true ? '已设置' : '未设置'}'),
        const SizedBox(height: AppSpacing.md),
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const Key('account-username'),
                controller: _username,
                enabled: !busy,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: '用户名',
                  helperText: '6–10 位小写字母或数字',
                  errorText: _usernameError,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) {
                  if (_usernameError != null) {
                    setState(() => _usernameError = null);
                  }
                },
                validator: (value) =>
                    value == (user.username.orElse(null) ?? '')
                    ? null
                    : validateNewUsername(value),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                key: const Key('account-nickname'),
                controller: _nickname,
                enabled: !busy,
                decoration: const InputDecoration(
                  labelText: '昵称',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? '请输入昵称' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                key: const Key('account-password'),
                controller: _password,
                enabled: !busy,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: '新密码',
                  helperText: '留空不修改；8–16 个字符，包含大小写字母和数字',
                  helperMaxLines: 3,
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? null
                    : validateNewPassword(value),
              ),
              if (_accountMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    _accountMessage!,
                    key: const Key('account-message'),
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              FilledButton(
                key: const Key('account-save'),
                onPressed: busy ? null : _save,
                child: Text(_saving ? '正在保存…' : '保存账号设置'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('学籍报告核验', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        const Text('核验报告中的吉林大学学校信息与学院，不核对本人身份，不限制学籍状态。'),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          key: const Key('student-report-code'),
          controller: _report,
          enabled: !busy,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(
            labelText: '在线验证报告验证码',
            border: OutlineInputBorder(),
          ),
        ),
        if (_reportMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              _reportMessage!,
              key: const Key('student-report-message'),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          key: const Key('student-report-submit'),
          onPressed: busy ? null : _verify,
          child: Text(_verifying ? '正在核验…' : '核验报告'),
        ),
      ],
    );
  }
}
