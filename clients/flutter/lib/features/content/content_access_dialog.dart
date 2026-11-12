import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import 'content_store.dart';

class ContentAccessDialog extends StatelessWidget {
  const ContentAccessDialog({
    super.key,
    required this.access,
    required this.sourceLabel,
  });

  final ContentFileAccess access;
  final String sourceLabel;

  static Future<void> show(
    BuildContext context, {
    required ContentFileAccess access,
    required String sourceLabel,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) =>
          ContentAccessDialog(access: access, sourceLabel: sourceLabel),
    );
  }

  @override
  Widget build(BuildContext context) {
    final modeLabel = access.mode == ContentAccessMode.signedUrl
        ? '来源签发的临时链接'
        : '来源页面';
    final expiresAt = access.expiresAtUtc;
    return AlertDialog(
      title: Text(
        access.filename,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$sourceLabel · $modeLabel'),
            const SizedBox(height: AppSpacing.sm),
            if (access.mode == ContentAccessMode.sourcePage)
              Text(
                '该地址需要在 $sourceLabel 来源会话中打开；'
                '工作台不会把它当作可直接下载的链接。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (expiresAt != null)
              Text(
                '链接有效至 ${_formatBeijing(expiresAt)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: AppSpacing.sm),
            SelectableText(
              access.uri.toString(),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: access.uri.toString()));
          },
          child: const Text('复制地址'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

String _formatBeijing(DateTime value) {
  final local = value.toUtc().add(const Duration(hours: 8));
  String pad(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${pad(local.month)}-${pad(local.day)} '
      '${pad(local.hour)}:${pad(local.minute)}';
}
