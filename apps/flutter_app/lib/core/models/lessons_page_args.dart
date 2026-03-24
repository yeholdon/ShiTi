class LessonsPageArgs {
  const LessonsPageArgs({
    this.focusLessonId,
    this.flashMessage,
    this.highlightTitle,
    this.highlightDetail,
    this.feedbackBadgeLabel,
  });

  final String? focusLessonId;
  final String? flashMessage;
  final String? highlightTitle;
  final String? highlightDetail;
  final String? feedbackBadgeLabel;
}
