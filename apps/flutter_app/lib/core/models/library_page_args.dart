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
  });

  final DocumentSummary? preferredDocumentSnapshot;
  final String? insertAfterItemId;
  final String? insertAfterItemTitle;
  final String? initialQuery;
  final String? initialSubjectLabel;
  final String? initialStageLabel;
  final String? initialTextbookLabel;
}
