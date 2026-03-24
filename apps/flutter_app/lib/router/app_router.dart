import 'package:flutter/material.dart';

import '../core/models/classes_page_args.dart';
import '../core/models/document_detail_args.dart';
import '../core/models/documents_page_args.dart';
import '../core/models/export_detail_args.dart';
import '../core/models/export_job_summary.dart';
import '../core/models/exports_page_args.dart';
import '../core/models/library_page_args.dart';
import '../core/models/lessons_page_args.dart';
import '../core/models/question_basket_page_args.dart';
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
import '../features/home/home_page.dart';
import '../features/library/library_page.dart';
import '../features/library/question_detail_page.dart';
import '../features/lessons/lessons_page.dart';
import '../features/settings/settings_page.dart';
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
  static const classes = '/classes';
  static const lessons = '/lessons';
  static const settings = '/settings';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case exports:
        final args = settings.arguments as ExportsPageArgs?;
        return MaterialPageRoute<void>(
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
        return MaterialPageRoute<void>(
          builder: (_) => DocumentDetailPage.fromArgs(
            args ?? const DocumentDetailArgs(documentId: 'doc-1'),
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
        return MaterialPageRoute<void>(
          builder: (_) => DocumentsPage(args: args),
          settings: settings,
        );
      case students:
        final args = settings.arguments as StudentsPageArgs?;
        return MaterialPageRoute<void>(
          builder: (_) => StudentsPage(args: args),
          settings: settings,
        );
      case classes:
        final args = settings.arguments as ClassesPageArgs?;
        return MaterialPageRoute<void>(
          builder: (_) => ClassesPage(args: args),
          settings: settings,
        );
      case lessons:
        final args = settings.arguments as LessonsPageArgs?;
        return MaterialPageRoute<void>(
          builder: (_) => LessonsPage(args: args),
          settings: settings,
        );
      case AppRouter.settings:
        return MaterialPageRoute<void>(
          builder: (_) => const SettingsPage(),
          settings: settings,
        );
      case questionDetail:
        final args = settings.arguments as QuestionDetailArgs?;
        return MaterialPageRoute<void>(
          builder: (_) => QuestionDetailPage.fromArgs(
            args ?? const QuestionDetailArgs(questionId: 'q-1'),
          ),
          settings: settings,
        );
      case login:
        return MaterialPageRoute<void>(
          builder: (_) => const LoginPage(),
          settings: settings,
        );
      case account:
        return MaterialPageRoute<void>(
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
        return MaterialPageRoute<void>(
          builder: (_) => LibraryPage(args: args),
          settings: settings,
        );
      case home:
      default:
        return MaterialPageRoute<void>(
          builder: (_) => const HomePage(),
          settings: settings,
        );
    }
  }
}
