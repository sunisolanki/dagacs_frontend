/// Matches backend `AttendanceMarkItemDTO`.
class AttendanceMarkItem {
  final int studentId;
  final String status;

  const AttendanceMarkItem({
    required this.studentId,
    required this.status,
  });

  Map<String, dynamic> toJson() {
    return {
      'studentId': studentId,
      'status': status,
    };
  }
}
