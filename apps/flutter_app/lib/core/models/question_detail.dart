class QuestionDetail {
  const QuestionDetail({
    required this.id,
    required this.title,
    required this.subject,
    required this.stage,
    required this.grade,
    required this.textbook,
    required this.chapter,
    required this.difficulty,
    required this.tags,
    required this.stemBlocks,
    required this.analysisBlocks,
    required this.solutionBlocks,
    required this.commentaryBlocks,
    required this.stemText,
    required this.analysisText,
    required this.solutionText,
    required this.commentaryText,
    required this.sourceText,
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
  final List<Map<String, dynamic>> stemBlocks;
  final List<Map<String, dynamic>> analysisBlocks;
  final List<Map<String, dynamic>> solutionBlocks;
  final List<Map<String, dynamic>> commentaryBlocks;
  final String stemText;
  final String analysisText;
  final String solutionText;
  final String commentaryText;
  final String sourceText;
}
