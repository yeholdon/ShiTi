class ExportJobSummary {
  const ExportJobSummary({
    required this.id,
    required this.documentName,
    required this.format,
    required this.status,
    required this.updatedAtLabel,
    this.documentId,
  });

  final String id;
  final String documentName;
  final String format;
  final String status;
  final String updatedAtLabel;
  final String? documentId;

  ExportJobSummary copyWith({
    String? id,
    String? documentName,
    String? format,
    String? status,
    String? updatedAtLabel,
    String? documentId,
  }) {
    return ExportJobSummary(
      id: id ?? this.id,
      documentName: documentName ?? this.documentName,
      format: format ?? this.format,
      status: status ?? this.status,
      updatedAtLabel: updatedAtLabel ?? this.updatedAtLabel,
      documentId: documentId ?? this.documentId,
    );
  }
}
