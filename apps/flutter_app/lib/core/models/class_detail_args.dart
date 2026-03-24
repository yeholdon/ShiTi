class ClassDetailArgs {
  const ClassDetailArgs({
    required this.classId,
    this.flashMessage,
  });

  final String classId;
  final String? flashMessage;
}
