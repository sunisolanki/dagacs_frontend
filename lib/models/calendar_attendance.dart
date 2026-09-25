class CalendarAttendance {
  final String date;
  final int presentCount;
  final int absentCount;
  final int totalRecordedCount;
  final double? percentage;

  CalendarAttendance({
    required this.date,
    required this.presentCount,
    required this.absentCount,
    required this.totalRecordedCount,
    this.percentage,
  });

  factory CalendarAttendance.fromJson(Map<String, dynamic> json) {
    return CalendarAttendance(
      date: json['date'] as String? ?? '',
      presentCount: (json['presentCount'] as num?)?.toInt() ?? 0,
      absentCount: (json['absentCount'] as num?)?.toInt() ?? 0,
      totalRecordedCount: (json['totalRecordedCount'] as num?)?.toInt() ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble(),
    );
  }
}
