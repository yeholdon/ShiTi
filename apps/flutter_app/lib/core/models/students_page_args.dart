class StudentsPageArgs {
  const StudentsPageArgs({
    this.focusStudentId,
    this.flashMessage,
    this.highlightTitle,
    this.highlightDetail,
    this.feedbackBadgeLabel,
  });

  final String? focusStudentId;
  final String? flashMessage;
  final String? highlightTitle;
  final String? highlightDetail;
  final String? feedbackBadgeLabel;
}
