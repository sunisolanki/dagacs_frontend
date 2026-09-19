/// Matches the backend M5.2 `StudentManagementDTO` (Jackson `non_null`) plus the
/// M9.5.2 login-linkage fields.
///
/// Read/write ADMIN view of the student master. The backend resolves program,
/// batch and section names; this model is used purely for display in the
/// ADMIN-only Manage Students screen. Passwords are never part of a response.
class StudentManagement {
  final int? id;
  final String? rollNumber;
  final String? email;
  final String? name;
  final String? gender;
  final String? fatherName;
  final String? motherName;
  final String? photoUrl;
  final String? enrollmentNumber;
  final int? age;
  final String? admissionDate;
  final String? status;
  final int? programId;
  final String? programName;
  final int? batchId;
  final String? batchName;
  final int? sectionId;
  final String? sectionName;
  final int? semesterId;
  final String? semesterName;
  final int? academicSessionId;
  final String? academicSessionName;
  final bool? loginLinked;
  final String? loginStatus;
  final bool? mustChangePassword;
  final String? temporaryPassword;
  final String? credentialDownloadId;

  const StudentManagement({
    this.id,
    this.rollNumber,
    this.email,
    this.name,
    this.gender,
    this.fatherName,
    this.motherName,
    this.photoUrl,
    this.enrollmentNumber,
    this.age,
    this.admissionDate,
    this.status,
    this.programId,
    this.programName,
    this.batchId,
    this.batchName,
    this.sectionId,
    this.sectionName,
    this.semesterId,
    this.semesterName,
    this.academicSessionId,
    this.academicSessionName,
    this.loginLinked,
    this.loginStatus,
    this.mustChangePassword,
    this.temporaryPassword,
    this.credentialDownloadId,
  });

  factory StudentManagement.fromJson(Map<String, dynamic> json) {
    return StudentManagement(
      id: json['id'] as int?,
      rollNumber: json['rollNumber'] as String?,
      email: json['email'] as String?,
      name: json['name'] as String?,
      gender: json['gender'] as String?,
      fatherName: json['fatherName'] as String?,
      motherName: json['motherName'] as String?,
      photoUrl: json['photoUrl'] as String?,
      enrollmentNumber: json['enrollmentNumber'] as String?,
      age: json['age'] as int?,
      admissionDate: json['admissionDate'] as String?,
      status: json['status'] as String?,
      programId: json['programId'] as int?,
      programName: json['programName'] as String?,
      batchId: json['batchId'] as int?,
      batchName: json['batchName'] as String?,
      sectionId: json['sectionId'] as int?,
      sectionName: json['sectionName'] as String?,
      semesterId: json['semesterId'] as int?,
      semesterName: json['semesterName'] as String?,
      academicSessionId: json['academicSessionId'] as int?,
      academicSessionName: json['academicSessionName'] as String?,
      loginLinked: json['loginLinked'] as bool?,
      loginStatus: json['loginStatus'] as String?,
      mustChangePassword: json['mustChangePassword'] as bool?,
      temporaryPassword: json['temporaryPassword'] as String?,
      credentialDownloadId: json['credentialDownloadId'] as String?,
    );
  }

  bool get isActive => status == 'ACTIVE';

  /// Login account ACTIVE/INACTIVE; only meaningful when [hasLogin] is true.
  bool get loginIsActive => loginStatus == 'ACTIVE';

  bool get hasLogin => loginLinked == true;

  /// Display labels per the approved UX: an active linked login shows
  /// "LOGIN ACTIVE", an absent login account shows "NO LOGIN" (the backend
  /// login status values stay ACTIVE/INACTIVE/NONE).
  String get loginStatusLabel {
    if (!hasLogin) return 'NO LOGIN';
    return loginIsActive ? 'LOGIN ACTIVE' : 'LOGIN INACTIVE';
  }
}

/// Login/account HTTP-y payloads (M9.5.2): the initial password for
/// provisioning and the new password for reset. The password is write-only and
/// is never echoed back by the backend.
class StudentLoginPasswordRequest {
  final String password;

  const StudentLoginPasswordRequest(this.password);

  Map<String, dynamic> toJson() => {'password': password};
}

/// Create/update payload for the ADMIN student master API. Matches the backend
/// `StudentManagementRequestDTO`. No field is sent by the client unless it has a
/// value (backend defaults status to ACTIVE when absent).
class StudentManagementRequest {
  final String? rollNumber;
  final String? email;
  final String? name;
  final String? gender;
  final String? fatherName;
  final String? motherName;
  final String? photoUrl;
  final String? enrollmentNumber;
  final int? age;
  final String? admissionDate;
  final String? status;
  final int? programId;
  final int? academicSessionId;
  final int? batchId;
  final int? sectionId;
  final int? semesterId;

  const StudentManagementRequest({
    this.rollNumber,
    this.email,
    this.name,
    this.gender,
    this.fatherName,
    this.motherName,
    this.photoUrl,
    this.enrollmentNumber,
    this.age,
    this.admissionDate,
    this.status,
    this.programId,
    this.academicSessionId,
    this.batchId,
    this.sectionId,
    this.semesterId,
  });

  factory StudentManagementRequest.fromStudent(StudentManagement student) =>
      StudentManagementRequest(
        rollNumber: student.rollNumber,
        email: student.email,
        name: student.name,
        gender: student.gender,
        fatherName: student.fatherName,
        motherName: student.motherName,
        photoUrl: student.photoUrl,
        enrollmentNumber: student.enrollmentNumber,
        age: student.age,
        admissionDate: student.admissionDate,
        status: student.status,
        programId: student.programId,
        academicSessionId: student.academicSessionId,
        batchId: student.batchId,
        sectionId: student.sectionId,
        semesterId: student.semesterId,
      );

  Map<String, dynamic> toJson() => {
        if (rollNumber != null) 'rollNumber': rollNumber,
        if (email != null) 'email': email,
        if (name != null) 'name': name,
        if (gender != null) 'gender': gender,
        if (fatherName != null) 'fatherName': fatherName,
        if (motherName != null) 'motherName': motherName,
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (enrollmentNumber != null) 'enrollmentNumber': enrollmentNumber,
        if (age != null) 'age': age,
        if (admissionDate != null) 'admissionDate': admissionDate,
        if (status != null) 'status': status,
        if (programId != null) 'programId': programId,
        if (academicSessionId != null) 'academicSessionId': academicSessionId,
        if (batchId != null) 'batchId': batchId,
        if (sectionId != null) 'sectionId': sectionId,
        if (semesterId != null) 'semesterId': semesterId,
      };
}

/// M9.10 bulk student import summary (backend `StudentImportResult`).
///
/// The import is all-or-nothing on the server: when [rejectedRows] is non-zero,
/// [importedRows] is always 0. [errors] carries one entry per rejected row with
/// the physical file row number, the affected field, the validation message and
/// the HTTP status that applies to that row (400 validation / 409 conflict).
class StudentImportResult {
  final int totalRows;
  final int importedRows;
  final int rejectedRows;
  final String? message;
  final String? credentialDownloadId;
  final List<StudentImportError> errors;

  const StudentImportResult({
    this.totalRows = 0,
    this.importedRows = 0,
    this.rejectedRows = 0,
    this.message,
    this.credentialDownloadId,
    this.errors = const [],
  });

  factory StudentImportResult.fromJson(Map<String, dynamic> json) {
    final rawErrors = json['errors'];
    return StudentImportResult(
      totalRows: (json['totalRows'] as num?)?.toInt() ?? 0,
      importedRows: (json['importedRows'] as num?)?.toInt() ?? 0,
      rejectedRows: (json['rejectedRows'] as num?)?.toInt() ?? 0,
      message: json['message'] as String?,
      credentialDownloadId: json['credentialDownloadId'] as String?,
      errors: rawErrors is List
          ? rawErrors
              .whereType<Map>()
              .map((e) =>
                  StudentImportError.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
  }

  bool get isSuccess => rejectedRows == 0;
}

/// One rejected row in an import summary.
class StudentImportError {
  final int rowNumber;
  final String? field;
  final String? message;
  final int status;

  const StudentImportError({
    this.rowNumber = 0,
    this.field,
    this.message,
    this.status = 0,
  });

  factory StudentImportError.fromJson(Map<String, dynamic> json) {
    return StudentImportError(
      rowNumber: (json['rowNumber'] as num?)?.toInt() ?? 0,
      field: json['field'] as String?,
      message: json['message'] as String?,
      status: (json['status'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Paged result of the ADMIN student search (backend `StudentPageResponse`).
///
/// The backend sorts by student name and caps `size` at 100; the page is
/// 0-indexed and `totalPages` is derived from `totalElements / size`.
class StudentPage {
  final List<StudentManagement> content;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;

  const StudentPage({
    this.content = const [],
    this.page = 0,
    this.size = 0,
    this.totalElements = 0,
    this.totalPages = 0,
  });

  factory StudentPage.fromJson(Map<String, dynamic> json) {
    final rawContent = json['content'];
    return StudentPage(
      content: rawContent is List
          ? rawContent
              .whereType<Map>()
              .map((e) => StudentManagement.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      page: (json['page'] as num?)?.toInt() ?? 0,
      size: (json['size'] as num?)?.toInt() ?? 0,
      totalElements: (json['totalElements'] as num?)?.toInt() ?? 0,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 0,
    );
  }

  bool get isEmpty => content.isEmpty;
  bool get hasMore => page + 1 < totalPages;
}

/// The student-search filter query. Every field is optional; a null field is
/// simply not sent (the backend applies equality only for explicitly selected
/// ids - never any cascade logic). Populated here by the UI in the approved
/// dependency order: Academic Session -> Program -> Semester -> Batch -> Section.
class StudentSearchQuery {
  final String? search;
  final int? academicSessionId;
  final int? programId;
  final int? semesterId;
  final int? batchId;
  final int? sectionId;
  final String? status;
  final String? loginStatus;
  final int page;
  final int size;

  const StudentSearchQuery({
    this.search,
    this.academicSessionId,
    this.programId,
    this.semesterId,
    this.batchId,
    this.sectionId,
    this.status,
    this.loginStatus,
    this.page = 0,
    this.size = 20,
  });

  StudentSearchQuery copyWith({
    String? search,
    int? academicSessionId,
    int? programId,
    int? semesterId,
    int? batchId,
    int? sectionId,
    String? status,
    String? loginStatus,
    int? page,
    int? size,
  }) {
    return StudentSearchQuery(
      search: search ?? this.search,
      academicSessionId: academicSessionId ?? this.academicSessionId,
      programId: programId ?? this.programId,
      semesterId: semesterId ?? this.semesterId,
      batchId: batchId ?? this.batchId,
      sectionId: sectionId ?? this.sectionId,
      status: status ?? this.status,
      loginStatus: loginStatus ?? this.loginStatus,
      page: page ?? this.page,
      size: size ?? this.size,
    );
  }

  /// Query parameters for the GET, skipping every unset filter.
  Map<String, dynamic> toQueryParameters() {
    return {
      if (search != null && search!.trim().isNotEmpty) 'search': search!.trim(),
      if (academicSessionId != null) 'academicSessionId': academicSessionId,
      if (programId != null) 'programId': programId,
      if (semesterId != null) 'semesterId': semesterId,
      if (batchId != null) 'batchId': batchId,
      if (sectionId != null) 'sectionId': sectionId,
      if (status != null) 'status': status,
      if (loginStatus != null) 'loginStatus': loginStatus,
      'page': page,
      'size': size,
    };
  }
}

/// One selectable filter option (backend `StudentFilterOption`). The extra
/// parent ids/names exist so options can be filtered/greyed client-side - e.g.
/// a program option knows its parent session.
class StudentFilterOption {
  final int id;
  final String? name;
  final int? programId;
  final String? programName;
  final int? academicSessionId;
  final String? academicSessionName;
  final int? batchId;
  final String? batchName;

  const StudentFilterOption({
    required this.id,
    this.name,
    this.programId,
    this.programName,
    this.academicSessionId,
    this.academicSessionName,
    this.batchId,
    this.batchName,
  });

  factory StudentFilterOption.fromJson(Map<String, dynamic> json) {
    return StudentFilterOption(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String?,
      programId: (json['programId'] as num?)?.toInt(),
      programName: json['programName'] as String?,
      academicSessionId: (json['academicSessionId'] as num?)?.toInt(),
      academicSessionName: json['academicSessionName'] as String?,
      batchId: (json['batchId'] as num?)?.toInt(),
      batchName: json['batchName'] as String?,
    );
  }

  String get displayName => name ?? 'Unnamed';
}

/// The cascaded filter options (backend `StudentFilterOptionsResponse`). The
/// lists come from the MASTER-DATA entities (never from student records), so
/// options remain available even when no student matches.
class StudentFilterOptionsData {
  final List<StudentFilterOption> academicSessions;
  final List<StudentFilterOption> programs;
  final List<StudentFilterOption> semesters;
  final List<StudentFilterOption> batches;
  final List<StudentFilterOption> sections;

  const StudentFilterOptionsData({
    this.academicSessions = const [],
    this.programs = const [],
    this.semesters = const [],
    this.batches = const [],
    this.sections = const [],
  });

  factory StudentFilterOptionsData.fromJson(Map<String, dynamic> json) {
    List<StudentFilterOption> parse(String key) {
      final raw = json[key];
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => StudentFilterOption.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    return StudentFilterOptionsData(
      academicSessions: parse('academicSessions'),
      programs: parse('programs'),
      semesters: parse('semesters'),
      batches: parse('batches'),
      sections: parse('sections'),
    );
  }
}