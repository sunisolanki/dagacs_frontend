import 'package:flutter/material.dart';

import '../../models/academic_session.dart';
import '../../models/program.dart';
import '../../network/api_exception.dart';
import '../../repositories/master_data_repository.dart';
import '../../widgets/dagacs_widgets.dart';

/// Opens the create/edit dialog for a [AcademicSession]. Programs are loaded
/// from the live repository for the required parent dropdown.
Future<AcademicSession?> showAcademicSessionForm(
  BuildContext context,
  MasterDataRepository repository, {
  AcademicSession? initial,
}) {
  return showDialog<AcademicSession>(
    context: context,
    builder: (_) => _AcademicSessionFormDialog(
      repository: repository,
      initial: initial,
    ),
  );
}

class _AcademicSessionFormDialog extends StatefulWidget {
  const _AcademicSessionFormDialog({required this.repository, this.initial});

  final MasterDataRepository repository;
  final AcademicSession? initial;

  @override
  State<_AcademicSessionFormDialog> createState() =>
      _AcademicSessionFormDialogState();
}

class _AcademicSessionFormDialogState extends State<_AcademicSessionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name =
      TextEditingController(text: widget.initial?.name ?? '');
  late final TextEditingController _code =
      TextEditingController(text: widget.initial?.code ?? '');
  late final TextEditingController _description =
      TextEditingController(text: widget.initial?.description ?? '');

  int? _programId;

  bool _loadingReferences = true;
  String? _referencesError;
  bool _submitting = false;
  String? _submitError;

  List<Program> _programs = const [];

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    _loadReferences();
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _loadReferences() async {
    setState(() {
      _loadingReferences = true;
      _referencesError = null;
    });
    try {
      final programs = await widget.repository.getPrograms();
      if (!mounted) return;
      setState(() {
        _programs = programs;
        _programId = widget.initial?.program?.id ??
            widget.initial?.programId ??
            programs.firstOrNull?.id;
        _loadingReferences = false;
      });
    } on ApiException {
      if (!mounted) return;
      setState(() {
        _referencesError = 'Could not load Program reference data.';
        _loadingReferences = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _referencesError = 'Could not load Program reference data.';
        _loadingReferences = false;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_programId == null) return;
    final request = AcademicSessionRequest(
      name: _name.text.trim(),
      code: _code.text.trim(),
      programId: _programId!,
      description: _description.text.trim().isEmpty
          ? null
          : _description.text.trim(),
    );
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final result = _isEdit
          ? await widget.repository
              .updateAcademicSession(widget.initial!.id!, request)
          : await widget.repository.createAcademicSession(request);
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
      return const SizedBox(
          height: 240, child: Center(child: CircularProgressIndicator()));
    }
    if (_referencesError != null) {
      return SizedBox(
        height: 240,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_referencesError!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                    onPressed: _loadReferences, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isEdit ? 'Edit Academic Session' : 'Add Academic Session',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          AppFormTextField(
            key: const Key('field-name'),
            label: 'Name',
            controller: _name,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Name is required' : null,
          ),
          AppFormTextField(
            key: const Key('field-code'),
            label: 'Code',
            controller: _code,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Code is required' : null,
          ),
          AppFormDropdown<int>(
            key: const Key('field-program'),
            label: 'Program',
            value: _programId,
            items: _programs
                .where((p) => p.id != null)
                .map((p) =>
                    DropdownMenuItem(value: p.id, child: Text(p.name ?? 'Unknown')))
                .toList(),
            onChanged: (v) => setState(() => _programId = v),
            validator: (v) => v == null ? 'Program is required' : null,
          ),
          AppFormTextField(
            key: const Key('field-description'),
            label: 'Description (optional)',
            controller: _description,
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
            submitKey: 'submit-academic-session',
            submitLabel: _isEdit ? 'Save Changes' : 'Create',
          ),
        ],
      ),
    );
  }
}