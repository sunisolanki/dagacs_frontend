import 'package:flutter/foundation.dart';

/// The levels of the HOD academic hierarchy, in cascading order.
///
/// The cascade direction is strictly parent-to-child:
/// `academicSession -> program -> semester -> section -> subject`.
enum HodContextLevel { academicSession, program, semester, section, subject }

/// One selectable value of a [HodContextLevel].
///
/// Options are only ever produced from a verified backend response. Phase 1
/// ships no hierarchy endpoint, so every level starts empty and the UI renders
/// a disabled control plus an explicit notice. No option is ever fabricated.
@immutable
class HodContextOption {
  const HodContextOption({required this.id, required this.label, this.code});

  final int id;
  final String label;
  final String? code;
}

/// Shared, reusable HOD academic context.
///
/// A single instance is registered on `AppDependencies` so the selected
/// Academic Session -> Program -> Semester -> Section -> Subject selection
/// (and the optional date range) survives navigation between HOD routes. Pages
/// never own independent filter state.
///
/// This is a plain [ChangeNotifier], matching the project's existing state
/// approach (`SessionController`); no additional state-management framework is
/// introduced.
class HodAcademicContext extends ChangeNotifier {
  /// Levels ordered parent-to-child; the cascade index is derived from this.
  static const List<HodContextLevel> levels = HodContextLevel.values;

  int? _academicSessionId;
  int? _programId;
  int? _semesterId;
  int? _sectionId;
  int? _subjectId;

  String? _academicSessionName;
  String? _programName;
  String? _semesterName;
  String? _sectionName;
  String? _subjectName;

  DateTime? _startDate;
  DateTime? _endDate;

  final Map<HodContextLevel, List<HodContextOption>> _options = {
    for (final level in levels) level: <HodContextOption>[],
  };

  /// False until a verified hierarchy source populates [options].
  ///
  /// While false the context bar stays disabled and announces that academic
  /// context filtering arrives in a later phase. It never blocks the rest of a
  /// page: existing endpoints keep working with their existing date filter.
  bool _hierarchyAvailable = false;

  bool get hierarchyAvailable => _hierarchyAvailable;

  int? get academicSessionId => _academicSessionId;
  int? get programId => _programId;
  int? get semesterId => _semesterId;
  int? get sectionId => _sectionId;
  int? get subjectId => _subjectId;

  String? get academicSessionName => _academicSessionName;
  String? get programName => _programName;
  String? get semesterName => _semesterName;
  String? get sectionName => _sectionName;
  String? get subjectName => _subjectName;

  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;

  /// True when a full Academic Session + Program + Semester selection exists.
  ///
  /// Phase 1 never satisfies this (no hierarchy source yet); later phases gate
  /// academic-context-scoped attendance on it.
  bool get hasAcademicContext =>
      _academicSessionId != null && _programId != null && _semesterId != null;

  /// Mirrors the existing date validation used by the HOD date bar: a start
  /// date strictly after the end date is invalid.
  bool get datesInvalid =>
      _startDate != null && _endDate != null && _startDate!.isAfter(_endDate!);

  bool get hasDateFilter => _startDate != null || _endDate != null;

  List<HodContextOption> optionsFor(HodContextLevel level) =>
      List<HodContextOption>.unmodifiable(_options[level]!);

  /// Replaces the options of a single level. Used once a hierarchy source
  /// exists; the caller is responsible for department scoping server-side.
  void setOptions(HodContextLevel level, List<HodContextOption> options) {
    _options[level] = List<HodContextOption>.of(options);
    // An option list that no longer contains the current selection must not
    // leave a stale, unselectable value behind.
    final currentId = idFor(level);
    if (currentId != null &&
        !_options[level]!.any((option) => option.id == currentId)) {
      _resetFrom(level);
    }
    notifyListeners();
  }

  /// Signals that a verified hierarchy source is now wired up, which enables
  /// the cascading controls.
  void markHierarchyAvailable() {
    if (_hierarchyAvailable) return;
    _hierarchyAvailable = true;
    notifyListeners();
  }

  int? idFor(HodContextLevel level) {
    switch (level) {
      case HodContextLevel.academicSession:
        return _academicSessionId;
      case HodContextLevel.program:
        return _programId;
      case HodContextLevel.semester:
        return _semesterId;
      case HodContextLevel.section:
        return _sectionId;
      case HodContextLevel.subject:
        return _subjectId;
    }
  }

  String? nameFor(HodContextLevel level) {
    switch (level) {
      case HodContextLevel.academicSession:
        return _academicSessionName;
      case HodContextLevel.program:
        return _programName;
      case HodContextLevel.semester:
        return _semesterName;
      case HodContextLevel.section:
        return _sectionName;
      case HodContextLevel.subject:
        return _subjectName;
    }
  }

  /// Selecting a level invalidates every incompatible child selection.
  ///
  /// Program -> resets semester, section, subject
  /// Semester -> resets section, subject
  /// Section -> resets subject
  void select(HodContextLevel level, int? id, {String? name}) {
    switch (level) {
      case HodContextLevel.academicSession:
        _academicSessionId = id;
        _academicSessionName = id == null ? null : name;
      case HodContextLevel.program:
        _programId = id;
        _programName = id == null ? null : name;
      case HodContextLevel.semester:
        _semesterId = id;
        _semesterName = id == null ? null : name;
      case HodContextLevel.section:
        _sectionId = id;
        _sectionName = id == null ? null : name;
      case HodContextLevel.subject:
        _subjectId = id;
        _subjectName = id == null ? null : name;
    }
    // Children of the changed level (and the level's own child chain) are no
    // longer guaranteed to be compatible with the new parent.
    _resetFrom(_childOf(level));
    // Option lists are only dropped for levels that are genuinely invalidated.
    // A level two or more steps down can no longer be trusted; the immediate
    // child keeps its options because they are still meaningful (for example
    // every department program stays valid when the academic session changes,
    // and the context bar narrows them to the session's own program).
    _clearOptionsFrom(level.index + 2);
    notifyListeners();
  }

  void setStartDate(DateTime? date) {
    _startDate = date;
    notifyListeners();
  }

  void setEndDate(DateTime? date) {
    _endDate = date;
    notifyListeners();
  }

  void clearDates() {
    _startDate = null;
    _endDate = null;
    notifyListeners();
  }

  /// Clears the entire academic selection (but keeps the date range, which is
  /// an independent filter).
  void clearHierarchy() {
    _resetFrom(HodContextLevel.academicSession);
    notifyListeners();
  }

  /// Clears everything, including the date range.
  void clearAll() {
    _resetFrom(HodContextLevel.academicSession);
    _startDate = null;
    _endDate = null;
    notifyListeners();
  }

  /// The selected levels that currently have a value, parent-to-child. Used to
  /// render the persistent context display.
  List<MapEntry<HodContextLevel, String>> get selectedChips {
    final chips = <MapEntry<HodContextLevel, String>>[];
    for (final level in levels) {
      final name = nameFor(level);
      if (name != null && name.isNotEmpty) {
        chips.add(MapEntry(level, name));
      }
    }
    return chips;
  }

  /// The child level of [level] (the next level down in the cascade), or null
  /// when [level] is already the deepest one.
  static HodContextLevel? _childOf(HodContextLevel level) {
    final next = level.index + 1;
    return next < levels.length ? levels[next] : null;
  }

  /// Clears the selection of [level] and every level below it.
  ///
  /// Option lists are intentionally *not* touched here: see [select], which
  /// decides separately which option lists are still trustworthy.
  void _resetFrom(HodContextLevel? level) {
    if (level == null) return;
    for (var i = level.index; i < levels.length; i++) {
      switch (levels[i]) {
        case HodContextLevel.academicSession:
          _academicSessionId = null;
          _academicSessionName = null;
        case HodContextLevel.program:
          _programId = null;
          _programName = null;
        case HodContextLevel.semester:
          _semesterId = null;
          _semesterName = null;
        case HodContextLevel.section:
          _sectionId = null;
          _sectionName = null;
        case HodContextLevel.subject:
          _subjectId = null;
          _subjectName = null;
      }
    }
  }

  /// Clears the option lists from [startIndex] and every level below it, so a
  /// value published for a previous parent can never be offered again.
  void _clearOptionsFrom(int startIndex) {
    for (var i = startIndex; i < levels.length; i++) {
      _options[levels[i]] = <HodContextOption>[];
    }
  }
}
