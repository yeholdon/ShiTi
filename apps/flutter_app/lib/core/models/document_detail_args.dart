import 'document_summary.dart';

class DocumentDetailArgs {
  const DocumentDetailArgs({
    required this.documentId,
    this.documentSnapshot,
    this.focusItemId,
    this.focusItemTitle,
    this.focusExportJobId,
    this.recentlyAddedQuestionCount,
  });

  final String documentId;
  final DocumentSummary? documentSnapshot;
  final String? focusItemId;
  final String? focusItemTitle;
  final String? focusExportJobId;
  final int? recentlyAddedQuestionCount;
}
