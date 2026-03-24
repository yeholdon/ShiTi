class StudentDetailArgs {
  const StudentDetailArgs({
    required this.studentId,
    this.flashMessage,
    this.sourceModule,
    this.sourceRecordId,
    this.sourceLabel,
  });

  final String studentId;
  final String? flashMessage;
  final String? sourceModule;
  final String? sourceRecordId;
  final String? sourceLabel;
}
