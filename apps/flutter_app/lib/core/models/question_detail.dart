class QuestionDetail {
  const QuestionDetail({
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
    required this.stemBlocks,
    required this.analysisBlocks,
    required this.solutionBlocks,
    required this.referenceAnswerBlocks,
    required this.scoringPointBlocks,
    required this.commentaryBlocks,
    required this.sourceBlocks,
    required this.stemText,
    required this.analysisText,
    required this.solutionText,
    required this.referenceAnswerText,
    required this.scoringPointsText,
    required this.commentaryText,
    required this.sourceText,
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
  final List<Map<String, dynamic>> stemBlocks;
  final List<Map<String, dynamic>> analysisBlocks;
  final List<Map<String, dynamic>> solutionBlocks;
  final List<Map<String, dynamic>> referenceAnswerBlocks;
  final List<Map<String, dynamic>> scoringPointBlocks;
  final List<Map<String, dynamic>> commentaryBlocks;
  final List<Map<String, dynamic>> sourceBlocks;
  final String stemText;
  final String analysisText;
  final String solutionText;
  final String referenceAnswerText;
  final String scoringPointsText;
  final String commentaryText;
  final String sourceText;
}
