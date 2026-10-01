import 'package:dagacs_frontend/models/hod_attendance_context.dart';
import 'package:dagacs_frontend/models/hod_attendance_matrix.dart';
import 'package:dagacs_frontend/models/hod_attendance_overview.dart';
import 'package:dagacs_frontend/models/hod_low_attendance_report.dart';
import 'package:dagacs_frontend/models/hod_student_attendance_detail.dart';
import 'package:dagacs_frontend/models/hod_subject_attendance_detail.dart';
import 'package:flutter_test/flutter_test.dart';

/// Parsing contract of the Phase 3 HOD attendance payloads.
///
/// The backend omits null fields (`spring.jackson.default-property-inclusion:
/// non_null`), so an absent key must decode to `null` - that is how "no data"
/// reaches the UI instead of a fabricated zero.
void main() {
  group('HodAttendanceContext', () {
    test('decodes every level and marks the context complete', () {
      final context = HodAttendanceContext.fromJson({
        'academicSessionId': 1,
        'academicSessionName': 'Academic Session 2026-27',
        'programId': 2,
        'programName': 'B.Tech CSE',
        'semesterId': 3,
        'semesterName': 'Semester 3',
        'sectionId': 4,
        'sectionName': 'A',
        'complete': true,
      });

      expect(context.academicSessionId, 1);
      expect(context.programName, 'B.Tech CSE');
      expect(context.semesterName, 'Semester 3');
      expect(context.sectionName, 'A');
      expect(context.complete, isTrue);
      expect(context.label,
          'Academic Session 2026-27 · B.Tech CSE · Semester 3 · A');
    });

    test('a partial context is not complete and says so', () {
      final context = HodAttendanceContext.fromJson({
        'semesterId': 3,
        'semesterName': 'Semester 3',
      });

      expect(context.complete, isFalse);
      expect(context.academicSessionId, isNull);
      expect(context.label, 'Semester 3');
    });

    test('an empty payload decodes to the empty context', () {
      expect(HodAttendanceContext.fromJson(const {}).label,
          'No academic context selected');
      expect(HodAttendanceContext.empty.complete, isFalse);
    });
  });

  group('HodAttendanceMatrix', () {
    Map<String, dynamic> payload({bool withSecondSubject = true}) => {
          'context': {
            'academicSessionId': 1,
            'programId': 2,
            'semesterId': 3,
            'sectionId': 4,
            'complete': true,
          },
          'subjects': [
            {
              'subjectId': 101,
              'subjectOfferingId': 11,
              'subjectCode': 'CS301',
              'subjectName': 'Data Structures and Algorithms',
              'facultyNames': ['Dr Rao'],
            },
            if (withSecondSubject)
              {
                'subjectId': 102,
                'subjectOfferingId': 12,
                'subjectCode': 'CS302',
                'subjectName': 'Computer Networks',
                'facultyNames': <String>[],
              },
          ],
          'students': [
            {
              'studentId': 91,
              'enrollmentNumber': 'CS2025001',
              'rollNumber': 'R1',
              'studentName': 'Rahul',
              'sectionName': 'A',
              'subjects': [
                {'subjectId': 101, 'present': 32, 'total': 40, 'percentage': 80.0},
                {'subjectId': 102, 'present': 30, 'total': 35, 'percentage': 85.714},
              ],
              'totalPresent': 62,
              'totalClasses': 75,
              'overallPercentage': 82.6666,
            },
          ],
          'page': 0,
          'size': 50,
          'totalElements': 1,
          'totalPages': 1,
          'singleSubject': false,
          'thresholdPercentage': 75.0,
        };

    test('decodes the dynamic subject columns and their faculty', () {
      final matrix = HodAttendanceMatrix.fromJson(payload());

      expect(matrix.subjects.length, 2);
      expect(matrix.subjects.first.subjectId, 101);
      expect(matrix.subjects.first.subjectCode, 'CS301');
      expect(matrix.subjects.first.headerLabel, 'CS301');
      expect(matrix.subjects.first.fullLabel,
          'CS301 · Data Structures and Algorithms');
      expect(matrix.subjects.first.facultyNames, ['Dr Rao']);
      expect(matrix.subjects.last.facultyNames, isEmpty);
      expect(matrix.hasNoSubjectColumns, isFalse);
    });

    test('decodes the cross-tab row with its totals and percentage', () {
      final matrix = HodAttendanceMatrix.fromJson(payload());
      final row = matrix.students.single;

      expect(row.identity, 'CS2025001');
      expect(row.studentName, 'Rahul');
      expect(row.subjects.length, matrix.subjects.length);
      expect(row.cellAt(0)!.fraction, '32 / 40');
      expect(row.cellAt(0)!.percentage, 80.0);
      expect(row.totalPresent, 62);
      expect(row.totalClasses, 75);
      expect(row.overallPercentage, closeTo(82.6666, 0.0001));
      expect(row.hasConductedClasses, isTrue);
      // Out-of-range positions return null rather than a wrong cell.
      expect(row.cellAt(9), isNull);
      expect(row.cellAt(-1), isNull);
    });

    test('a subject with no conducted class shows 0 / 0 and no percentage', () {
      final matrix = HodAttendanceMatrix.fromJson({
        ...payload(),
        'students': [
          {
            'studentId': 93,
            'enrollmentNumber': 'CS2025003',
            'rollNumber': 'R3',
            'studentName': 'Neha',
            'sectionName': 'A',
            'subjects': [
              {'subjectId': 101, 'present': 0, 'total': 0},
              {'subjectId': 102, 'present': 0, 'total': 0},
            ],
            'totalPresent': 0,
            'totalClasses': 0,
          },
        ],
        'totalElements': 1,
      });

      final row = matrix.students.single;
      expect(row.hasConductedClasses, isFalse);
      expect(row.totalPresent, 0);
      expect(row.totalClasses, 0);
      // Absent key -> null, never a fabricated 0.00%.
      expect(row.overallPercentage, isNull);
      expect(row.cellAt(0)!.fraction, '0 / 0');
      expect(row.cellAt(0)!.hasConductedClass, isFalse);
      expect(row.cellAt(0)!.percentage, isNull);
    });

    test('an unmarked conducted class stays in the denominator', () {
      // 10 conducted classes for this subject; the student was marked PRESENT
      // in 7 of them and never marked in the other 3. The reported cell must be
      // 7 / 10 = 70%, never 7 / 7 = 100%.
      final matrix = HodAttendanceMatrix.fromJson({
        ...payload(),
        'students': [
          {
            'studentId': 92,
            'enrollmentNumber': 'CS2025002',
            'rollNumber': 'R2',
            'studentName': 'Ishan',
            'sectionName': 'A',
            'subjects': [
              {'subjectId': 101, 'present': 7, 'total': 10, 'percentage': 70.0},
              {'subjectId': 102, 'present': 4, 'total': 0},
            ],
            'totalPresent': 11,
            'totalClasses': 40,
            'overallPercentage': 27.5,
          },
        ],
        'totalElements': 1,
      });

      final row = matrix.students.single;
      final cell = row.cellAt(0)!;
      expect(cell.fraction, '7 / 10');
      expect(cell.total, 10);
      expect(cell.percentage, 70.0);
      expect(row.cellAt(1)!.hasConductedClass, isFalse);
    });

    test('a subject column with no classes is not fabricated away', () {
      final matrix = HodAttendanceMatrix.fromJson({
        ...payload(),
        'subjects': [
          {
            'subjectId': 101,
            'subjectCode': 'CS301',
            'subjectName': 'Data Structures',
            'facultyNames': <String>[],
          },
        ],
        'students': [
          {
            'studentId': 91,
            'enrollmentNumber': 'E1',
            'rollNumber': 'R1',
            'studentName': 'A',
            'sectionName': 'A',
            'subjects': [
              {'subjectId': 101, 'present': 0, 'total': 0},
            ],
            'totalPresent': 0,
            'totalClasses': 0,
          },
        ],
      });

      expect(matrix.subjects.length, 1);
      expect(matrix.students.single.subjects.length, 1);
      expect(matrix.students.single.cellAt(0)!.total, 0);
    });

    test('exposes paging helpers derived from the page metadata', () {
      final single = HodAttendanceMatrix.fromJson(payload());
      expect(single.hasPreviousPage, isFalse);
      expect(single.hasNextPage, isFalse);

      final middle = HodAttendanceMatrix.fromJson(
          {...payload(), 'page': 1, 'totalPages': 3, 'totalElements': 120});
      expect(middle.hasPreviousPage, isTrue);
      expect(middle.hasNextPage, isTrue);
    });

    test('an empty payload decodes to an empty matrix, not an error', () {
      final matrix = HodAttendanceMatrix.fromJson(const {});
      expect(matrix.isEmpty, isTrue);
      expect(matrix.subjects, isEmpty);
      expect(matrix.hasNoSubjectColumns, isTrue);
      expect(matrix.context.complete, isFalse);
    });
  });

  group('HodAttendanceOverview', () {
    test('decodes the metrics, distribution and subject table', () {
      final overview = HodAttendanceOverview.fromJson({
        'context': {'sectionId': 4, 'sectionName': 'A', 'complete': true},
        'totalStudents': 3,
        'overallPresentCount': 8,
        'overallTotalClasses': 12,
        'overallPercentage': 66.6666,
        'belowThresholdCount': 1,
        'classesConducted': 6,
        'thresholdPercentage': 75.0,
        'noConductedClasses': 1,
        'distribution': [
          {'band': 'high', 'label': '90-100%', 'studentCount': 0},
          {'band': 'medium', 'label': '75-89%', 'studentCount': 1},
          {'band': 'low', 'label': 'Below 75%', 'studentCount': 1},
        ],
        'subjects': [
          {
            'subjectId': 101,
            'subjectCode': 'CS301',
            'subjectName': 'Data Structures',
            'facultyNames': ['Dr Rao'],
            'classesConducted': 4,
            'presentCount': 5,
            'totalClasses': 8,
            'percentage': 62.5,
          },
        ],
      });

      expect(overview.totalStudents, 3);
      expect(overview.overallPresentCount, 8);
      expect(overview.overallTotalClasses, 12);
      expect(overview.overallPercentage, closeTo(66.6666, 0.0001));
      expect(overview.belowThresholdCount, 1);
      expect(overview.classesConducted, 6);
      expect(overview.noConductedClasses, 1);
      expect(overview.distribution.map((b) => b.studentCount), [0, 1, 1]);
      expect(overview.subjects.single.facultyLabel, 'Dr Rao');
      expect(overview.subjects.single.totalClasses, 8);
      expect(overview.subjects.single.hasConductedClasses, isTrue);
      expect(overview.hasConductedClasses, isTrue);
    });

    test('an absent classes-conducted value stays null, not zero', () {
      final overview = HodAttendanceOverview.fromJson({
        'totalStudents': 0,
        'overallPresentCount': 0,
        'overallTotalClasses': 0,
        'belowThresholdCount': 0,
        'noConductedClasses': 0,
      });

      expect(overview.classesConducted, isNull);
      expect(overview.overallPercentage, isNull);
      expect(overview.hasConductedClasses, isFalse);
    });

    test('an unmarked student is 0 / 10, not a 0 / 0 no-data state', () {
      // One conducted class set of 10, this student never marked in any of it.
      // The denominator is the conducted classes, so this is a real 0%.
      final overview = HodAttendanceOverview.fromJson({
        'totalStudents': 1,
        'overallPresentCount': 0,
        'overallTotalClasses': 10,
        'overallPercentage': 0.0,
        'belowThresholdCount': 1,
        'classesConducted': 10,
        'noConductedClasses': 0,
      });

      expect(overview.overallTotalClasses, 10);
      expect(overview.overallPercentage, 0.0);
      expect(overview.hasConductedClasses, isTrue);
      expect(overview.noConductedClasses, 0);
    });

    test('a subject with no conducted class has no percentage and says so', () {
      final overview = HodAttendanceOverview.fromJson({
        'totalStudents': 1,
        'overallPresentCount': 0,
        'overallTotalClasses': 0,
        'belowThresholdCount': 0,
        'noConductedClasses': 1,
        'subjects': [
          {
            'subjectId': 102,
            'subjectCode': 'CS302',
            'subjectName': 'Computer Networks',
            'classesConducted': 0,
            'presentCount': 0,
            'totalClasses': 0,
          },
        ],
      });

      final subject = overview.subjects.single;
      expect(subject.percentage, isNull);
      expect(subject.hasConductedClasses, isFalse);
      expect(subject.facultyLabel, 'No faculty assigned');
    });
  });

  group('HodStudentAttendanceDetail', () {
    test('decodes the identity, subject breakdown and totals', () {
      final detail = HodStudentAttendanceDetail.fromJson({
        'context': {'complete': true, 'sectionName': 'A'},
        'studentId': 91,
        'enrollmentNumber': 'CS2025001',
        'rollNumber': 'R1',
        'studentName': 'Rahul',
        'programName': 'B.Tech CSE',
        'semesterName': 'Semester 3',
        'sectionName': 'A',
        'subjects': [
          {
            'subjectId': 101,
            'subjectCode': 'CS301',
            'subjectName': 'Data Structures',
            'classes': 40,
            'present': 32,
            'notAttended': 8,
            'percentage': 80.0,
          },
          {
            'subjectId': 102,
            'subjectCode': 'CS302',
            'subjectName': 'Computer Networks',
            'classes': 0,
            'present': 0,
            'notAttended': 0,
          },
        ],
        'totalPresent': 32,
        'totalClasses': 40,
        'overallPercentage': 80.0,
      });

      expect(detail.identity, 'CS2025001');
      expect(detail.studentName, 'Rahul');
      expect(detail.subjects.length, 2);
      expect(detail.subjects.first.notAttended, 8);
      expect(detail.subjects.first.label, 'CS301');
      expect(detail.subjects.last.hasConductedClass, isFalse);
      expect(detail.subjects.last.percentage, isNull);
      expect(detail.totalPresent, 32);
      expect(detail.hasConductedClasses, isTrue);
    });
  });

  group('HodSubjectAttendanceDetail', () {
    test('decodes faculty, class count, roster and below-threshold count', () {
      final detail = HodSubjectAttendanceDetail.fromJson({
        'context': {'complete': true},
        'subjectId': 101,
        'subjectCode': 'CS301',
        'subjectName': 'Data Structures',
        'programName': 'B.Tech CSE',
        'semesterName': 'Semester 3',
        'sectionName': 'A',
        'facultyNames': ['Dr Rao'],
        'totalClasses': 4,
        'students': 3,
        'presentCount': 5,
        'totalClassesAcrossStudents': 12,
        'averageAttendance': 41.6666,
        'studentsBelowThreshold': 1,
        'thresholdPercentage': 75.0,
        'studentRows': [
          {
            'studentId': 91,
            'enrollmentNumber': 'E1',
            'rollNumber': 'R1',
            'studentName': 'Alice',
            'present': 4,
            'total': 4,
            'percentage': 100.0,
          },
          {
            'studentId': 93,
            'enrollmentNumber': 'E2',
            'rollNumber': 'R2',
            'studentName': 'Neha',
            'present': 0,
            'total': 4,
            'percentage': 0.0,
          },
        ],
      });

      expect(detail.label, 'CS301');
      expect(detail.facultyLabel, 'Dr Rao');
      expect(detail.totalClasses, 4);
      expect(detail.students, 3);
      expect(detail.totalClassesAcrossStudents, 12);
      expect(detail.averageAttendance, closeTo(41.6666, 0.0001));
      expect(detail.studentsBelowThreshold, 1);
      // The never-marked student is listed with a real 0% over 4 conducted
      // classes, not hidden behind a 0 / 0.
      expect(detail.studentRows.length, 2);
      expect(detail.studentRows.last.hasConductedClass, isTrue);
      expect(detail.studentRows.last.total, 4);
      expect(detail.studentRows.last.percentage, 0.0);
    });

    test('a subject with no conducted class reports no percentage at all', () {
      final detail = HodSubjectAttendanceDetail.fromJson({
        'context': {'complete': true},
        'subjectId': 101,
        'subjectCode': 'CS301',
        'subjectName': 'Data Structures',
        'totalClasses': 0,
        'students': 3,
        'presentCount': 0,
        'totalClassesAcrossStudents': 0,
        'studentsBelowThreshold': 0,
        'studentRows': [
          {
            'studentId': 91,
            'enrollmentNumber': 'E1',
            'rollNumber': 'R1',
            'studentName': 'Alice',
            'present': 0,
            'total': 0,
          },
        ],
      });

      expect(detail.averageAttendance, isNull);
      expect(detail.hasConductedClasses, isFalse);
      expect(detail.studentRows.single.hasConductedClass, isFalse);
      expect(detail.studentRows.single.percentage, isNull);
    });

    test('an unassigned subject says so rather than inventing faculty', () {
      final detail = HodSubjectAttendanceDetail.fromJson({
        'subjectId': 101,
        'subjectCode': 'CS301',
        'subjectName': 'Data Structures',
        'totalClasses': 0,
        'students': 0,
        'presentCount': 0,
        'totalClassesAcrossStudents': 0,
        'studentsBelowThreshold': 0,
      });

      expect(detail.facultyNames, isEmpty);
      expect(detail.facultyLabel, 'No faculty assigned');
      expect(detail.averageAttendance, isNull);
      expect(detail.hasConductedClasses, isFalse);
    });
  });

  group('HodLowAttendanceReport', () {
    test('decodes the threshold, the population and the subject breakdown', () {
      final report = HodLowAttendanceReport.fromJson({
        'context': {'complete': true},
        'thresholdPercentage': 75.0,
        'totalStudents': 3,
        'belowThresholdCount': 1,
        'students': [
          {
            'studentId': 93,
            'enrollmentNumber': 'E-003',
            'rollNumber': 'R3',
            'studentName': 'Carol',
            'sectionName': 'A',
            'programName': 'B.Tech CSE',
            'semesterName': 'Semester 3',
            'academicSessionName': 'Academic Session 2026-27',
            'presentCount': 3,
            'totalClasses': 6,
            'percentage': 50.0,
            'subjectsBelowThreshold': 1,
            'belowThresholdSubjects': [
              {
                'subjectId': 101,
                'subjectCode': 'CS301',
                'subjectName': 'Data Structures',
                'present': 1,
                'total': 4,
                'percentage': 25.0,
              },
            ],
          },
        ],
      });

      expect(report.thresholdPercentage, 75.0);
      expect(report.totalStudents, 3);
      expect(report.belowThresholdCount, 1);
      final carol = report.students.single;
      expect(carol.identity, 'E-003');
      expect(carol.totalClasses, 6);
      expect(carol.percentage, 50.0);
      expect(carol.subjectsBelowThreshold, 1);
      expect(carol.hasBreakdown, isTrue);
      expect(carol.belowThresholdSubjects.single.label, 'CS301');
      expect(carol.belowThresholdSubjects.single.percentage, 25.0);
    });

    test('a student with no identifiable cause reports an empty breakdown', () {
      final report = HodLowAttendanceReport.fromJson({
        'thresholdPercentage': 75.0,
        'totalStudents': 1,
        'belowThresholdCount': 1,
        'students': [
          {
            'studentId': 94,
            'enrollmentNumber': 'E-004',
            'rollNumber': 'R4',
            'studentName': 'Dinesh',
            'sectionName': 'A',
            'presentCount': 1,
            'totalClasses': 2,
            'percentage': 50.0,
            'subjectsBelowThreshold': 0,
          },
        ],
      });

      expect(report.students.single.hasBreakdown, isFalse);
      expect(report.students.single.belowThresholdSubjects, isEmpty);
    });

    test('an empty payload decodes to an empty report, not an error', () {
      final report = HodLowAttendanceReport.fromJson(const {});
      expect(report.isEmpty, isTrue);
      expect(report.belowThresholdCount, 0);
      expect(report.thresholdPercentage, isNull);
    });
  });
}
