/// Matches backend `AttendanceSessionCreateRequestDTO`.
///
/// Exactly one of [sectionId] | [batchId] is set (XOR). Section mode is used
/// for sectioned batches; batch mode targets a zero-section batch.
class AttendanceSessionCreateRequest {
  final int subjectId;
  final int? sectionId;
  final int? batchId;
  final String lecturePeriod;
  final String date;

  const AttendanceSessionCreateRequest({
    required this.subjectId,
    this.sectionId,
    this.batchId,
    required this.lecturePeriod,
    required this.date,
  });

  Map<String, dynamic> toJson() {
    return {
      'subjectId': subjectId,
      if (sectionId != null) 'sectionId': sectionId,
      if (batchId != null) 'batchId': batchId,
      'lecturePeriod': lecturePeriod,
      'date': date,
    };
  }
}
