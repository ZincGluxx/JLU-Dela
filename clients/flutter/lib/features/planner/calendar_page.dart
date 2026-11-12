import 'package:flutter/material.dart';

import '../../app/feature_placeholder.dart';
import '../../core/storage/local_workspace.dart';

class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key, required this.workspace});

  final LocalWorkspace workspace;

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      icon: Icons.calendar_month_outlined,
      title: '学习日历',
      description: '功能迁移中，尚未接入本地课表与作业数据',
    );
  }
}
