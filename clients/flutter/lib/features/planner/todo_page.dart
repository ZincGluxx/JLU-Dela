import 'package:flutter/material.dart';

import '../../app/feature_placeholder.dart';
import '../../core/storage/local_workspace.dart';

class TodoPage extends StatelessWidget {
  const TodoPage({super.key, required this.workspace});

  final LocalWorkspace workspace;

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      icon: Icons.checklist_outlined,
      title: '待办',
      description: '功能迁移中，尚未接入本地待办数据',
    );
  }
}
