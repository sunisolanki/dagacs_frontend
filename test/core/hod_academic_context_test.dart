import 'package:dagacs_frontend/core/context/hod_academic_context.dart';
import 'package:flutter_test/flutter_test.dart';

/// Unit coverage for the shared HOD academic context and its cascading
/// parent-to-child invalidation.
void main() {
  group('cascade reset', () {
    test('starts with nothing selected and no valid hierarchy', () {
      final context = HodAcademicContext();

      expect(context.hierarchyAvailable, isFalse);
      expect(context.academicSessionId, isNull);
      expect(context.programId, isNull);
      expect(context.semesterId, isNull);
      expect(context.sectionId, isNull);
      expect(context.subjectId, isNull);
      expect(context.hasAcademicContext, isFalse);
      expect(context.selectedChips, isEmpty);
    });

    test('selecting an academic session resets program through subject', () {
      final context = HodAcademicContext()..markHierarchyAvailable();
      context
        ..select(HodContextLevel.program, 2, name: 'B.Tech CSE')
        ..select(HodContextLevel.semester, 3, name: 'Semester 3')
        ..select(HodContextLevel.section, 4, name: 'Section A')
        ..select(HodContextLevel.subject, 5, name: 'DSA');

      expect(context.subjectId, 5);

      context.select(HodContextLevel.academicSession, 1, name: '2026-27');

      expect(context.academicSessionId, 1);
      expect(context.programId, isNull);
      expect(context.semesterId, isNull);
      expect(context.sectionId, isNull);
      expect(context.subjectId, isNull);
    });

    test('changing program resets semester, section and subject', () {
      final context = HodAcademicContext()..markHierarchyAvailable();
      context
        ..select(HodContextLevel.academicSession, 1, name: '2026-27')
        ..select(HodContextLevel.program, 2, name: 'B.Tech CSE')
        ..select(HodContextLevel.semester, 3, name: 'Semester 3')
        ..select(HodContextLevel.section, 4, name: 'Section A')
        ..select(HodContextLevel.subject, 5, name: 'DSA');

      context.select(HodContextLevel.program, 6, name: 'M.Tech CSE');

      expect(context.programId, 6);
      expect(context.programName, 'M.Tech CSE');
      expect(context.semesterId, isNull);
      expect(context.sectionId, isNull);
      expect(context.subjectId, isNull);
    });

    test('changing semester resets section and subject', () {
      final context = HodAcademicContext()..markHierarchyAvailable();
      context
        ..select(HodContextLevel.academicSession, 1, name: '2026-27')
        ..select(HodContextLevel.program, 2, name: 'B.Tech CSE')
        ..select(HodContextLevel.semester, 3, name: 'Semester 3')
        ..select(HodContextLevel.section, 4, name: 'Section A')
        ..select(HodContextLevel.subject, 5, name: 'DSA');

      context.select(HodContextLevel.semester, 7, name: 'Semester 4');

      expect(context.semesterId, 7);
      expect(context.sectionId, isNull);
      expect(context.subjectId, isNull);
    });

    test('changing section resets only subject', () {
      final context = HodAcademicContext()..markHierarchyAvailable();
      context
        ..select(HodContextLevel.academicSession, 1, name: '2026-27')
        ..select(HodContextLevel.program, 2, name: 'B.Tech CSE')
        ..select(HodContextLevel.semester, 3, name: 'Semester 3')
        ..select(HodContextLevel.section, 4, name: 'Section A')
        ..select(HodContextLevel.subject, 5, name: 'DSA');

      context.select(HodContextLevel.section, 8, name: 'Section B');

      expect(context.semesterId, 3);
      expect(context.sectionId, 8);
      expect(context.subjectId, isNull);
    });

    test('clearing a parent to null resets its children', () {
      final context = HodAcademicContext()..markHierarchyAvailable();
      context
        ..select(HodContextLevel.academicSession, 1, name: '2026-27')
        ..select(HodContextLevel.program, 2, name: 'B.Tech CSE')
        ..select(HodContextLevel.semester, 3, name: 'Semester 3');

      context.select(HodContextLevel.program, null);

      expect(context.programId, isNull);
      expect(context.semesterId, isNull);
    });
  });

  group('derived state', () {
    test('selectedChips lists only selected levels, parent to child', () {
      final context = HodAcademicContext()..markHierarchyAvailable();
      context
        ..select(HodContextLevel.academicSession, 1, name: '2026-27')
        ..select(HodContextLevel.program, 2, name: 'B.Tech CSE')
        ..select(HodContextLevel.semester, 3, name: 'Semester 3');

      final chips = context.selectedChips;
      expect(chips.map((c) => c.value).toList(),
          ['2026-27', 'B.Tech CSE', 'Semester 3']);
    });

    test('hasAcademicContext requires session, program and semester', () {
      final context = HodAcademicContext()..markHierarchyAvailable();
      context
        ..select(HodContextLevel.academicSession, 1, name: '2026-27')
        ..select(HodContextLevel.program, 2, name: 'B.Tech CSE');
      expect(context.hasAcademicContext, isFalse);

      context.select(HodContextLevel.semester, 3, name: 'Semester 3');
      expect(context.hasAcademicContext, isTrue);
    });

    test('markHierarchyAvailable notifies exactly once', () {
      final context = HodAcademicContext();
      var notifications = 0;
      context.addListener(() => notifications++);

      context.markHierarchyAvailable();
      context.markHierarchyAvailable();

      expect(notifications, 1);
      expect(context.hierarchyAvailable, isTrue);
    });
  });

  group('date range', () {
    test('detects a start date after the end date', () {
      final context = HodAcademicContext();
      context
        ..setStartDate(DateTime(2026, 9, 10))
        ..setEndDate(DateTime(2026, 9, 1));

      expect(context.datesInvalid, isTrue);
      expect(context.hasDateFilter, isTrue);
    });

    test('accepts an equal or ordered range', () {
      final context = HodAcademicContext();
      context
        ..setStartDate(DateTime(2026, 9, 1))
        ..setEndDate(DateTime(2026, 9, 1));
      expect(context.datesInvalid, isFalse);

      context
        ..setStartDate(DateTime(2026, 9, 1))
        ..setEndDate(DateTime(2026, 9, 30));
      expect(context.datesInvalid, isFalse);
    });

    test('clearDates resets both bounds and leaves the hierarchy intact', () {
      final context = HodAcademicContext()..markHierarchyAvailable();
      context
        ..select(HodContextLevel.academicSession, 1, name: '2026-27')
        ..setStartDate(DateTime(2026, 9, 1))
        ..setEndDate(DateTime(2026, 9, 30));

      context.clearDates();

      expect(context.startDate, isNull);
      expect(context.endDate, isNull);
      expect(context.hasDateFilter, isFalse);
      expect(context.academicSessionId, 1);
    });
  });

  group('options', () {
    test('an option list that drops the current selection clears it', () {
      final context = HodAcademicContext()..markHierarchyAvailable();
      context.setOptions(HodContextLevel.semester, const [
        HodContextOption(id: 3, label: 'Semester 3'),
        HodContextOption(id: 4, label: 'Semester 4'),
      ]);
      context.select(HodContextLevel.semester, 3, name: 'Semester 3');
      expect(context.semesterId, 3);

      // Semester 3 is no longer offered.
      context.setOptions(HodContextLevel.semester, const [
        HodContextOption(id: 4, label: 'Semester 4'),
      ]);

      expect(context.semesterId, isNull);
    });

    test('options are empty until a real source supplies them', () {
      final context = HodAcademicContext();
      for (final level in HodAcademicContext.levels) {
        expect(context.optionsFor(level), isEmpty);
      }
    });
  });
}
