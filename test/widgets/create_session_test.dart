import 'package:dagacs_frontend/models/attendance_session.dart';
import 'package:dagacs_frontend/models/attendance_session_create_request.dart';
import 'package:dagacs_frontend/network/api_exception.dart';
import 'package:dagacs_frontend/repositories/attendance_repository.dart';
import 'package:dagacs_frontend/screens/create_session_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAttendanceRepository extends AttendanceRepository {
  _FakeAttendanceRepository();
  Future<AttendanceSession> Function(AttendanceSessionCreateRequest)? onCreateSession;

  @override
  Future<AttendanceSession> createSession(AttendanceSessionCreateRequest request) =>
      onCreateSession != null ? onCreateSession!(request) : super.createSession(request);
}

void main() {
  testWidgets('shows validation errors for empty fields', (tester) async {
    final repo = _FakeAttendanceRepository();
    await tester.pumpWidget(MaterialApp(
        home: CreateSessionScreen(attendanceRepository: repo)));
    final submit = find.byType(ElevatedButton);
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    expect(find.text('Subject ID is required'), findsOneWidget);
    expect(find.text('Section ID is required'), findsOneWidget);
    expect(find.text('Lecture period is required'), findsOneWidget);
    expect(find.text('Date is required'), findsOneWidget);
  });

  testWidgets('shows error on 409 conflict', (tester) async {
    final repo = _FakeAttendanceRepository()
      ..onCreateSession = (_) async =>
          throw const ApiException(409, 'Session already exists');
    await tester.pumpWidget(MaterialApp(
        home: CreateSessionScreen(attendanceRepository: repo)));
    await tester.enterText(find.byType(TextFormField).at(0), '5');
    await tester.enterText(find.byType(TextFormField).at(1), '2');
    await tester.enterText(find.byType(TextFormField).at(2), '1st');
    await tester.enterText(find.byType(TextFormField).at(3), '2026-09-04');
    final submit = find.byType(ElevatedButton).last;
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.textContaining('session already exists'), findsOneWidget);
  });

  testWidgets('shows info note about manual ID entry', (tester) async {
    final repo = _FakeAttendanceRepository();
    await tester.pumpWidget(MaterialApp(
        home: CreateSessionScreen(attendanceRepository: repo)));
    expect(find.textContaining('Enter subject and section IDs'), findsOneWidget);
  });
}
