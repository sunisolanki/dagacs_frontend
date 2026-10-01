import 'package:flutter/material.dart';

import '../../core/context/hod_academic_context.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme/dagacs_theme.dart';
import '../../models/hod_rollup.dart';
import '../../network/api_exception.dart';
import '../../repositories/hod_repository.dart';
import '../../widgets/hod/hod_common.dart';
import '../../widgets/hod/hod_scaffold.dart';

/// Monthly and quarterly attendance rollups, migrated from the previous HOD
/// dashboard's "Rollups" tab onto its own route.
///
/// Only `monthly` and `quarterly` are offered, exactly as before: the backend
/// does not accept a semester rollup type. A later phase folds this view into
/// the Reports route.
class HodRollupsScreen extends StatefulWidget {
  const HodRollupsScreen({
    super.key,
    required this.hodRepository,
    required this.session,
    required this.academicContext,
  });

  final HodRepository hodRepository;
  final SessionController session;
  final HodAcademicContext academicContext;

  @override
  State<HodRollupsScreen> createState() => _HodRollupsScreenState();
}

class _HodRollupsScreenState extends State<HodRollupsScreen> {
  String _rollupType = 'monthly';
  bool _loading = true;
  String? _error;
  List<HodRollup> _rollups = [];

  @override
  void initState() {
    super.initState();
    _fetchRollups();
  }

  Future<void> _fetchRollups() async {
    if (widget.academicContext.datesInvalid) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.hodRepository.getRollups(
        type: _rollupType,
        startDate: widget.academicContext.startDate,
        endDate: widget.academicContext.endDate,
      );
      if (!mounted) return;
      setState(() {
        _rollups = data;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _messageFor(e);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load attendance rollups.';
        _loading = false;
      });
    }
  }

  void _selectType(String type) {
    if (type == _rollupType) return;
    setState(() => _rollupType = type);
    _fetchRollups();
  }

  String _messageFor(ApiException e) {
    switch (e.statusCode) {
      case 401:
        return 'Session expired. Please sign in again.';
      case -1:
        return 'Network error. Check your connection and retry.';
      default:
        return e.message;
    }
  }

  @override
  Widget build(BuildContext context) {
    return HodScaffold(
      session: widget.session,
      academicContext: widget.academicContext,
      title: 'Rollups',
      subtitle: 'Monthly and quarterly attendance rollups.',
      icon: Icons.timeline_outlined,
      onRangeChanged: _fetchRollups,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DagacsSpace.md,
              DagacsSpace.sm,
              DagacsSpace.md,
              DagacsSpace.sm,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<String>(
                key: const Key('rollup-type-selector'),
                segments: const [
                  ButtonSegment(value: 'monthly', label: Text('Monthly')),
                  ButtonSegment(value: 'quarterly', label: Text('Quarterly')),
                ],
                selected: {_rollupType},
                onSelectionChanged: (values) => _selectType(values.first),
              ),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return HodErrorView(message: _error!, onRetry: _fetchRollups);
    }
    if (_rollups.isEmpty) {
      return const Center(child: Text('No rollup data for this period.'));
    }
    return ListView.builder(
      key: const Key('hod-list'),
      padding: const EdgeInsets.only(bottom: DagacsSpace.lg),
      itemCount: _rollups.length,
      itemBuilder: (context, index) {
        final r = _rollups[index];
        return ListTile(
          leading: const Icon(Icons.date_range),
          title: Text(r.period),
          subtitle: Text('${r.presentCount} / ${r.totalRecordedCount} recorded'),
          trailing: Text(
            formatHodPercentage(r.percentage),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: hodPercentageColor(r.percentage),
                ),
          ),
        );
      },
    );
  }
}
