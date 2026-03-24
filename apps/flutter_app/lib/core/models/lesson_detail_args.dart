class LessonDetailArgs {
  const LessonDetailArgs({
    required this.lessonId,
    this.flashMessage,
    this.sourceModule,
    this.sourceRecordId,
    this.sourceLabel,
  });

  final String lessonId;
  final String? flashMessage;
  final String? sourceModule;
  final String? sourceRecordId;
  final String? sourceLabel;
}
