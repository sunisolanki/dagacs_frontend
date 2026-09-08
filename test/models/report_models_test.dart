import 'package:dagacs_frontend/models/hod_coverage_row.dart';
import 'package:dagacs_frontend/models/hod_daily_lecture_row.dart';
import 'package:dagacs_frontend/models/report_page.dart';
import 'package:dagacs_frontend/models/teacher_report_row.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HodDailyLectureRow', () {
    test('parses a populated M7.1 row', () {
      final row = HodDailyLectureRow.fromJson(const {
        'date': '2026-01-10',
        'lecturePeriod': 'LP1',
        'subjectCode': 'SUBJ-1',
        'subjectName': 'Data Structures',
        'sectionCode': 'SEC-A',
        'sectionName': 'Section A',
        'presentCount': 2,
        'totalRecordedCount': 3,
        'percentage': 66.66666,
      });
      expect(row.date, '2026-01-10');
      expect(row.lecturePeriod, 'LP1');
      expect(row.subjectCode, 'SUBJ-1');
      expect(row.subjectName, 'Data Structures');
      expect(row.sectionCode, 'SEC-A');
      expect(row.sectionName, 'Section A');
      expect(row.presentCount, 2);
      expect(row.totalRecordedCount, 3);
      expect(row.percentage, 66.66666);
    });

    test('null percentage parses to null (never 0)', () {
      final row = HodDailyLectureRow.fromJson(const {
        'date': '2026-01-10',
        'lecturePeriod': 'LP1',
        'presentCount': 0,
        'totalRecordedCount': 0,
        'percentage': null,
      });
      expect(row.percentage, isNull);
    });
  });

  group('HodCoverageRow', () {
    test('parses a populated coverage row', () {
      final row = HodCoverageRow.fromJson(const {
        'subjectCode': 'SUBJ-1',
        'subjectName': 'Data Structures',
        'sectionCode': 'SEC-A',
        'sectionName': 'Section A',
        'recordedDateCount': 4,
        'sessionCount': 6,
      });
      expect(row.subjectCode, 'SUBJ-1');
      expect(row.recordedDateCount, 4);
      expect(row.sessionCount, 6);
    });
  });

  group('TeacherReportRow', () {
    test('parses own subject-wise row and ignores ids', () {
      final row = TeacherReportRow.fromJson(const {
        'subjectId': 1,
        'subjectCode': 'DS',
        'subjectName': 'Data Structures',
        'sectionId': 2,
        'sectionCode': 'A',
        'sectionName': 'Section A',
        'presentCount': 5,
        'totalRecordedCount': 8,
        'percentage': 62.5,
      });
      expect(row.subjectCode, 'DS');
      expect(row.subjectName, 'Data Structures');
      expect(row.sectionCode, 'A');
      expect(row.sectionName, 'Section A');
      expect(row.presentCount, 5);
      expect(row.totalRecordedCount, 8);
      expect(row.percentage, 62.5);
    });
  });

  group('ReportPage', () {
    test('parses Spring page envelope with content, number and totalPages', () {
      final page = ReportPage<HodCoverageRow>.fromJson(
        {
          'content': [
            {
              'subjectCode': 'SUBJ-1',
              'subjectName': 'DS',
              'sectionCode': 'A',
              'sectionName': 'A',
              'recordedDateCount': 2,
              'sessionCount': 2,
            }
          ],
          'number': 3,
          'totalPages': 9,
        },
        HodCoverageRow.fromJson,
      );
      expect(page.items.length, 1);
      expect(page.items.first.subjectCode, 'SUBJ-1');
      expect(page.page, 3);
      expect(page.totalPages, 9);
    });

    test('empty content yields an empty items list', () {
      final page = ReportPage<HodCoverageRow>.fromJson(
        const {'content': <Object>[], 'number': 0, 'totalPages': 0},
        HodCoverageRow.fromJson,
      );
      expect(page.items, isEmpty);
      expect(page.page, 0);
      expect(page.totalPages, 0);
    });
  });
}