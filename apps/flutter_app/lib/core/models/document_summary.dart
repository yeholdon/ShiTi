class DocumentSummary {
  const DocumentSummary({
    required this.id,
    required this.name,
    required this.kind,
    required this.questionCount,
    required this.layoutCount,
    required this.latestExportStatus,
    this.latestExportJobId,
    this.previewBlocks = const <Map<String, dynamic>>[],
  });

  final String id;
  final String name;
  final String kind;
  final int questionCount;
  final int layoutCount;
  final String latestExportStatus;
  final String? latestExportJobId;
  final List<Map<String, dynamic>> previewBlocks;

  DocumentSummary copyWith({
    String? id,
    String? name,
    String? kind,
    int? questionCount,
    int? layoutCount,
    String? latestExportStatus,
    String? latestExportJobId,
    List<Map<String, dynamic>>? previewBlocks,
  }) {
    return DocumentSummary(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      questionCount: questionCount ?? this.questionCount,
      layoutCount: layoutCount ?? this.layoutCount,
      latestExportStatus: latestExportStatus ?? this.latestExportStatus,
      latestExportJobId: latestExportJobId ?? this.latestExportJobId,
      previewBlocks: previewBlocks ?? this.previewBlocks,
    );
  }
}
