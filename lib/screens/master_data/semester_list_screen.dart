import 'package:flutter/material.dart';

import '../../models/semester.dart';
import '../../repositories/master_data_repository.dart';
import 'master_data_crud_screen.dart';
import 'semester_form.dart';

class SemesterListScreen extends StatelessWidget {
  const SemesterListScreen({super.key, required this.repository});

  final MasterDataRepository repository;

  @override
  Widget build(BuildContext context) {
    return MasterDataCrudScreen<Semester>(
      title: 'Semesters',
      entityKey: 'semester',
      icon: Icons.layers_outlined,
      addTooltip: 'Add semester',
      emptyText: 'No semesters yet. Use + to add one.',
      idOf: (s) => s.id!,
      titleOf: (s) => s.name ?? 'Unknown',
      subtitleOf: (s) => <String?>[s.code, s.year?.toString(), s.academicSession?.name]
          .where((v) => v != null && v.isNotEmpty)
          .join(' · '),
      fetch: repository.getSemesters,
      create: (context) => showSemesterForm(context, repository),
      edit: (context, item) => showSemesterForm(context, repository, initial: item),
      remove: (item) => repository.deleteSemester(item.id!),
    );
  }
}