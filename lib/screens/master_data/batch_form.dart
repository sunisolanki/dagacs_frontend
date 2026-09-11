import 'package:flutter/material.dart';

import '../../models/academic_session.dart';
import '../../models/batch.dart';
import '../../models/program.dart';
import '../../network/api_exception.dart';
import '../../repositories/master_data_repository.dart';
import '../../widgets/dagacs_widgets.dart';

/// Opens the create/edit dialog for a [Batch]. Academic sessions are loaded
/// from the live repository for the required parent dropdown.
Future<Batch?> showBatchForm(
  BuildContext context,
  MasterDataRepository repository, {
  Batch? initial,
}) {
  return showDialog<Batch>(
    context: context,
    builder: (_) => _BatchFormDialog(
      repository: repository,
      initial: initial,
    ),
  );
}

class _BatchFormDialog extends StatefulWidget {
  const _BatchFormDialog({required this.repository, this.initial});

  final MasterDataRepository repository;
  final Batch? initial;

  @override
  State<_BatchFormDialog> createState() => _BatchFormDialogState();
}

class _BatchFormDialogState extends State<_BatchFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _batchCode =
      TextEditingController(text: widget.initial?.batchCode ?? '');
  late final TextEditingController _name =
      TextEditingController(text: widget.initial?.name ?? '');
  late final TextEditingController _year =
      TextEditingController(text: widget.initial?.year?.toString() ?? '');
  late final TextEditingController _maxCapacity =
      TextEditingController(
          text: widget.initial?.maxCapacity?.toString() ?? '');

  int? _academicSessionId;

  bool _loadingReferences = true;
  String? _referencesError;
  bool _submitting = false;
  String? _submitError;

  List<AcademicSession> _sessions = const [];
  Map<int, Program> _programsById = const {};

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    _loadReferences();
  }

  @override
  void dispose() {
    _batchCode.dispose();
    _name.dispose();
    _year.dispose();
    _maxCapacity.dispose();
    super.dispose();
  }

  Future<void> _loadReferences() async {
    setState(() {
      _loadingReferences = true;
      _referencesError = null;
    });
    try {
      final results = await Future.wait([
        widget.repository.getAcademicSessions(),
        widget.repository.getPrograms(),
      ]);
      if (!mounted) return;
      setState(() {
        _sessions = results[0] as List<AcademicSession>;
        _programsById = {
          for (final program in results[1] as List<Program>)
            if (program.id != null) program.id!: program,
        };
        _academicSessionId = widget.initial?.academicSession?.id ??
            widget.initial?.academicSessionId ??
            _sessions.firstOrNull?.id;
        _loadingReferences = false;
      });
    } on ApiException {
      if (!mounted) return;
      setState(() {
        _referencesError = 'Could not load Academic Session reference data.';
        _loadingReferences = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _referencesError = 'Could not load Academic Session reference data.';
        _loadingReferences = false;
      });
    }
  }

  String _sessionLabel(AcademicSession s) =>
      academicSessionContextLabel(s, programsById: _programsById);

  String? _yearValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Admission year is required';
    final parsed = int.tryParse(v.trim());
    if (parsed == null) return 'Admission year must be a number';
    if (parsed < 2000 || parsed > 2100) return 'Enter a valid admission year';
    return null;
  }

  String? _capacityValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Max capacity is required';
    final parsed = int.tryParse(v.trim());
    if (parsed == null) return 'Max capacity must be a number';
    if (parsed <= 0) return 'Max capacity must be positive';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final request = BatchRequest(
      batchCode: _batchCode.text.trim(),
      name: _name.text.trim(),
      year: int.parse(_year.text.trim()),
      academicSessionId: _academicSessionId!,
      maxCapacity: int.parse(_maxCapacity.text.trim()),
    );
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final result = _isEdit
          ? await widget.repository.updateBatch(widget.initial!.id!, request)
          : await widget.repository.createBatch(request);
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = userMessageFor(e);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = 'Something went wrong while saving. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDialogFrame(child: _buildContent());
  }

  Widget _buildContent() {
    if (_loadingReferences) {
      return SizedBox(
          height: 240,
          child: AppLoadingState(
              message: 'Loading Academic Session reference data...'));
    }
    if (_referencesError != null) {
      return SizedBox(
        height: 240,
        child: AppErrorState(
            message: _referencesError!, onRetry: _loadReferences),
      );
    }
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isEdit ? 'Edit Batch' : 'Add Batch',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          AppFormTextField(
            key: const Key('field-batchCode'),
            label: 'Batch Code',
            controller: _batchCode,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Batch code is required'
                : null,
          ),
          AppFormTextField(
            key: const Key('field-name'),
            label: 'Name',
            controller: _name,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Name is required' : null,
          ),
          AppFormTextField(
            key: const Key('field-year'),
            label: 'Admission Year (e.g. 2026)',
            controller: _year,
            keyboardType: TextInputType.number,
            validator: _yearValidator,
          ),
          AppFormTextField(
            key: const Key('field-maxCapacity'),
            label: 'Max capacity',
            controller: _maxCapacity,
            keyboardType: TextInputType.number,
            validator: _capacityValidator,
          ),
          AppFormDropdown<int>(
            key: const Key('field-academic-session'),
            label: 'Academic Session',
            value: _academicSessionId,
            items: _sessions
                .where((s) => s.id != null)
                .map((s) => DropdownMenuItem(
                      value: s.id,
                      child: Text(
                        _sessionLabel(s),
                        maxLines: 2,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _academicSessionId = v),
            validator: (v) => v == null ? 'Academic Session is required' : null,
          ),
          if (_submitError != null) ...[
            const SizedBox(height: 12),
            Text(
              _submitError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 8),
          AppFormActions(
            onCancel: () => Navigator.of(context).pop(),
            onSubmit: _submit,
            submitting: _submitting,
            submitKey: 'submit-batch',
            submitLabel: _isEdit ? 'Save Changes' : 'Create',
          ),
        ],
      ),
    );
  }
}