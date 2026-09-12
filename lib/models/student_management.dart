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
  final bool? loginLinked;
  final String? loginStatus;

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
    this.loginLinked,
    this.loginStatus,
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
      loginLinked: json['loginLinked'] as bool?,
      loginStatus: json['loginStatus'] as String?,
    );
  }

  bool get isActive => status == 'ACTIVE';

  /// Login account ACTIVE/INACTIVE; only meaningful when [hasLogin] is true.
  bool get loginIsActive => loginStatus == 'ACTIVE';

  bool get hasLogin => loginLinked == true;
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
  final int? batchId;
  final int? sectionId;

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
    this.batchId,
    this.sectionId,
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
        batchId: student.batchId,
        sectionId: student.sectionId,
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
        if (batchId != null) 'batchId': batchId,
        if (sectionId != null) 'sectionId': sectionId,
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
  final List<StudentImportError> errors;

  const StudentImportResult({
    this.totalRows = 0,
    this.importedRows = 0,
    this.rejectedRows = 0,
    this.message,
    this.errors = const [],
  });

  factory StudentImportResult.fromJson(Map<String, dynamic> json) {
    final rawErrors = json['errors'];
    return StudentImportResult(
      totalRows: (json['totalRows'] as num?)?.toInt() ?? 0,
      importedRows: (json['importedRows'] as num?)?.toInt() ?? 0,
      rejectedRows: (json['rejectedRows'] as num?)?.toInt() ?? 0,
      message: json['message'] as String?,
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