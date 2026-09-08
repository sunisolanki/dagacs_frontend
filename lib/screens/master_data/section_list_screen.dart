import 'package:flutter/material.dart';

import '../../models/section.dart';
import '../../repositories/master_data_repository.dart';
import 'master_data_crud_screen.dart';
import 'section_form.dart';

class SectionListScreen extends StatelessWidget {
  const SectionListScreen({super.key, required this.repository});

  final MasterDataRepository repository;

  @override
  Widget build(BuildContext context) {
    return MasterDataCrudScreen<Section>(
      title: 'Sections',
      entityKey: 'section',
      icon: Icons.view_agenda_outlined,
      addTooltip: 'Add section',
      emptyText: 'No sections yet. Use + to add one.',
      idOf: (s) => s.id!,
      titleOf: (s) => s.name ?? 'Unknown',
      subtitleOf: (s) =>
          <String?>[s.sectionCode, s.maxCapacity?.toString(), s.batch?.name]
              .where((v) => v != null && v.isNotEmpty)
              .join(' · '),
      fetch: repository.getSections,
      create: (context) => showSectionForm(context, repository),
      edit: (context, item) => showSectionForm(context, repository, initial: item),
      remove: (item) => repository.deleteSection(item.id!),
    );
  }
}