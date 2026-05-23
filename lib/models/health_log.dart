class HealthLog {
  final String id;
  final String diagnosis;
  final String? diagnosisCategory;
  final String? treatment;
  final String severity;
  final DateTime? resolvedAt;
  final DateTime createdAt;

  const HealthLog({
    required this.id,
    required this.diagnosis,
    this.diagnosisCategory,
    this.treatment,
    required this.severity,
    this.resolvedAt,
    required this.createdAt,
  });

  bool get isResolved => resolvedAt != null;

  factory HealthLog.fromJson(Map<String, dynamic> json) {
    return HealthLog(
      id:                json['id'] as String,
      diagnosis:         json['diagnosis'] as String,
      diagnosisCategory: json['diagnosisCategory'] as String?,
      treatment:         json['treatment'] as String?,
      severity:          json['severity'] as String,
      resolvedAt:        json['resolvedAt'] != null
                           ? DateTime.parse(json['resolvedAt'] as String)
                           : null,
      createdAt:         DateTime.parse(json['createdAt'] as String),
    );
  }
}
