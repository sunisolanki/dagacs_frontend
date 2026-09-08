/// Minimal Spring `Page<T>` projection used by the paginated HOD report feeds
/// (`/api/hod/reports/daily-lecture`, `/api/hod/coverage`).
class ReportPage<T> {
  final List<T> items;
  final int page;
  final int totalPages;

  const ReportPage({
    required this.items,
    required this.page,
    required this.totalPages,
  });

  /// Parses the Spring page envelope given a row-level [fromJson].
  factory ReportPage.fromJson(
      Map<String, dynamic> json, T Function(Map<String, dynamic>) fromJson) {
    final content = (json['content'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return ReportPage<T>(
      items: content,
      page: (json['number'] as num?)?.toInt() ?? 0,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 0,
    );
  }
}