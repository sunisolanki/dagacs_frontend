import 'package:flutter/material.dart';

import '../models/attendance_session_create_request.dart';
import '../network/api_exception.dart';
import '../repositories/attendance_repository.dart';
import '../core/theme/dagacs_theme.dart';
import '../widgets/dagacs_widgets.dart';

/// Form for creating a new attendance session.
///
/// KNOWN LIMITATION: The backend has no endpoint for listing a teacher's
/// assigned subjects or sections. The teacher must enter subject and
/// section IDs manually. This limitation will be resolved when a
/// teacher-assignments endpoint is added in a future milestone.
class CreateSessionScreen extends StatefulWidget {
  const CreateSessionScreen({super.key, required this.attendanceRepository});

  final AttendanceRepository attendanceRepository;

  @override
  State<CreateSessionScreen> createState() => _CreateSessionScreenState();
}

class _CreateSessionScreenState extends State<CreateSessionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectIdController = TextEditingController();
  final _sectionIdController = TextEditingController();
  final _lecturePeriodController = TextEditingController();
  final _dateController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _subjectIdController.dispose();
    _sectionIdController.dispose();
    _lecturePeriodController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) {
      setState(() {
        _dateController.text =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final subjectId = int.parse(_subjectIdController.text.trim());
      final sectionId = int.parse(_sectionIdController.text.trim());
      await widget.attendanceRepository.createSession(
        AttendanceSessionCreateRequest(
          subjectId: subjectId,
          sectionId: sectionId,
          lecturePeriod: _lecturePeriodController.text.trim(),
          date: _dateController.text.trim(),
        ),
      );
      if (!mounted) return;
      Navigator.pop(context);
    } on FormatException {
      if (!mounted) return;
      setState(() {
        _error = 'Subject ID and Section ID must be numbers.';
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = switch (e.statusCode) {
          400 => e.message.isNotEmpty ? e.message : 'Validation error.',
          403 =>
            'You are not assigned to this subject and section.',
          404 => 'Subject or section not found.',
          409 =>
            'A session already exists for this subject, section, date, and period.',
          -1 => kNetworkErrorMessage,
          _ => e.statusCode >= 500 ? kServerErrorMessage : e.message,
        };
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to create session. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Session')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(DagacsSpace.lg),
        child: AppConstrainedMax(
          maxWidth: 640,
          child: Form(
            key: _formKey,
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AppPageHeader(
                    icon: Icons.event_available_outlined,
                    title: 'Create attendance session',
                    subtitle: 'Record a class before marking attendance.',
                  ),
                  Container(
                    padding: const EdgeInsets.all(DagacsSpace.md),
                    decoration: BoxDecoration(
                      color: DagacsColors.infoBg,
                      borderRadius: BorderRadius.circular(DagacsRadius.md),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: DagacsColors.info),
                        SizedBox(width: DagacsSpace.sm),
                        Expanded(
                          child: Text(
                            'Subject and section selection requires a teaching-assignment API, which is not available in this app. Enter subject and section IDs supplied by your administrator.',
                            style: TextStyle(fontSize: 13, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: DagacsSpace.xl),
                  AppFormTextField(
                    label: 'Subject ID',
                    controller: _subjectIdController,
                    keyboardType: TextInputType.number,
                    prefixIcon: Icons.book_outlined,
                    validator: _idValidator('Subject ID'),
                  ),
                  AppFormTextField(
                    label: 'Section ID',
                    controller: _sectionIdController,
                    keyboardType: TextInputType.number,
                    prefixIcon: Icons.groups_outlined,
                    validator: _idValidator('Section ID'),
                  ),
                  AppFormTextField(
                    label: 'Lecture period',
                    controller: _lecturePeriodController,
                    hintText: 'For example, 1st Period',
                    prefixIcon: Icons.schedule_outlined,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Lecture period is required'
                        : null,
                  ),
                  AppFormTextField(
                    label: 'Date',
                    controller: _dateController,
                    hintText: 'YYYY-MM-DD',
                    prefixIcon: Icons.calendar_today_outlined,
                    suffixIcon: IconButton(
                      tooltip: 'Choose date',
                      icon: const Icon(Icons.calendar_month_outlined),
                      onPressed: _pickDate,
                    ),
                    onTap: _pickDate,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Date is required'
                        : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: DagacsSpace.xs),
                    Text(_error!,
                        style: const TextStyle(
                            color: DagacsColors.error, fontSize: 13)),
                  ],
                  const SizedBox(height: DagacsSpace.lg),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.add_task_outlined),
                          const SizedBox(width: DagacsSpace.sm),
                          Text(_isLoading ? 'Creating…' : 'Create session'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? Function(String?) _idValidator(String field) => (value) {
        if (value == null || value.trim().isEmpty) return '$field is required';
        if (int.tryParse(value.trim()) == null) return '$field must be a number';
        return null;
      };
}
