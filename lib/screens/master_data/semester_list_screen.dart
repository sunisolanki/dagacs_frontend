import 'package:flutter/material.dart';

import '../../models/academic_session.dart';
import '../../models/program.dart';
import '../../models/semester.dart';
import '../../repositories/master_data_repository.dart';
import 'master_data_crud_screen.dart';
import 'semester_form.dart';

class SemesterListScreen extends StatefulWidget {
  const SemesterListScreen({super.key, required this.repository});

  final MasterDataRepository repository;

  @override
  State<SemesterListScreen> createState() => _SemesterListScreenState();
}

class _SemesterListScreenState extends State<SemesterListScreen> {
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

  String? _contextOf(Semester semester) {
    final shallow = semester.academicSession;
    if (shallow == null) return null;
    final session = _sessionsById[shallow.id] ?? shallow;
    return academicSessionContextLabel(session, programsById: _programsById);
  }

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
      subtitleOf: (s) => <String?>[
        s.code,
        s.year?.toString(),
        _contextOf(s),
      ].where((v) => v != null && v.isNotEmpty).join(' · '),
      fetch: widget.repository.getSemesters,
      create: (context) => showSemesterForm(context, widget.repository),
      edit: (context, item) =>
          showSemesterForm(context, widget.repository, initial: item),
      remove: (item) => widget.repository.deleteSemester(item.id!),
    );
  }
}
