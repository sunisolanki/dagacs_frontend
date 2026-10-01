import 'package:flutter/foundation.dart';

import '../core/context/hod_academic_context.dart';
import '../models/hod_hierarchy.dart';
import '../network/api_exception.dart';
import '../repositories/hod_hierarchy_repository.dart';

/// Loads the HOD academic hierarchy and writes it into the shared
/// [HodAcademicContext].
///
/// Behaviour that the module depends on:
///  * The root (department + programs + sessions) is fetched **once** and
///    reused; re-entering a screen never refetches it.
///  * Each cascade level is fetched **only when its parent changes**, so a new
///    selection invalidates only the dependent options.
///  * [HodAcademicContext.setOptions] and its cascade reset already guarantee a
///    stale child selection can never survive a parent change; this loader
///    never works around that, it just feeds it.
///  * A failure is reported as [HodHierarchyStatus.unauthorized] or
///    [HodHierarchyStatus.error] and never as an empty selection, so a broken
///    hierarchy can never masquerade as "no academic data exists".
class HodHierarchyLoader extends ChangeNotifier {
  HodHierarchyLoader({
    required HodHierarchyRepository repository,
    required HodAcademicContext context,
  })  : _repository = repository,
        _context = context;

  final HodHierarchyRepository _repository;
  final HodAcademicContext _context;

  HodHierarchyStatus _rootStatus = HodHierarchyStatus.idle;
  HodHierarchyRoot? _root;
  final Map<HodContextLevel, HodHierarchyStatus> _levelStatus = {
    for (final level in HodAcademicContext.levels) level: HodHierarchyStatus.idle,
  };
  final Map<HodContextLevel, String> _levelErrors = {};

  HodHierarchyStatus get rootStatus => _rootStatus;
  HodHierarchyRoot? get root => _root;

  String? get rootError => _levelErrors[HodContextLevel.academicSession];

  HodHierarchyStatus statusFor(HodContextLevel level) =>
      _levelStatus[level] ?? HodHierarchyStatus.idle;

  String? errorFor(HodContextLevel level) => _levelErrors[level];

  bool get isRootResolved => _root != null;

  /// The program an academic session belongs to.
  ///
  /// A session has exactly one program in this domain, so the client uses this
  /// to offer only the compatible program. That makes an invalid
  /// program/session pairing impossible to construct in the first place, which
  /// is what keeps a B.Tech context from ever being mixed with an M.Tech one.
  int? programIdForSession(int? sessionId) {
    if (sessionId == null) return null;
    for (final session in _root?.academicSessions ?? const <HodHierarchyOption>[]) {
      if (session.id == sessionId) return session.programId;
    }
    return null;
  }

  /// Loads the hierarchy root once. Safe to call from every screen.
  Future<void> ensureRoot({bool force = false}) async {
    if (_root != null && !force) return;
    _setRootStatus(HodHierarchyStatus.loading, null);
    try {
      final root = await _repository.getRoot();
      _root = root;
      // The context bar becomes interactive only after a real response.
      _context.markHierarchyAvailable();
      _context.setOptions(
        HodContextLevel.academicSession,
        root.academicSessions
            .map((option) => option.toContextOption())
            .toList(),
      );
      // Programs are filtered client-side against the selected session, so
      // every program of the department is published at the root.
      _context.setOptions(
        HodContextLevel.program,
        root.programs.map((option) => option.toContextOption()).toList(),
      );
      _setRootStatus(
        root.academicSessions.isEmpty && root.programs.isEmpty
            ? HodHierarchyStatus.empty
            : HodHierarchyStatus.ready,
        null,
      );
    } on ApiException catch (e) {
      _setRootStatus(_statusFor(e), _messageFor(e));
    } catch (_) {
      _setRootStatus(HodHierarchyStatus.error, hodHierarchyErrorMessage);
    }
  }

  /// Semesters of the selected academic session.
  Future<void> loadSemesters({required int academicSessionId}) async {
    await _loadLevel(HodContextLevel.semester, () async {
      final rows = await _repository.getSemesters(
          academicSessionId: academicSessionId);
      _context.setOptions(
        HodContextLevel.semester,
        rows.map((option) => option.toContextOption()).toList(),
      );
      return rows;
    });
  }

  /// Sections of the selected session, restricted to the selected semester.
  Future<void> loadSections({
    required int academicSessionId,
    int? programId,
    int? semesterId,
  }) async {
    await _loadLevel(HodContextLevel.section, () async {
      final rows = await _repository.getSections(
        academicSessionId: academicSessionId,
        programId: programId,
        semesterId: semesterId,
      );
      _context.setOptions(
        HodContextLevel.section,
        rows.map((option) => option.toContextOption()).toList(),
      );
      return rows;
    });
  }

  /// Subjects offered in the selected semester, with the faculty of the
  /// selected section when there is one.
  Future<List<HodHierarchySubject>> loadSubjects({
    required int semesterId,
    int? sectionId,
  }) {
    return _loadLevel<HodHierarchySubject>(
      HodContextLevel.subject,
      () async {
        final rows = await _repository.getSubjects(
          semesterId: semesterId,
          sectionId: sectionId,
        );
        _lastSubjects = rows;
        _context.setOptions(
          HodContextLevel.subject,
          rows.map((option) => option.toContextOption()).toList(),
        );
        return rows;
      },
    );
  }

  /// Faculty for the subjects of the currently selected semester, for the
  /// Subjects view. Returns an empty list when the cached subjects belong to a
  /// different semester, so a stale faculty list can never be shown.
  List<HodHierarchySubject> subjectsWithFaculty({required int semesterId}) {
    if (_context.semesterId != semesterId) return const [];
    return _lastSubjects
        .where((subject) => subject.semesterId == semesterId)
        .toList(growable: false);
  }

  List<HodHierarchySubject> _lastSubjects = const [];

  Future<List<T>> _loadLevel<T>(
    HodContextLevel level,
    Future<List<T>> Function() fetch,
  ) async {
    _setLevelStatus(level, HodHierarchyStatus.loading, null);
    try {
      final rows = await fetch();
      if (level != HodContextLevel.subject) {
        _lastSubjects = const [];
      }
      _setLevelStatus(
        level,
        rows.isEmpty ? HodHierarchyStatus.empty : HodHierarchyStatus.ready,
        null,
      );
      return rows;
    } on ApiException catch (e) {
      if (level != HodContextLevel.subject) {
        _lastSubjects = const [];
      }
      _setLevelStatus(level, _statusFor(e), _messageFor(e));
      return <T>[];
    } catch (_) {
      if (level != HodContextLevel.subject) {
        _lastSubjects = const [];
      }
      _setLevelStatus(level, HodHierarchyStatus.error, hodHierarchyErrorMessage);
      return <T>[];
    }
  }

  void _setRootStatus(HodHierarchyStatus status, String? error) {
    _rootStatus = status;
    if (error == null) {
      _levelErrors.remove(HodContextLevel.academicSession);
    } else {
      _levelErrors[HodContextLevel.academicSession] = error;
    }
    notifyListeners();
  }

  void _setLevelStatus(HodContextLevel level, HodHierarchyStatus status, String? error) {
    _levelStatus[level] = status;
    if (error == null) {
      _levelErrors.remove(level);
    } else {
      _levelErrors[level] = error;
    }
    notifyListeners();
  }

  static HodHierarchyStatus _statusFor(ApiException e) =>
      (e.statusCode == 401 || e.statusCode == 403)
          ? HodHierarchyStatus.unauthorized
          : HodHierarchyStatus.error;

  static String _messageFor(ApiException e) {
    if (e.statusCode == 401 || e.statusCode == 403) {
      return hodHierarchyUnauthorizedMessage;
    }
    // A transport or server failure has no useful detail for the HOD, so the
    // loader states the action it could not complete.
    if (e.statusCode == -1 || e.statusCode >= 500) {
      return hodHierarchyErrorMessage;
    }
    // A 4xx carries an actionable reason (for example an inconsistent
    // academic-context combination), so it is surfaced verbatim.
    return e.message.isEmpty ? hodHierarchyErrorMessage : e.message;
  }
}

/// User-facing copy for a hierarchy load that failed.
const String hodHierarchyErrorMessage = 'Unable to load academic hierarchy.';

/// User-facing copy for a hierarchy load the HOD is not allowed to perform.
const String hodHierarchyUnauthorizedMessage =
    'You are not authorized to access this academic data.';

/// User-facing copy for a hierarchy that loaded but holds no academic sessions.
const String hodHierarchyEmptyMessage = 'No academic sessions available.';

/// User-facing copy while the hierarchy is loading.
const String hodHierarchyLoadingMessage = 'Loading academic hierarchy...';
