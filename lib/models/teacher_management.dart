/// Read/write ADMIN view of the teacher master (M9.5.1).
///
/// Matches the backend `TeacherManagementDTO` from
/// `/api/admin/teacher-management/teachers`. It extends the read-only
/// assignment projection ([Teacher]) with the profile + login lifecycle facts
/// the ADMIN teacher-management UI needs: profile status, department, HOD flag,
/// and whether/which state the linked login account is in. Passwords are never
/// part of a response and never present on this model.
class TeacherManagement {
  final int? id;
  final String? email;
  final String? fullName;
  final String? phone;
  final String? designation;
  final String? status;
  final int? departmentId;
  final String? departmentName;
  final bool? isHod;
  final bool? loginLinked;
  final String? loginStatus;
  final String? createdAt;
  final String? updatedAt;

  const TeacherManagement({
    this.id,
    this.email,
    this.fullName,
    this.phone,
    this.designation,
    this.status,
    this.departmentId,
    this.departmentName,
    this.isHod,
    this.loginLinked,
    this.loginStatus,
    this.createdAt,
    this.updatedAt,
  });

  factory TeacherManagement.fromJson(Map<String, dynamic> json) {
    return TeacherManagement(
      id: json['id'] as int?,
      email: json['email'] as String?,
      fullName: json['fullName'] as String?,
      phone: json['phone'] as String?,
      designation: json['designation'] as String?,
      status: json['status'] as String?,
      departmentId: json['departmentId'] as int?,
      departmentName: json['departmentName'] as String?,
      isHod: json['isHod'] as bool?,
      loginLinked: json['loginLinked'] as bool?,
      loginStatus: json['loginStatus'] as String?,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }

  /// Profile ACTIVE/INACTIVE (independent of the login state, D4).
  bool get isActive => status == 'ACTIVE';

  /// Login account ACTIVE/INACTIVE; only meaningful when [loginLinked] is true.
  bool get loginIsActive => loginStatus == 'ACTIVE';

  bool get hasLogin => loginLinked == true;
}

/// Create-teacher payload for `POST /api/admin/teacher-management/teachers`.
///
/// The admin supplies the initial password (D3); it is transmitted once and is
/// never echoed back. `status` defaults to ACTIVE on the backend when omitted.
class TeacherCreateRequest {
  final String email;
  final String fullName;
  final String? phone;
  final String? designation;
  final int? departmentId;
  final String password;
  final String? status;

  const TeacherCreateRequest({
    required this.email,
    required this.fullName,
    this.phone,
    this.designation,
    this.departmentId,
    required this.password,
    this.status,
  });

  Map<String, dynamic> toJson() => {
        'email': email,
        'fullName': fullName,
        if (phone != null && phone!.isNotEmpty) 'phone': phone,
        if (designation != null && designation!.isNotEmpty)
          'designation': designation,
        if (departmentId != null) 'departmentId': departmentId,
        'password': password,
        if (status != null) 'status': status,
      };
}

/// Update-teacher-profile payload for `PUT /api/admin/teacher-management/teachers/{id}`.
///
/// Email is immutable once a teacher exists (email is the login-linkage key); it
/// is deliberately not part of this request. Absent fields keep their current
/// value on the backend.
class TeacherUpdateRequest {
  final String? fullName;
  final String? phone;
  final String? designation;
  final int? departmentId;

  const TeacherUpdateRequest({
    this.fullName,
    this.phone,
    this.designation,
    this.departmentId,
  });

  factory TeacherUpdateRequest.fromTeacher(TeacherManagement teacher) =>
      TeacherUpdateRequest(
        fullName: teacher.fullName,
        phone: teacher.phone,
        designation: teacher.designation,
        departmentId: teacher.departmentId,
      );

  Map<String, dynamic> toJson() => {
        if (fullName != null && fullName!.isNotEmpty) 'fullName': fullName,
        if (phone != null && phone!.isNotEmpty) 'phone': phone,
        if (designation != null && designation!.isNotEmpty)
          'designation': designation,
        if (departmentId != null) 'departmentId': departmentId,
      };
}

/// Login/account HTTP-y payloads (M9.5.1): initial password for provisioning and
/// the new password for reset. The password is write-only.
class TeacherLoginPasswordRequest {
  final String password;

  const TeacherLoginPasswordRequest(this.password);

  Map<String, dynamic> toJson() => {'password': password};
}

/// HOD designation payload for `PATCH /api/admin/teachers/{id}/hod` (M6.1/M9.5.3).
/// `designated=true` promotes with the given department; `false` demotes.
class TeacherHodDesignationRequest {
  final bool designated;
  final int? departmentId;

  const TeacherHodDesignationRequest({
    required this.designated,
    this.departmentId,
  });

  Map<String, dynamic> toJson() => {
        'designated': designated,
        if (departmentId != null) 'departmentId': departmentId,
      };
}

/// Read-only HOD identity returned by `PATCH /api/admin/teachers/{id}/hod`
/// (matches the frozen backend `HodIdentityDTO`): business identifiers only,
/// no internal database keys.
class HodIdentity {
  final String? email;
  final String? teacherName;
  final String? designation;
  final bool? hod;
  final String? departmentName;
  final String? departmentCode;

  const HodIdentity({
    this.email,
    this.teacherName,
    this.designation,
    this.hod,
    this.departmentName,
    this.departmentCode,
  });

  factory HodIdentity.fromJson(Map<String, dynamic> json) {
    return HodIdentity(
      email: json['email'] as String?,
      teacherName: json['teacherName'] as String?,
      designation: json['designation'] as String?,
      hod: json['hod'] as bool?,
      departmentName: json['departmentName'] as String?,
      departmentCode: json['departmentCode'] as String?,
    );
  }
}