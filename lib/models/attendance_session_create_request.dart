/// Matches backend `AttendanceSessionCreateRequestDTO`.
class AttendanceSessionCreateRequest {
  final int subjectId;
  final int sectionId;
  final String lecturePeriod;
  final String date;

  const AttendanceSessionCreateRequest({
    required this.subjectId,
    required this.sectionId,
    required this.lecturePeriod,
    required this.date,
  });

  Map<String, dynamic> toJson() {
    return {
      'subjectId': subjectId,
      'sectionId': sectionId,
      'lecturePeriod': lecturePeriod,
      'date': date,
    };
  }
}
