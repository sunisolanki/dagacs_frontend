/// Matches the backend `HodRollupDTO` for `type=monthly` and `type=quarterly`.
///
/// Semester rollups are NOT DERIVABLE / NOT IMPLEMENTED by the backend, so a
/// [period] here is always a monthly (`YYYY-MM`) or quarterly (`YYYY-QN`)
/// label. [percentage] is nullable — `null` never renders as 0%.
class HodRollup {
  final String period;
  final int presentCount;
  final int totalRecordedCount;
  final double? percentage;

  const HodRollup({
    required this.period,
    required this.presentCount,
    required this.totalRecordedCount,
    this.percentage,
  });

  factory HodRollup.fromJson(Map<String, dynamic> json) {
    return HodRollup(
      period: json['period'] as String? ?? '',
      presentCount: (json['presentCount'] as num?)?.toInt() ?? 0,
      totalRecordedCount: (json['totalRecordedCount'] as num?)?.toInt() ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble(),
    );
  }
}