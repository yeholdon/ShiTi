class DocumentItemSummary {
  const DocumentItemSummary({
    required this.id,
    required this.kind,
    required this.title,
    required this.detail,
    this.previewBlocks = const <Map<String, dynamic>>[],
  });

  final String id;
  final String kind;
  final String title;
  final String detail;
  final List<Map<String, dynamic>> previewBlocks;
}
