/// Matches backend `AttendanceSessionUpdateRequestDTO`.
class AttendanceSessionUpdateRequest {
  final String lecturePeriod;
  final String date;
  final String status;

  const AttendanceSessionUpdateRequest({
    required this.lecturePeriod,
    required this.date,
    required this.status,
  });

  Map<String, dynamic> toJson() {
    return {
      'lecturePeriod': lecturePeriod,
      'date': date,
      'status': status,
    };
  }
}
