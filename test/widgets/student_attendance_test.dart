import 'package:dagacs_frontend/models/attendance_percentage.dart';
import 'package:dagacs_frontend/models/attendance_record.dart';
import 'package:dagacs_frontend/network/api_exception.dart';
import 'package:dagacs_frontend/repositories/attendance_repository.dart';
import 'package:dagacs_frontend/screens/student_attendance_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAttendanceRepository extends AttendanceRepository {
  _FakeAttendanceRepository();
  Future<List<AttendanceRecord>> Function()? onGetMyAttendance;
  Future<AttendancePercentage> Function()? onGetOverall;
  Future<AttendancePercentage> Function(int subjectId)? onGetSubject;

  @override
  Future<List<AttendanceRecord>> getMyAttendance() =>
      onGetMyAttendance != null
          ? onGetMyAttendance!()
          : super.getMyAttendance();

  @override
  Future<AttendancePercentage> getOverallAttendanceCalculation(
          {DateTime? startDate, DateTime? endDate}) =>
      onGetOverall != null
          ? onGetOverall!()
          : Future.value(const AttendancePercentage(
              presentCount: 0, totalRecordedCount: 0));

  @override
  Future<AttendancePercentage> getSubjectAttendanceCalculation(
          int subjectId,
          {DateTime? startDate, DateTime? endDate}) =>
      onGetSubject != null
          ? onGetSubject!(subjectId)
          : Future.value(const AttendancePercentage(
              presentCount: 0, totalRecordedCount: 0));
}

void main() {
  testWidgets('shows loading then empty state', (tester) async {
    final repo = _FakeAttendanceRepository()
      ..onGetMyAttendance = () async => [];
    await tester.pumpWidget(MaterialApp(
        home: StudentAttendanceScreen(attendanceRepository: repo)));
    // Loading state shown before async completes
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('No attendance records found.'), findsOneWidget);
  });

  testWidgets('shows empty state when no records', (tester) async {
    final repo = _FakeAttendanceRepository()
      ..onGetMyAttendance = () async => [];
    await tester.pumpWidget(MaterialApp(
        home: StudentAttendanceScreen(attendanceRepository: repo)));
    await tester.pumpAndSettle();
    expect(find.text('No attendance records found.'), findsOneWidget);
  });

  testWidgets('shows error on network failure', (tester) async {
    final repo = _FakeAttendanceRepository()
      ..onGetMyAttendance =
          () async => throw const ApiException.network();
    await tester.pumpWidget(MaterialApp(
        home: StudentAttendanceScreen(attendanceRepository: repo)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Network error'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('displays records with Present/Absent icons', (tester) async {
    final repo = _FakeAttendanceRepository()
      ..onGetMyAttendance = () async => [
            const AttendanceRecord(
                id: 1, subjectId: 5, status: 'PRESENT', isPresent: true,
                date: '2026-09-04', lecturePeriod: '1st'),
            const AttendanceRecord(
                id: 2, subjectId: 5, status: 'ABSENT', isPresent: false,
                date: '2026-09-04', lecturePeriod: '1st'),
          ];
    await tester.pumpWidget(MaterialApp(
        home: StudentAttendanceScreen(attendanceRepository: repo)));
    await tester.pumpAndSettle();
    expect(find.text('Present'), findsOneWidget);
    expect(find.text('Absent'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.byIcon(Icons.cancel), findsOneWidget);
  });
}
