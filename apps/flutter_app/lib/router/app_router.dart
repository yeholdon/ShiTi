import 'package:flutter/material.dart';

import '../core/models/class_detail_args.dart';
import '../core/models/classes_page_args.dart';
import '../core/models/document_detail_args.dart';
import '../core/models/documents_page_args.dart';
import '../core/models/export_detail_args.dart';
import '../core/models/export_job_summary.dart';
import '../core/models/exports_page_args.dart';
import '../core/models/lesson_detail_args.dart';
import '../core/models/library_page_args.dart';
import '../core/models/lessons_page_args.dart';
import '../core/models/question_basket_page_args.dart';
import '../core/models/student_detail_args.dart';
import '../core/models/students_page_args.dart';
import '../features/account/account_page.dart';
import '../features/auth/login_page.dart';
import '../features/basket/question_basket_page.dart';
import '../features/documents/document_detail_page.dart';
import '../features/documents/documents_page.dart';
import '../features/exports/export_detail_page.dart';
import '../features/exports/exports_page.dart';
import '../features/exports/export_result_page.dart';
import '../features/classes/classes_page.dart';
import '../features/classes/class_detail_page.dart';
import '../features/home/home_page.dart';
import '../features/library/library_page.dart';
import '../features/library/question_detail_page.dart';
import '../features/lessons/lesson_detail_page.dart';
import '../features/lessons/lessons_page.dart';
import '../features/settings/settings_page.dart';
import '../features/students/student_detail_page.dart';
import '../features/students/students_page.dart';
import '../features/tenants/tenant_switch_page.dart';
import '../features/tenants/tenant_members_page.dart';
import '../core/models/question_detail_args.dart';

class AppRouter {
  static const home = '/';
  static const account = '/me';
  static const library = '/library';
  static const login = '/login';
  static const tenantSwitch = '/tenants';
  static const tenantMembers = '/tenants/members';
  static const questionDetail = '/questions/detail';
  static const basket = '/basket';
  static const documents = '/documents';
  static const documentDetail = '/documents/detail';
  static const exports = '/exports';
  static const exportDetail = '/exports/detail';
  static const exportResult = '/exports/result';
  static const students = '/students';
  static const studentDetail = '/students/detail';
  static const classes = '/classes';
  static const classDetail = '/classes/detail';
  static const lessons = '/lessons';
  static const lessonDetail = '/lessons/detail';
  static const settings = '/settings';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final routeUri = Uri.tryParse(settings.name ?? home);
    final routePath = routeUri?.path.isNotEmpty == true ? routeUri!.path : home;

    switch (routePath) {
      case exports:
        final args = settings.arguments as ExportsPageArgs?;
        return _workspaceModuleRoute(
          builder: (_) => ExportsPage(args: args),
          settings: settings,
        );
      case exportDetail:
        final args = settings.arguments as ExportDetailArgs?;
        return MaterialPageRoute<void>(
          builder: (_) => ExportDetailPage(
            args: args ??
                const ExportDetailArgs(
                  job: ExportJobSummary(
                    id: 'job-1',
                    documentName: '九上相似专题讲义',
                    format: 'pdf',
                    status: 'succeeded',
                    updatedAtLabel: '刚刚',
                  ),
                ),
          ),
          settings: settings,
        );
      case exportResult:
        final args = settings.arguments as ExportDetailArgs?;
        return MaterialPageRoute<void>(
          builder: (_) => ExportResultPage(
            args: args ??
                const ExportDetailArgs(
                  job: ExportJobSummary(
                    id: 'job-1',
                    documentName: '九上相似专题讲义',
                    format: 'pdf',
                    status: 'succeeded',
                    updatedAtLabel: '刚刚',
                  ),
                ),
          ),
          settings: settings,
        );
      case documentDetail:
        final args = settings.arguments as DocumentDetailArgs?;
        final documentId =
            routeUri?.queryParameters['documentId']?.trim().isNotEmpty == true
                ? routeUri!.queryParameters['documentId']!.trim()
                : 'doc-1';
        return MaterialPageRoute<void>(
          builder: (_) => DocumentDetailPage.fromArgs(
            args ?? DocumentDetailArgs(documentId: documentId),
          ),
          settings: settings,
        );
      case basket:
        final args = settings.arguments as QuestionBasketPageArgs?;
        return MaterialPageRoute<void>(
          builder: (_) => QuestionBasketPage(args: args),
          settings: settings,
        );
      case documents:
        final args = settings.arguments as DocumentsPageArgs?;
        final focusDocumentId =
            routeUri?.queryParameters['focusDocumentId']?.trim().isNotEmpty == true
                ? routeUri!.queryParameters['focusDocumentId']!.trim()
                : null;
        final flashMessage =
            routeUri?.queryParameters['flashMessage']?.trim().isNotEmpty == true
                ? routeUri!.queryParameters['flashMessage']!.trim()
                : null;
        final highlightTitle =
            routeUri?.queryParameters['highlightTitle']?.trim().isNotEmpty == true
                ? routeUri!.queryParameters['highlightTitle']!.trim()
                : null;
        final highlightDetail =
            routeUri?.queryParameters['highlightDetail']?.trim().isNotEmpty == true
                ? routeUri!.queryParameters['highlightDetail']!.trim()
                : null;
        final feedbackBadgeLabel =
            routeUri?.queryParameters['feedbackBadgeLabel']?.trim().isNotEmpty == true
                ? routeUri!.queryParameters['feedbackBadgeLabel']!.trim()
                : null;
        final sourceModule =
            routeUri?.queryParameters['sourceModule']?.trim().isNotEmpty == true
                ? routeUri!.queryParameters['sourceModule']!.trim()
                : null;
        final sourceRecordId =
            routeUri?.queryParameters['sourceRecordId']?.trim().isNotEmpty == true
                ? routeUri!.queryParameters['sourceRecordId']!.trim()
                : null;
        final sourceLabel =
            routeUri?.queryParameters['sourceLabel']?.trim().isNotEmpty == true
                ? routeUri!.queryParameters['sourceLabel']!.trim()
                : null;
        return _workspaceModuleRoute(
          builder: (_) => DocumentsPage(
            args: args ??
                DocumentsPageArgs(
                  focusDocumentId: focusDocumentId,
                  flashMessage: flashMessage,
                  highlightTitle: highlightTitle,
                  highlightDetail: highlightDetail,
                  feedbackBadgeLabel: feedbackBadgeLabel,
                  sourceModule: sourceModule,
                  sourceRecordId: sourceRecordId,
                  sourceLabel: sourceLabel,
                ),
          ),
          settings: settings,
        );
      case students:
        final args = settings.arguments as StudentsPageArgs?;
        final focusStudentId =
            routeUri?.queryParameters['focusStudentId']?.trim().isNotEmpty == true
                ? routeUri!.queryParameters['focusStudentId']!.trim()
                : null;
        final flashMessage =
            routeUri?.queryParameters['flashMessage']?.trim().isNotEmpty == true
                ? routeUri!.queryParameters['flashMessage']!.trim()
                : null;
        final highlightTitle =
            routeUri?.queryParameters['highlightTitle']?.trim().isNotEmpty == true
                ? routeUri!.queryParameters['highlightTitle']!.trim()
                : null;
        final highlightDetail =
            routeUri?.queryParameters['highlightDetail']?.trim().isNotEmpty == true
                ? routeUri!.queryParameters['highlightDetail']!.trim()
                : null;
        final feedbackBadgeLabel =
            routeUri?.queryParameters['feedbackBadgeLabel']?.trim().isNotEmpty == true
                ? routeUri!.queryParameters['feedbackBadgeLabel']!.trim()
                : null;
        return _workspaceModuleRoute(
          builder: (_) => StudentsPage(
            args: args ??
                StudentsPageArgs(
                  focusStudentId: focusStudentId,
                  flashMessage: flashMessage,
                  highlightTitle: highlightTitle,
                  highlightDetail: highlightDetail,
                  feedbackBadgeLabel: feedbackBadgeLabel,
                ),
          ),
          settings: settings,
        );
      case studentDetail:
        final args = settings.arguments as StudentDetailArgs?;
        final studentId =
            routeUri?.queryParameters['studentId']?.trim().isNotEmpty == true
                ? routeUri!.queryParameters['studentId']!.trim()
                : 'student-1';
        return MaterialPageRoute<void>(
          builder: (_) => StudentDetailPage.fromArgs(
            args ?? StudentDetailArgs(studentId: studentId),
          ),
          settings: settings,
        );
      case classes:
        final args = settings.arguments as ClassesPageArgs?;
        final focusClassId =
            routeUri?.queryParameters['focusClassId']?.trim().isNotEmpty == true
                ? routeUri!.queryParameters['focusClassId']!.trim()
                : null;
        final flashMessage =
            routeUri?.queryParameters['flashMessage']?.trim().isNotEmpty == true
                ? routeUri!.queryParameters['flashMessage']!.trim()
                : null;
        final highlightTitle =
            routeUri?.queryParameters['highlightTitle']?.trim().isNotEmpty == true
                ? routeUri!.queryParameters['highlightTitle']!.trim()
                : null;
        final highlightDetail =
            routeUri?.queryParameters['highlightDetail']?.trim().isNotEmpty == true
                ? routeUri!.queryParameters['highlightDetail']!.trim()
                : null;
        final feedbackBadgeLabel =
            routeUri?.queryParameters['feedbackBadgeLabel']?.trim().isNotEmpty == true
                ? routeUri!.queryParameters['feedbackBadgeLabel']!.trim()
                : null;
        return _workspaceModuleRoute(
          builder: (_) => ClassesPage(
            args: args ??
                ClassesPageArgs(
                  focusClassId: focusClassId,
                  flashMessage: flashMessage,
                  highlightTitle: highlightTitle,
                  highlightDetail: highlightDetail,
                  feedbackBadgeLabel: feedbackBadgeLabel,
                ),
          ),
          settings: settings,
        );
      case classDetail:
        final args = settings.arguments as ClassDetailArgs?;
        final classId =
            routeUri?.queryParameters['classId']?.trim().isNotEmpty == true
                ? routeUri!.queryParameters['classId']!.trim()
                : 'class-1';
        return MaterialPageRoute<void>(
          builder: (_) => ClassDetailPage.fromArgs(
            args ?? ClassDetailArgs(classId: classId),
          ),
          settings: settings,
        );
      case lessons:
        final args = settings.arguments as LessonsPageArgs?;
        final focusLessonId =
            routeUri?.queryParameters['focusLessonId']?.trim().isNotEmpty == true
                ? routeUri!.queryParameters['focusLessonId']!.trim()
                : null;
        final flashMessage =
            routeUri?.queryParameters['flashMessage']?.trim().isNotEmpty == true
                ? routeUri!.queryParameters['flashMessage']!.trim()
                : null;
        final highlightTitle =
            routeUri?.queryParameters['highlightTitle']?.trim().isNotEmpty == true
                ? routeUri!.queryParameters['highlightTitle']!.trim()
                : null;
        final highlightDetail =
            routeUri?.queryParameters['highlightDetail']?.trim().isNotEmpty == true
                ? routeUri!.queryParameters['highlightDetail']!.trim()
                : null;
        final feedbackBadgeLabel =
            routeUri?.queryParameters['feedbackBadgeLabel']?.trim().isNotEmpty == true
                ? routeUri!.queryParameters['feedbackBadgeLabel']!.trim()
                : null;
        return _workspaceModuleRoute(
          builder: (_) => LessonsPage(
            args: args ??
                LessonsPageArgs(
                  focusLessonId: focusLessonId,
                  flashMessage: flashMessage,
                  highlightTitle: highlightTitle,
                  highlightDetail: highlightDetail,
                  feedbackBadgeLabel: feedbackBadgeLabel,
                ),
          ),
          settings: settings,
        );
      case lessonDetail:
        final args = settings.arguments as LessonDetailArgs?;
        final lessonId =
            routeUri?.queryParameters['lessonId']?.trim().isNotEmpty == true
                ? routeUri!.queryParameters['lessonId']!.trim()
                : 'lesson-1';
        return MaterialPageRoute<void>(
          builder: (_) => LessonDetailPage.fromArgs(
            args ?? LessonDetailArgs(lessonId: lessonId),
          ),
          settings: settings,
        );
      case AppRouter.settings:
        return _workspaceModuleRoute(
          builder: (_) => const SettingsPage(),
          settings: settings,
        );
      case questionDetail:
        final args = settings.arguments as QuestionDetailArgs?;
        final questionId =
            routeUri?.queryParameters['questionId']?.trim().isNotEmpty == true
                ? routeUri!.queryParameters['questionId']!.trim()
                : 'q-1';
        final initialQuery =
            routeUri?.queryParameters['initialQuery']?.trim().isNotEmpty == true
                ? routeUri!.queryParameters['initialQuery']!.trim()
                : null;
        final initialSubjectLabel =
            routeUri?.queryParameters['initialSubjectLabel']?.trim().isNotEmpty ==
                    true
                ? routeUri!.queryParameters['initialSubjectLabel']!.trim()
                : null;
        final initialStageLabel =
            routeUri?.queryParameters['initialStageLabel']?.trim().isNotEmpty ==
                    true
                ? routeUri!.queryParameters['initialStageLabel']!.trim()
                : null;
        final initialTextbookLabel = routeUri
                    ?.queryParameters['initialTextbookLabel']
                    ?.trim()
                    .isNotEmpty ==
                true
            ? routeUri!.queryParameters['initialTextbookLabel']!.trim()
            : null;
        final flashMessage =
            routeUri?.queryParameters['flashMessage']?.trim().isNotEmpty == true
                ? routeUri!.queryParameters['flashMessage']!.trim()
                : null;
        final highlightTitle =
            routeUri?.queryParameters['highlightTitle']?.trim().isNotEmpty == true
                ? routeUri!.queryParameters['highlightTitle']!.trim()
                : null;
        final highlightDetail =
            routeUri?.queryParameters['highlightDetail']?.trim().isNotEmpty == true
                ? routeUri!.queryParameters['highlightDetail']!.trim()
                : null;
        final feedbackBadgeLabel = routeUri
                    ?.queryParameters['feedbackBadgeLabel']
                    ?.trim()
                    .isNotEmpty ==
                true
            ? routeUri!.queryParameters['feedbackBadgeLabel']!.trim()
            : null;
        final sourceModule =
            routeUri?.queryParameters['sourceModule']?.trim().isNotEmpty == true
                ? routeUri!.queryParameters['sourceModule']!.trim()
                : null;
        final sourceRecordId =
            routeUri?.queryParameters['sourceRecordId']?.trim().isNotEmpty == true
                ? routeUri!.queryParameters['sourceRecordId']!.trim()
                : null;
        final sourceLabel =
            routeUri?.queryParameters['sourceLabel']?.trim().isNotEmpty == true
                ? routeUri!.queryParameters['sourceLabel']!.trim()
                : null;
        final insertAfterItemId = routeUri
                    ?.queryParameters['insertAfterItemId']
                    ?.trim()
                    .isNotEmpty ==
                true
            ? routeUri!.queryParameters['insertAfterItemId']!.trim()
            : null;
        final insertAfterItemTitle = routeUri
                    ?.queryParameters['insertAfterItemTitle']
                    ?.trim()
                    .isNotEmpty ==
                true
            ? routeUri!.queryParameters['insertAfterItemTitle']!.trim()
            : null;
        final hasLibraryContext = [
          initialQuery,
          initialSubjectLabel,
          initialStageLabel,
          initialTextbookLabel,
          flashMessage,
          highlightTitle,
          highlightDetail,
          feedbackBadgeLabel,
          sourceModule,
          sourceRecordId,
          sourceLabel,
          insertAfterItemId,
          insertAfterItemTitle,
        ].any((value) => (value ?? '').trim().isNotEmpty);
        return MaterialPageRoute<void>(
          builder: (_) => QuestionDetailPage.fromArgs(
            args ??
                QuestionDetailArgs(
                  questionId: questionId,
                  insertAfterItemId: insertAfterItemId,
                  insertAfterItemTitle: insertAfterItemTitle,
                  libraryContextArgs: hasLibraryContext
                      ? LibraryPageArgs(
                          initialQuery: initialQuery,
                          initialSubjectLabel: initialSubjectLabel,
                          initialStageLabel: initialStageLabel,
                          initialTextbookLabel: initialTextbookLabel,
                          flashMessage: flashMessage,
                          highlightTitle: highlightTitle,
                          highlightDetail: highlightDetail,
                          feedbackBadgeLabel: feedbackBadgeLabel,
                          sourceModule: sourceModule,
                          sourceRecordId: sourceRecordId,
                          sourceLabel: sourceLabel,
                        )
                      : null,
                ),
          ),
          settings: settings,
        );
      case login:
        return MaterialPageRoute<void>(
          builder: (_) => const LoginPage(),
          settings: settings,
        );
      case account:
        return _workspaceModuleRoute(
          builder: (_) => const AccountPage(),
          settings: settings,
        );
      case tenantSwitch:
        return MaterialPageRoute<void>(
          builder: (_) => const TenantSwitchPage(),
          settings: settings,
        );
      case tenantMembers:
        return MaterialPageRoute<void>(
          builder: (_) => const TenantMembersPage(),
          settings: settings,
        );
      case library:
        final args = settings.arguments as LibraryPageArgs?;
        final initialQuery =
            routeUri?.queryParameters['initialQuery']?.trim().isNotEmpty == true
                ? routeUri!.queryParameters['initialQuery']!.trim()
                : null;
        final initialSubjectLabel =
            routeUri?.queryParameters['initialSubjectLabel']?.trim().isNotEmpty == true
                ? routeUri!.queryParameters['initialSubjectLabel']!.trim()
                : null;
        final initialStageLabel =
            routeUri?.queryParameters['initialStageLabel']?.trim().isNotEmpty == true
                ? routeUri!.queryParameters['initialStageLabel']!.trim()
                : null;
        final initialTextbookLabel =
            routeUri?.queryParameters['initialTextbookLabel']?.trim().isNotEmpty == true
                ? routeUri!.queryParameters['initialTextbookLabel']!.trim()
                : null;
        final flashMessage =
            routeUri?.queryParameters['flashMessage']?.trim().isNotEmpty == true
                ? routeUri!.queryParameters['flashMessage']!.trim()
                : null;
        final highlightTitle =
            routeUri?.queryParameters['highlightTitle']?.trim().isNotEmpty == true
                ? routeUri!.queryParameters['highlightTitle']!.trim()
                : null;
        final highlightDetail =
            routeUri?.queryParameters['highlightDetail']?.trim().isNotEmpty == true
                ? routeUri!.queryParameters['highlightDetail']!.trim()
                : null;
        final feedbackBadgeLabel =
            routeUri?.queryParameters['feedbackBadgeLabel']?.trim().isNotEmpty == true
                ? routeUri!.queryParameters['feedbackBadgeLabel']!.trim()
                : null;
        final sourceModule =
            routeUri?.queryParameters['sourceModule']?.trim().isNotEmpty == true
                ? routeUri!.queryParameters['sourceModule']!.trim()
                : null;
        final sourceRecordId =
            routeUri?.queryParameters['sourceRecordId']?.trim().isNotEmpty == true
                ? routeUri!.queryParameters['sourceRecordId']!.trim()
                : null;
        final sourceLabel =
            routeUri?.queryParameters['sourceLabel']?.trim().isNotEmpty == true
                ? routeUri!.queryParameters['sourceLabel']!.trim()
                : null;
        return _workspaceModuleRoute(
          builder: (_) => LibraryPage(
            args: args ??
                LibraryPageArgs(
                  initialQuery: initialQuery,
                  initialSubjectLabel: initialSubjectLabel,
                  initialStageLabel: initialStageLabel,
                  initialTextbookLabel: initialTextbookLabel,
                  flashMessage: flashMessage,
                  highlightTitle: highlightTitle,
                  highlightDetail: highlightDetail,
                  feedbackBadgeLabel: feedbackBadgeLabel,
                  sourceModule: sourceModule,
                  sourceRecordId: sourceRecordId,
                  sourceLabel: sourceLabel,
                ),
          ),
          settings: settings,
        );
      case home:
      default:
        return _workspaceModuleRoute(
          builder: (_) => const HomePage(),
          settings: settings,
        );
    }
  }

  static Route<void> _workspaceModuleRoute({
    required WidgetBuilder builder,
    required RouteSettings settings,
  }) {
    return PageRouteBuilder<void>(
      settings: settings,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    );
  }
}
