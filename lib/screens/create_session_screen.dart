import 'package:flutter/material.dart';

import '../models/attendance_session_create_request.dart';
import '../network/api_exception.dart';
import '../repositories/attendance_repository.dart';

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
          -1 => 'Network error. Check your connection and try again.',
          _ => e.message,
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
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.5),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Enter subject and section IDs manually. These can be '
                    'found from existing session data or admin records.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _subjectIdController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Subject ID',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Subject ID is required';
                  }
                  if (int.tryParse(v.trim()) == null) {
                    return 'Must be a number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _sectionIdController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Section ID',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Section ID is required';
                  }
                  if (int.tryParse(v.trim()) == null) {
                    return 'Must be a number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _lecturePeriodController,
                decoration: const InputDecoration(
                  labelText: 'Lecture Period',
                  hintText: 'e.g. 1st Period',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Lecture period is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dateController,
                onTap: _pickDate,
                decoration: const InputDecoration(
                  labelText: 'Date',
                  hintText: 'YYYY-MM-DD',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Date is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_error!,
                      style: const TextStyle(color: Colors.red, fontSize: 13)),
                ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create Session'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
