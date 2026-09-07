import 'attendance_mark_item.dart';

/// Matches backend `AttendanceMarkRequestDTO`.
class AttendanceMarkRequest {
  final int sessionId;
  final List<AttendanceMarkItem> items;

  const AttendanceMarkRequest({
    required this.sessionId,
    required this.items,
  });

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }
}
