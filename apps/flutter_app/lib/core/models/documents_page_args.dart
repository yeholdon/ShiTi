import 'document_summary.dart';

class DocumentsPageArgs {
  const DocumentsPageArgs({
    this.focusDocumentId,
    this.documentSnapshot,
    this.flashMessage,
    this.highlightTitle,
    this.highlightDetail,
    this.recentlyAddedQuestionCount,
    this.feedbackBadgeLabel,
    this.sourceModule,
    this.sourceRecordId,
    this.sourceLabel,
  });

  final String? focusDocumentId;
  final DocumentSummary? documentSnapshot;
  final String? flashMessage;
  final String? highlightTitle;
  final String? highlightDetail;
  final int? recentlyAddedQuestionCount;
  final String? feedbackBadgeLabel;
  final String? sourceModule;
  final String? sourceRecordId;
  final String? sourceLabel;
}
