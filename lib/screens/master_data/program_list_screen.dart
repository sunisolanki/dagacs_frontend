import 'package:flutter/material.dart';

import '../../models/program.dart';
import '../../repositories/master_data_repository.dart';
import 'master_data_crud_screen.dart';
import 'program_form.dart';

class ProgramListScreen extends StatelessWidget {
  const ProgramListScreen({super.key, required this.repository});

  final MasterDataRepository repository;

  @override
  Widget build(BuildContext context) {
    return MasterDataCrudScreen<Program>(
      title: 'Programs',
      entityKey: 'program',
      icon: Icons.school_outlined,
      addTooltip: 'Add program',
      emptyText: 'No programs yet. Use + to add one.',
      idOf: (p) => p.id!,
      titleOf: (p) => p.name ?? 'Unknown',
      subtitleOf: (p) => <String?>[p.code, p.duration, p.department?.name]
          .where((s) => s != null && s.isNotEmpty)
          .join(' · '),
      fetch: repository.getPrograms,
      create: (context) => showProgramForm(context, repository),
      edit: (context, item) =>
          showProgramForm(context, repository, initial: item),
      remove: (item) => repository.deleteProgram(item.id!),
    );
  }
}