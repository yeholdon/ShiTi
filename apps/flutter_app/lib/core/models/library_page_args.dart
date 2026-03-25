import 'document_summary.dart';

class LibraryPageArgs {
  const LibraryPageArgs({
    this.preferredDocumentSnapshot,
    this.insertAfterItemId,
    this.insertAfterItemTitle,
    this.initialQuery,
    this.initialSubjectLabel,
    this.initialStageLabel,
    this.initialTextbookLabel,
    this.flashMessage,
    this.highlightTitle,
    this.highlightDetail,
    this.feedbackBadgeLabel,
    this.sourceModule,
    this.sourceRecordId,
    this.sourceLabel,
  });

  final DocumentSummary? preferredDocumentSnapshot;
  final String? insertAfterItemId;
  final String? insertAfterItemTitle;
  final String? initialQuery;
  final String? initialSubjectLabel;
  final String? initialStageLabel;
  final String? initialTextbookLabel;
  final String? flashMessage;
  final String? highlightTitle;
  final String? highlightDetail;
  final String? feedbackBadgeLabel;
  final String? sourceModule;
  final String? sourceRecordId;
  final String? sourceLabel;
}
