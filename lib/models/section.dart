import 'batch.dart';

/// Matches backend `SectionDTO`.
class Section {
  final int? id;
  final String? sectionCode;
  final String? name;
  final int? maxCapacity;
  final int? batchId;
  final Batch? batch;
  final String? createdAt;
  final String? updatedAt;

  const Section({
    this.id,
    this.sectionCode,
    this.name,
    this.maxCapacity,
    this.batchId,
    this.batch,
    this.createdAt,
    this.updatedAt,
  });

  factory Section.fromJson(Map<String, dynamic> json) {
    final batchJson = json['batch'];
    return Section(
      id: json['id'] as int?,
      sectionCode: json['sectionCode'] as String?,
      name: json['name'] as String?,
      maxCapacity: json['maxCapacity'] as int?,
      batchId: json['batchId'] as int?,
      batch: batchJson is Map<String, dynamic>
          ? Batch.fromJson(batchJson)
          : null,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }
}

/// Mutable fields sent for POST/PUT `/api/admin/sections`.
class SectionRequest {
  const SectionRequest({
    required this.sectionCode,
    required this.name,
    required this.maxCapacity,
    required this.batchId,
  });

  final String sectionCode;
  final String name;
  final int maxCapacity;
  final int batchId;

  Map<String, dynamic> toJson() => {
        'sectionCode': sectionCode,
        'name': name,
        'maxCapacity': maxCapacity,
        'batchId': batchId,
      };
}
