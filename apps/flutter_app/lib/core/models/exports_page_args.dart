import 'document_summary.dart';

class ExportsPageArgs {
  const ExportsPageArgs({
    this.focusDocumentName,
    this.focusJobId,
    this.documentSnapshot,
  });

  final String? focusDocumentName;
  final String? focusJobId;
  final DocumentSummary? documentSnapshot;
}
