class LessonDetailArgs {
  const LessonDetailArgs({
    required this.lessonId,
    this.flashMessage,
  });

  final String lessonId;
  final String? flashMessage;
}
