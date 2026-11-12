import 'package:flutter/material.dart';

import '../../app/feature_placeholder.dart';
import '../../core/storage/local_workspace.dart';
import 'chaoxing_store.dart';

class AssignmentsPage extends StatelessWidget {
  const AssignmentsPage({
    super.key,
    required this.workspace,
    required this.store,
  });

  final LocalWorkspace workspace;
  final ChaoxingStore store;

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      icon: Icons.task_alt_outlined,
      title: '作业',
      description: '功能迁移中，尚未接入学习通作业数据',
    );
  }
}
