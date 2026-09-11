import 'package:flutter/material.dart';

import '../../models/academic_session.dart';
import '../../models/program.dart';
import '../../models/subject_offering.dart';
import '../../repositories/master_data_repository.dart';
import 'master_data_crud_screen.dart';
import 'subject_offering_form.dart';

class SubjectOfferingListScreen extends StatefulWidget {
  const SubjectOfferingListScreen({super.key, required this.repository});

  final MasterDataRepository repository;

  @override
  State<SubjectOfferingListScreen> createState() =>
      _SubjectOfferingListScreenState();
}

class _SubjectOfferingListScreenState extends State<SubjectOfferingListScreen> {
  Map<int, AcademicSession> _sessionsById = const {};
  Map<int, Program> _programsById = const {};

  @override
  void initState() {
    super.initState();
    _loadReference();
  }

  Future<void> _loadReference() async {
    try {
      final results = await Future.wait([
        widget.repository.getAcademicSessions(),
        widget.repository.getPrograms(),
      ]);
      if (!mounted) return;
      setState(() {
        _sessionsById = {
          for (final session in results[0] as List<AcademicSession>)
            if (session.id != null) session.id!: session,
        };
        _programsById = {
          for (final program in results[1] as List<Program>)
            if (program.id != null) program.id!: program,
        };
      });
    } catch (_) {
      // Reference data is best-effort; the list stays fully usable and the
      // contextual label degrades to explicit "* unavailable" markers.
    }
  }

  String? _contextOf(SubjectOffering offering) {
    final shallow = offering.semester?.academicSession;
    if (shallow == null) return null;
    final session = _sessionsById[shallow.id] ?? shallow;
    return academicSessionContextLabel(session, programsById: _programsById);
  }

  @override
  Widget build(BuildContext context) {
    return MasterDataCrudScreen<SubjectOffering>(
      title: 'Subject Offerings',
      entityKey: 'subject-offering',
      icon: Icons.merge_type_outlined,
      addTooltip: 'Add subject offering',
      emptyText: 'No subject offerings yet. Use + to map one.',
      idOf: (o) => o.id!,
      titleOf: (o) => o.subject?.name ?? 'Unknown',
      subtitleOf: (o) => <String?>[
        o.subject?.code,
        _contextOf(o),
        o.semester?.name,
      ].where((v) => v != null && v.isNotEmpty).join(' · '),
      fetch: widget.repository.getSubjectOfferings,
      create: (context) =>
          showSubjectOfferingForm(context, widget.repository),
      edit: (context, item) =>
          showSubjectOfferingForm(context, widget.repository, initial: item),
      remove: (item) => widget.repository.deleteSubjectOffering(item.id!),
    );
  }
}