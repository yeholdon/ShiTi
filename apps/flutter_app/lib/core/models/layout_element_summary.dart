class LayoutElementSummary {
  const LayoutElementSummary({
    required this.id,
    required this.name,
    required this.description,
    this.previewBlocks = const <Map<String, dynamic>>[],
  });

  final String id;
  final String name;
  final String description;
  final List<Map<String, dynamic>> previewBlocks;
}
