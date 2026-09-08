import 'package:flutter/material.dart';

import '../../models/batch.dart';
import '../../models/section.dart';
import '../../network/api_exception.dart';
import '../../repositories/master_data_repository.dart';
import '../../widgets/dagacs_widgets.dart';

/// Opens the create/edit dialog for a [Section]. Batches are loaded from the
/// live repository for the required parent dropdown.
Future<Section?> showSectionForm(
  BuildContext context,
  MasterDataRepository repository, {
  Section? initial,
}) {
  return showDialog<Section>(
    context: context,
    builder: (_) => _SectionFormDialog(
      repository: repository,
      initial: initial,
    ),
  );
}

class _SectionFormDialog extends StatefulWidget {
  const _SectionFormDialog({required this.repository, this.initial});

  final MasterDataRepository repository;
  final Section? initial;

  @override
  State<_SectionFormDialog> createState() => _SectionFormDialogState();
}

class _SectionFormDialogState extends State<_SectionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _sectionCode =
      TextEditingController(text: widget.initial?.sectionCode ?? '');
  late final TextEditingController _name =
      TextEditingController(text: widget.initial?.name ?? '');
  late final TextEditingController _maxCapacity =
      TextEditingController(
          text: widget.initial?.maxCapacity?.toString() ?? '');

  int? _batchId;

  bool _loadingReferences = true;
  String? _referencesError;
  bool _submitting = false;
  String? _submitError;

  List<Batch> _batches = const [];

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    _loadReferences();
  }

  @override
  void dispose() {
    _sectionCode.dispose();
    _name.dispose();
    _maxCapacity.dispose();
    super.dispose();
  }

  Future<void> _loadReferences() async {
    setState(() {
      _loadingReferences = true;
      _referencesError = null;
    });
    try {
      final batches = await widget.repository.getBatches();
      if (!mounted) return;
      setState(() {
        _batches = batches;
        _batchId = widget.initial?.batch?.id ??
            widget.initial?.batchId ??
            batches.firstOrNull?.id;
        _loadingReferences = false;
      });
    } on ApiException {
      if (!mounted) return;
      setState(() {
        _referencesError = 'Could not load Batch reference data.';
        _loadingReferences = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _referencesError = 'Could not load Batch reference data.';
        _loadingReferences = false;
      });
    }
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
    final request = SectionRequest(
      sectionCode: _sectionCode.text.trim(),
      name: _name.text.trim(),
      maxCapacity: int.parse(_maxCapacity.text.trim()),
      batchId: _batchId!,
    );
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final result = _isEdit
          ? await widget.repository
              .updateSection(widget.initial!.id!, request)
          : await widget.repository.createSection(request);
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
            _isEdit ? 'Edit Section' : 'Add Section',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          AppFormTextField(
            key: const Key('field-sectionCode'),
            label: 'Section Code',
            controller: _sectionCode,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Section code is required'
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
            key: const Key('field-maxCapacity'),
            label: 'Max capacity',
            controller: _maxCapacity,
            keyboardType: TextInputType.number,
            validator: _capacityValidator,
          ),
          AppFormDropdown<int>(
            key: const Key('field-batch'),
            label: 'Batch',
            value: _batchId,
            items: _batches
                .where((b) => b.id != null)
                .map((b) =>
                    DropdownMenuItem(value: b.id, child: Text(b.name ?? 'Unknown')))
                .toList(),
            onChanged: (v) => setState(() => _batchId = v),
            validator: (v) => v == null ? 'Batch is required' : null,
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
            submitKey: 'submit-section',
            submitLabel: _isEdit ? 'Save Changes' : 'Create',
          ),
        ],
      ),
    );
  }
}