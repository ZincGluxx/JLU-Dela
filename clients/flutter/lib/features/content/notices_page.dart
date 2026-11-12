import 'package:flutter/material.dart';

import '../../app/feature_placeholder.dart';
import '../../core/storage/local_workspace.dart';
import 'content_store.dart';

class NoticesPage extends StatelessWidget {
  const NoticesPage({super.key, required this.workspace, required this.store});

  final LocalWorkspace workspace;
  final ContentStore store;

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      icon: Icons.notifications_none_outlined,
      title: '校园通知',
      description: '功能迁移中，尚未接入电子校务通知数据',
    );
  }
}
