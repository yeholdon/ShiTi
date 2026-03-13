class QuestionSummary {
  const QuestionSummary({
    required this.id,
    required this.title,
    required this.subject,
    required this.stage,
    required this.grade,
    required this.textbook,
    required this.chapter,
    required this.difficulty,
    required this.tags,
    required this.stemPreview,
  });

  final String id;
  final String title;
  final String subject;
  final String stage;
  final String grade;
  final String textbook;
  final String chapter;
  final int difficulty;
  final List<String> tags;
  final String stemPreview;
}
