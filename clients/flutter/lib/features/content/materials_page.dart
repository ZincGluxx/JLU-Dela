import 'package:flutter/material.dart';

import '../../app/feature_placeholder.dart';
import '../../core/storage/local_workspace.dart';
import 'content_store.dart';

class MaterialsPage extends StatelessWidget {
  const MaterialsPage({
    super.key,
    required this.workspace,
    required this.store,
  });

  final LocalWorkspace workspace;
  final ContentStore store;

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      icon: Icons.folder_open_outlined,
      title: '课程资料',
      description: '功能迁移中，尚未接入学习通资料目录',
    );
  }
}
