import 'document_summary.dart';
import 'library_page_args.dart';

class QuestionDetailArgs {
  const QuestionDetailArgs({
    required this.questionId,
    this.preferredDocumentSnapshot,
    this.insertAfterItemId,
    this.insertAfterItemTitle,
    this.libraryContextArgs,
  });

  final String questionId;
  final DocumentSummary? preferredDocumentSnapshot;
  final String? insertAfterItemId;
  final String? insertAfterItemTitle;
  final LibraryPageArgs? libraryContextArgs;
}
