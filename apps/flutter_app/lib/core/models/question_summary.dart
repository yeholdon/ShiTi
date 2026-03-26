class QuestionSummary {
  const QuestionSummary({
    required this.id,
    required this.title,
    required this.type,
    required this.subject,
    required this.stage,
    required this.grade,
    required this.textbook,
    required this.chapter,
    required this.difficulty,
    required this.defaultScore,
    required this.tags,
    required this.stemPreview,
    this.previewBlocks = const <Map<String, dynamic>>[],
  });

  final String id;
  final String title;
  final String type;
  final String subject;
  final String stage;
  final String grade;
  final String textbook;
  final String chapter;
  final int difficulty;
  final String defaultScore;
  final List<String> tags;
  final String stemPreview;
  final List<Map<String, dynamic>> previewBlocks;
}
