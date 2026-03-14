import 'document_summary.dart';
import 'export_job_summary.dart';

class ExportDetailArgs {
  const ExportDetailArgs({
    required this.job,
    this.documentSnapshot,
  });

  final ExportJobSummary job;
  final DocumentSummary? documentSnapshot;
}
