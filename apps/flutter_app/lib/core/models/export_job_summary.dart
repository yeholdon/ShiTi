class ExportJobSummary {
  const ExportJobSummary({
    required this.id,
    required this.documentName,
    required this.format,
    required this.status,
    required this.updatedAtLabel,
  });

  final String id;
  final String documentName;
  final String format;
  final String status;
  final String updatedAtLabel;
}
