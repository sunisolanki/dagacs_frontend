/// Matches the backend M5.1 `StudentProfileDTO`.
///
/// Read-only academic profile of the authenticated student. The backend resolves
/// the identity from the JWT — Flutter never supplies a studentId.
class StudentProfile {
  final String? rollNumber;
  final String? enrollmentNumber;
  final String? email;
  final String? name;
  final String? gender;
  final String? fatherName;
  final String? motherName;
  final String? photoUrl;
  final int? age;
  final String? admissionDate;
  final String? status;
  final String? batchName;
  final String? programName;
  final String? sectionName;

  const StudentProfile({
    this.rollNumber,
    this.enrollmentNumber,
    this.email,
    this.name,
    this.gender,
    this.fatherName,
    this.motherName,
    this.photoUrl,
    this.age,
    this.admissionDate,
    this.status,
    this.batchName,
    this.programName,
    this.sectionName,
  });

  factory StudentProfile.fromJson(Map<String, dynamic> json) {
    return StudentProfile(
      rollNumber: json['rollNumber'] as String?,
      enrollmentNumber: json['enrollmentNumber'] as String?,
      email: json['email'] as String?,
      name: json['name'] as String?,
      gender: json['gender'] as String?,
      fatherName: json['fatherName'] as String?,
      motherName: json['motherName'] as String?,
      photoUrl: json['photoUrl'] as String?,
      age: json['age'] as int?,
      admissionDate: json['admissionDate'] as String?,
      status: json['status'] as String?,
      batchName: json['batchName'] as String?,
      programName: json['programName'] as String?,
      sectionName: json['sectionName'] as String?,
    );
  }
}