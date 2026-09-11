import 'academic_session.dart';
import 'section.dart';

/// Matches backend `BatchDTO`.
class Batch {
  final int? id;
  final String? batchCode;
  final String? name;
  final int? year;
  final int? academicSessionId;
  final AcademicSession? academicSession;
  final String? program;
  final int? maxCapacity;
  final List<Section> sections;
  final String? createdAt;
  final String? updatedAt;

  const Batch({
    this.id,
    this.batchCode,
    this.name,
    this.year,
    this.academicSessionId,
    this.academicSession,
    this.program,
    this.maxCapacity,
    this.sections = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory Batch.fromJson(Map<String, dynamic> json) {
    final sessionJson = json['academicSession'];
    return Batch(
      id: json['id'] as int?,
      batchCode: json['batchCode'] as String?,
      name: json['name'] as String?,
      year: json['year'] as int?,
      academicSessionId: json['academicSessionId'] as int?,
      academicSession: sessionJson is Map<String, dynamic>
          ? AcademicSession.fromJson(sessionJson)
          : null,
      program: json['program'] as String?,
      maxCapacity: json['maxCapacity'] as int?,
      sections: (json['sections'] as List?)
          ?.whereType<Map>()
          .map((e) => Section.fromJson(Map<String, dynamic>.from(e)))
          .toList() ??
          const [],
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }
}

/// Mutable fields sent for POST/PUT `/api/admin/batches`.
class BatchRequest {
  const BatchRequest({
    required this.batchCode,
    required this.name,
    required this.year,
    required this.academicSessionId,
    required this.maxCapacity,
  });

  final String batchCode;
  final String name;
  final int year;
  final int academicSessionId;
  final int maxCapacity;

  Map<String, dynamic> toJson() => {
        'batchCode': batchCode,
        'name': name,
        'year': year,
        'academicSessionId': academicSessionId,
        'maxCapacity': maxCapacity,
      };
}
