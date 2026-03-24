class ClassDetailArgs {
  const ClassDetailArgs({
    required this.classId,
    this.flashMessage,
    this.sourceModule,
    this.sourceRecordId,
    this.sourceLabel,
  });

  final String classId;
  final String? flashMessage;
  final String? sourceModule;
  final String? sourceRecordId;
  final String? sourceLabel;
}
