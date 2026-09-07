import 'package:dagacs_frontend/models/attendance_session.dart';
import 'package:dagacs_frontend/network/api_exception.dart';
import 'package:dagacs_frontend/repositories/attendance_repository.dart';
import 'package:dagacs_frontend/screens/attendance_session_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAttendanceRepository extends AttendanceRepository {
  _FakeAttendanceRepository();
  Future<List<AttendanceSession>> Function()? onGetSessions;

  @override
  Future<List<AttendanceSession>> getSessions() =>
      onGetSessions != null ? onGetSessions!() : super.getSessions();
}

void main() {
  testWidgets('shows loading then empty state', (tester) async {
    final repo = _FakeAttendanceRepository()
      ..onGetSessions = () async => [];
    await tester.pumpWidget(MaterialApp(
        home: AttendanceSessionListScreen(attendanceRepository: repo)));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('No attendance sessions yet.'), findsOneWidget);
  });

  testWidgets('shows error on failure', (tester) async {
    final repo = _FakeAttendanceRepository()
      ..onGetSessions = () async => throw const ApiException.network();
    await tester.pumpWidget(MaterialApp(
        home: AttendanceSessionListScreen(attendanceRepository: repo)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Network error'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('displays sessions with subject and status', (tester) async {
    final repo = _FakeAttendanceRepository()
      ..onGetSessions = () async => [
            const AttendanceSession(
                id: 1,
                subjectName: 'Data Structures',
                sectionName: 'CS-A',
                date: '2026-09-04',
                lecturePeriod: '1st',
                status: 'SCHEDULED'),
          ];
    await tester.pumpWidget(MaterialApp(
        home: AttendanceSessionListScreen(attendanceRepository: repo)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Data Structures'), findsOneWidget);
    expect(find.text('SCHEDULED'), findsOneWidget);
  });

  testWidgets('FAB navigates to create session', (tester) async {
    final repo = _FakeAttendanceRepository()
      ..onGetSessions = () async => [];
    await tester.pumpWidget(MaterialApp(
        home: AttendanceSessionListScreen(attendanceRepository: repo)));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}
