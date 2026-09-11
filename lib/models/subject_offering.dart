import 'semester.dart';
import 'subject.dart';

/// Matches backend `SubjectOfferingDTO`.
///
/// A Subject Offering is a pure many-to-many mapping between a reusable
/// Subject and a Semester. Academic context (session / program / department)
/// is intentionally NOT stored on the offering - it is derived from the
/// Semester —> AcademicSession —> Program —> Department chain on the backend.
class SubjectOffering {
  final int? id;
  final int? subjectId;
  final Subject? subject;
  final int? semesterId;
  final Semester? semester;
  final String? createdAt;
  final String? updatedAt;

  const SubjectOffering({
    this.id,
    this.subjectId,
    this.subject,
    this.semesterId,
    this.semester,
    this.createdAt,
    this.updatedAt,
  });

  factory SubjectOffering.fromJson(Map<String, dynamic> json) {
    final subjectJson = json['subject'];
    final semesterJson = json['semester'];
    return SubjectOffering(
      id: json['id'] as int?,
      subjectId: json['subjectId'] as int?,
      subject: subjectJson is Map<String, dynamic>
          ? Subject.fromJson(subjectJson)
          : null,
      semesterId: json['semesterId'] as int?,
      semester: semesterJson is Map<String, dynamic>
          ? Semester.fromJson(semesterJson)
          : null,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }
}

/// Mutable fields sent for POST/PUT `/api/admin/subject-offerings`.
///
/// Exactly two identities exist in the request contract: `subjectId` and
/// `semesterId`. Context ids (programId / academicSessionId / departmentId /
/// teacherId / sectionId / batchId) are deliberately absent.
class SubjectOfferingRequest {
  const SubjectOfferingRequest({
    required this.subjectId,
    required this.semesterId,
  });

  final int subjectId;
  final int semesterId;

  Map<String, dynamic> toJson() => {
        'subjectId': subjectId,
        'semesterId': semesterId,
      };
}