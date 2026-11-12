import 'package:flutter/material.dart';

import '../../app/feature_placeholder.dart';
import '../../core/storage/local_workspace.dart';
import 'teaching_store.dart';

class TeachingPage extends StatelessWidget {
  const TeachingPage({super.key, required this.workspace, required this.store});

  final LocalWorkspace workspace;
  final TeachingStore store;

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      icon: Icons.menu_book_outlined,
      title: '课表',
      description: '功能迁移中，尚未接入教务学期与课表数据',
    );
  }
}
