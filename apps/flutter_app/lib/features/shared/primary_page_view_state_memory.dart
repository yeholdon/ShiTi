import '../../core/models/library_filter_state.dart';

class PrimaryLibraryViewState {
  const PrimaryLibraryViewState({
    required this.filters,
    required this.showOnlySelectedQuestions,
    required this.basketFilter,
    required this.gradeFilter,
    required this.chapterFilter,
    required this.sortBy,
  });

  final LibraryFilterState filters;
  final bool showOnlySelectedQuestions;
  final String basketFilter;
  final String gradeFilter;
  final String chapterFilter;
  final String sortBy;
}

class PrimaryDocumentsViewState {
  const PrimaryDocumentsViewState({
    required this.query,
    required this.kindFilter,
    required this.exportStatusFilter,
    required this.sortBy,
    required this.showOnlySelectedDocuments,
  });

  final String query;
  final String kindFilter;
  final String exportStatusFilter;
  final String sortBy;
  final bool showOnlySelectedDocuments;
}

class PrimaryExportsViewState {
  const PrimaryExportsViewState({
    required this.query,
    required this.statusFilter,
    required this.formatFilter,
    required this.sortBy,
    required this.showOnlySelectedJobs,
    required this.showOnlyCurrentDocument,
  });

  final String query;
  final String statusFilter;
  final String formatFilter;
  final String sortBy;
  final bool showOnlySelectedJobs;
  final bool showOnlyCurrentDocument;
}

class PrimaryStudentsViewState {
  const PrimaryStudentsViewState({
    required this.query,
    required this.filter,
    required this.selectedStudentId,
  });

  final String query;
  final String filter;
  final String selectedStudentId;
}

class PrimaryClassesViewState {
  const PrimaryClassesViewState({
    required this.query,
    required this.filter,
    required this.selectedClassId,
  });

  final String query;
  final String filter;
  final String selectedClassId;
}

class PrimaryLessonsViewState {
  const PrimaryLessonsViewState({
    required this.query,
    required this.filter,
    required this.selectedLessonId,
  });

  final String query;
  final String filter;
  final String selectedLessonId;
}

class PrimaryPageViewStateMemory {
  static PrimaryLibraryViewState? library;
  static PrimaryDocumentsViewState? documents;
  static PrimaryExportsViewState? exports;
  static PrimaryStudentsViewState? students;
  static PrimaryClassesViewState? classes;
  static PrimaryLessonsViewState? lessons;
}
