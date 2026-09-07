/// Matches backend `AttendanceUpdateRequestDTO`.
class AttendanceUpdateRequest {
  final String newStatus;
  final String? reason;

  const AttendanceUpdateRequest({
    required this.newStatus,
    this.reason,
  });

  Map<String, dynamic> toJson() {
    return {
      'newStatus': newStatus,
      if (reason != null) 'reason': reason,
    };
  }
}
