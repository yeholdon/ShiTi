class LibraryFilterState {
  const LibraryFilterState({
    this.subject = '全部学科',
    this.stage = '全部学段',
    this.textbook = '全部教材',
    this.query = '',
  });

  final String subject;
  final String stage;
  final String textbook;
  final String query;

  LibraryFilterState copyWith({
    String? subject,
    String? stage,
    String? textbook,
    String? query,
  }) {
    return LibraryFilterState(
      subject: subject ?? this.subject,
      stage: stage ?? this.stage,
      textbook: textbook ?? this.textbook,
      query: query ?? this.query,
    );
  }
}
