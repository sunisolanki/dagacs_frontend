import 'package:flutter/material.dart';

import '../../models/teacher_assignment.dart';
import '../../repositories/master_data_repository.dart';
import 'assignment_form.dart';
import 'master_data_crud_screen.dart';

class TeacherAssignmentListScreen extends StatefulWidget {
  const TeacherAssignmentListScreen({super.key, required this.repository});

  final MasterDataRepository repository;

  @override
  State<TeacherAssignmentListScreen> createState() =>
      _TeacherAssignmentListScreenState();
}

class _TeacherAssignmentListScreenState
    extends State<TeacherAssignmentListScreen> {
  /// Fully derived server-side context is joined into one human-readable
  /// subtitle, mirroring how the backend resolves it (no client context ids).
  static String? _contextOf(TeacherAssignment a) {
    String join(List<String?> parts) => parts
        .where((p) => p != null && p.isNotEmpty)
        .join(' — ')
        .trim();

    final subject =
        join([a.subjectCode, a.subjectName]);
    final session =
        join([a.sessionName, a.programName, a.departmentName]);
    final section = join([a.sectionCode, a.sectionName]);
    final batch = a.batchCode?.trim();

    return <String?>[subject, session, section, batch]
        .where((p) => p != null && p.isNotEmpty)
        .join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return MasterDataCrudScreen<TeacherAssignment>(
      title: 'Teacher Assignments',
      entityKey: 'assignment',
      icon: Icons.badge_outlined,
      addTooltip: 'Add teacher assignment',
      emptyText: 'No teacher assignments yet. Use + to map one.',
      idOf: (a) => a.id!,
      titleOf: (a) => a.teacherName ?? 'Unknown',
      subtitleOf: _contextOf,
      fetch: widget.repository.getTeacherAssignments,
      create: (context) =>
          showTeacherAssignmentForm(context, widget.repository),
      edit: (context, item) => showTeacherAssignmentForm(context,
          widget.repository,
          initial: item),
      remove: (item) => widget.repository.deleteTeacherAssignment(item.id!),
    );
  }
}