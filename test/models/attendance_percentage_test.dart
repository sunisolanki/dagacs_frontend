import 'package:dagacs_frontend/models/attendance_percentage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AttendancePercentage', () {
    test('valid calculation JSON deserializes correctly', () {
      final p = AttendancePercentage.fromJson({
        'presentCount': 5,
        'totalRecordedCount': 8,
        'percentage': 62.5,
      });
      expect(p.presentCount, 5);
      expect(p.totalRecordedCount, 8);
      expect(p.percentage, 62.5);
    });

    test('presentCount is preserved', () {
      final p = AttendancePercentage.fromJson({
        'presentCount': 10,
        'totalRecordedCount': 10,
        'percentage': 100.0,
      });
      expect(p.presentCount, 10);
    });

    test('totalRecordedCount is preserved', () {
      final p = AttendancePercentage.fromJson({
        'presentCount': 0,
        'totalRecordedCount': 10,
        'percentage': 0.0,
      });
      expect(p.totalRecordedCount, 10);
    });

    test('percentage is correctly deserialized (fractional)', () {
      final p = AttendancePercentage.fromJson({
        'presentCount': 5,
        'totalRecordedCount': 8,
        'percentage': 62.5,
      });
      expect(p.percentage, 62.5);
    });

    test('percentage is correctly deserialized (integral double)', () {
      final p = AttendancePercentage.fromJson({
        'presentCount': 10,
        'totalRecordedCount': 10,
        'percentage': 100.0,
      });
      expect(p.percentage, 100.0);
    });

    test('percentage null remains null for zero records', () {
      final p = AttendancePercentage.fromJson({
        'presentCount': 0,
        'totalRecordedCount': 0,
        'percentage': null,
      });
      expect(p.presentCount, 0);
      expect(p.totalRecordedCount, 0);
      expect(p.percentage, isNull);
    });

    test('percentage is NOT coerced to 0 when null', () {
      final p = AttendancePercentage.fromJson({
        'presentCount': 0,
        'totalRecordedCount': 0,
        'percentage': null,
      });
      expect(p.percentage, isNull);
      expect(p.percentage == 0, isFalse);
    });
  });
}
