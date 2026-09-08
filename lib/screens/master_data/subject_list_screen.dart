import 'package:flutter/material.dart';

import '../../models/subject.dart';
import '../../repositories/master_data_repository.dart';
import 'master_data_crud_screen.dart';
import 'subject_form.dart';

class SubjectListScreen extends StatelessWidget {
  const SubjectListScreen({super.key, required this.repository});

  final MasterDataRepository repository;

  @override
  Widget build(BuildContext context) {
    return MasterDataCrudScreen<Subject>(
      title: 'Subjects',
      entityKey: 'subject',
      icon: Icons.book_outlined,
      addTooltip: 'Add subject',
      emptyText: 'No subjects yet. Use + to add one.',
      idOf: (s) => s.id!,
      titleOf: (s) => s.name ?? 'Unknown',
      subtitleOf: (s) =>
          <String?>[s.code, s.creditHours, s.department, s.status]
              .where((v) => v != null && v.isNotEmpty)
              .join(' · '),
      fetch: repository.getSubjects,
      create: (context) => showSubjectForm(context, repository),
      edit: (context, item) => showSubjectForm(context, repository, initial: item),
      remove: (item) => repository.deleteSubject(item.id!),
    );
  }
}