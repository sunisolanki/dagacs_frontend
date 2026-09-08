import 'package:flutter/material.dart';

import '../../models/batch.dart';
import '../../repositories/master_data_repository.dart';
import 'batch_form.dart';
import 'master_data_crud_screen.dart';

class BatchListScreen extends StatelessWidget {
  const BatchListScreen({super.key, required this.repository});

  final MasterDataRepository repository;

  @override
  Widget build(BuildContext context) {
    return MasterDataCrudScreen<Batch>(
      title: 'Batches',
      entityKey: 'batch',
      icon: Icons.groups_outlined,
      addTooltip: 'Add batch',
      emptyText: 'No batches yet. Use + to add one.',
      idOf: (b) => b.id!,
      titleOf: (b) => b.name ?? 'Unknown',
      subtitleOf: (b) =>
          <String?>[b.batchCode, b.year?.toString(), b.program, b.academicSession?.name]
              .where((v) => v != null && v.isNotEmpty)
              .join(' · '),
      fetch: repository.getBatches,
      create: (context) => showBatchForm(context, repository),
      edit: (context, item) => showBatchForm(context, repository, initial: item),
      remove: (item) => repository.deleteBatch(item.id!),
    );
  }
}