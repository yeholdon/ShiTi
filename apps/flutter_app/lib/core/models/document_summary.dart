class DocumentSummary {
  const DocumentSummary({
    required this.id,
    required this.name,
    required this.kind,
    required this.questionCount,
    required this.layoutCount,
    required this.latestExportStatus,
  });

  final String id;
  final String name;
  final String kind;
  final int questionCount;
  final int layoutCount;
  final String latestExportStatus;
}
