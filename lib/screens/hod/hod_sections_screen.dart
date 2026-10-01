import 'package:flutter/material.dart';

import '../../core/context/hod_academic_context.dart';
import '../../core/session/session_controller.dart';
import '../../models/hod_section_attendance.dart';
import '../../network/api_exception.dart';
import '../../repositories/hod_repository.dart';
import '../../services/hod_hierarchy_loader.dart';
import '../../widgets/hod/hod_common.dart';
import '../../widgets/hod/hod_scaffold.dart';

/// Section-wise attendance, migrated from the previous HOD dashboard's
/// "Sections" tab onto its own route.
///
/// The data source, the date filter and the loading/error/empty behaviour are
/// unchanged; only the presentation shell is new.
class HodSectionsScreen extends StatefulWidget {
  const HodSectionsScreen({
    super.key,
    required this.hodRepository,
    required this.session,
    required this.academicContext,
    this.hierarchyLoader,
  });

  final HodRepository hodRepository;
  final SessionController session;
  final HodAcademicContext academicContext;

  /// Supplies the real academic hierarchy to the context bar.
  final HodHierarchyLoader? hierarchyLoader;

  @override
  State<HodSectionsScreen> createState() => _HodSectionsScreenState();
}

class _HodSectionsScreenState extends State<HodSectionsScreen> {
  static const String _errorCopy = 'Failed to load data.';

  bool _loading = true;
  String? _error;
  List<HodSectionAttendance> _sections = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.academicContext.datesInvalid) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ctx = widget.academicContext;
      final data = await widget.hodRepository.getSections(
        startDate: ctx.startDate,
        endDate: ctx.endDate,
        academicSessionId: ctx.academicSessionId,
        programId: ctx.programId,
        semesterId: ctx.semesterId,
        sectionId: ctx.sectionId,
      );
      if (!mounted) return;
      setState(() {
        _sections = data;
        _loading = false;
      });
    } on ApiException {
      if (!mounted) return;
      setState(() {
        _error = _errorCopy;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = _errorCopy;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return HodScaffold(
      session: widget.session,
      academicContext: widget.academicContext,
      title: 'Sections',
      subtitle: 'Section-wise attendance across your department.',
      icon: Icons.meeting_room_outlined,
      onRangeChanged: _load,
      hierarchyLoader: widget.hierarchyLoader,
      onContextChanged: _load,
      body: HodListPanel(
        loading: _loading,
        errorMessage: _error,
        onRetry: _load,
        emptyMessage: 'No section data yet.',
        loadingMessage: 'Loading sections...',
        showScopeNotice:
            !widget.academicContext.hasAcademicContext,
        itemCount: _sections.length,
        itemBuilder: (context, index) {
          final s = _sections[index];
          return ListTile(
            leading: const Icon(Icons.meeting_room),
            title: Text('${s.sectionName} (${s.sectionCode})'),
            subtitle: Text(s.hasAcademicContext
                ? '${s.studentCount} students · ${s.programName} · '
                    '${s.semesterName} · ${s.academicSessionName}'
                : '${s.studentCount} students'),
            trailing: Text(
              formatHodPercentage(s.percentage),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: hodPercentageColor(s.percentage),
                  ),
            ),
          );
        },
      ),
    );
  }
}
