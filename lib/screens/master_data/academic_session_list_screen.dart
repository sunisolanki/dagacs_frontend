import 'package:flutter/material.dart';

import '../../models/academic_session.dart';
import '../../repositories/master_data_repository.dart';
import 'academic_session_form.dart';
import 'master_data_crud_screen.dart';

class AcademicSessionListScreen extends StatelessWidget {
  const AcademicSessionListScreen({super.key, required this.repository});

  final MasterDataRepository repository;

  @override
  Widget build(BuildContext context) {
    return MasterDataCrudScreen<AcademicSession>(
      title: 'Academic Sessions',
      entityKey: 'academicSession',
      icon: Icons.calendar_month_outlined,
      addTooltip: 'Add academic session',
      emptyText: 'No academic sessions yet. Use + to add one.',
      idOf: (s) => s.id!,
      titleOf: (s) => s.name ?? 'Unknown',
      subtitleOf: (s) => <String?>[
            s.code,
            s.semester,
            s.program?.name,
            s.durationHours == null ? null : '${s.durationHours}h',
          ]
          .where((v) => v != null && v.isNotEmpty)
          .join(' · '),
      fetch: repository.getAcademicSessions,
      create: (context) => showAcademicSessionForm(context, repository),
      edit: (context, item) =>
          showAcademicSessionForm(context, repository, initial: item),
      remove: (item) => repository.deleteAcademicSession(item.id!),
    );
  }
}