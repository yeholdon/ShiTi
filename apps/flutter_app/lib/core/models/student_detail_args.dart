class StudentDetailArgs {
  const StudentDetailArgs({
    required this.studentId,
    this.flashMessage,
  });

  final String studentId;
  final String? flashMessage;
}
