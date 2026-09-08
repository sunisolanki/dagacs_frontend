import 'package:flutter/material.dart';

import '../../models/department.dart';
import '../../repositories/master_data_repository.dart';
import 'department_form.dart';
import 'master_data_crud_screen.dart';

class DepartmentListScreen extends StatelessWidget {
  const DepartmentListScreen({super.key, required this.repository});

  final MasterDataRepository repository;

  @override
  Widget build(BuildContext context) {
    return MasterDataCrudScreen<Department>(
      title: 'Departments',
      entityKey: 'department',
      icon: Icons.account_balance_outlined,
      addTooltip: 'Add department',
      emptyText: 'No departments yet. Use + to add one.',
      idOf: (d) => d.id!,
      titleOf: (d) => d.name ?? 'Unknown',
      subtitleOf: (d) => <String?>[d.code, d.description]
          .where((s) => s != null && s.isNotEmpty)
          .join(' · '),
      fetch: repository.getDepartments,
      create: (context) => showDepartmentForm(context, repository),
      edit: (context, item) =>
          showDepartmentForm(context, repository, initial: item),
      remove: (item) => repository.deleteDepartment(item.id!),
    );
  }
}