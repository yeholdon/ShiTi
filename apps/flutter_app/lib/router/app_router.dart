import 'package:flutter/material.dart';

import '../core/models/document_detail_args.dart';
import '../features/auth/login_page.dart';
import '../features/basket/question_basket_page.dart';
import '../features/documents/document_detail_page.dart';
import '../features/documents/documents_page.dart';
import '../features/exports/exports_page.dart';
import '../features/home/home_page.dart';
import '../features/library/library_page.dart';
import '../features/library/question_detail_page.dart';
import '../features/tenants/tenant_switch_page.dart';
import '../core/models/question_detail_args.dart';

class AppRouter {
  static const home = '/';
  static const library = '/library';
  static const login = '/login';
  static const tenantSwitch = '/tenants';
  static const questionDetail = '/questions/detail';
  static const basket = '/basket';
  static const documents = '/documents';
  static const documentDetail = '/documents/detail';
  static const exports = '/exports';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case exports:
        return MaterialPageRoute<void>(
          builder: (_) => const ExportsPage(),
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
        return MaterialPageRoute<void>(
          builder: (_) => const QuestionBasketPage(),
          settings: settings,
        );
      case documents:
        return MaterialPageRoute<void>(
          builder: (_) => const DocumentsPage(),
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
      case tenantSwitch:
        return MaterialPageRoute<void>(
          builder: (_) => const TenantSwitchPage(),
          settings: settings,
        );
      case library:
        return MaterialPageRoute<void>(
          builder: (_) => const LibraryPage(),
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
