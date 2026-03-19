import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiti_flutter_app/app.dart';
import 'package:shiti_flutter_app/core/models/document_summary.dart';
import 'package:shiti_flutter_app/core/models/documents_page_args.dart';
import 'package:shiti_flutter_app/core/models/exports_page_args.dart';
import 'package:shiti_flutter_app/core/models/library_filter_state.dart';
import 'package:shiti_flutter_app/core/models/library_page_args.dart';
import 'package:shiti_flutter_app/features/documents/documents_page.dart';
import 'package:shiti_flutter_app/features/exports/exports_page.dart';
import 'package:shiti_flutter_app/features/library/library_page.dart';
import 'package:shiti_flutter_app/features/shared/primary_navigation_bar.dart';
import 'package:shiti_flutter_app/features/shared/primary_page_scroll_memory.dart';
import 'package:shiti_flutter_app/features/shared/primary_page_view_state_memory.dart';
import 'package:shiti_flutter_app/router/app_router.dart';

class _TestNavigatorObserver extends NavigatorObserver {
  int pushCount = 0;
  final List<String?> pushedRouteNames = <String?>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushCount += 1;
    pushedRouteNames.add(route.settings.name);
    super.didPush(route, previousRoute);
  }
}

Widget _buildPrimaryNavTestApp({
  required NavigatorObserver observer,
}) {
  return MaterialApp(
    initialRoute: AppRouter.home,
    navigatorObservers: [observer],
    onGenerateRoute: (settings) {
      switch (settings.name) {
        case AppRouter.library:
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const Scaffold(
              body: Center(child: Text('library-route')),
            ),
          );
        case AppRouter.home:
        default:
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => Builder(
              builder: (context) => Scaffold(
                body: Column(
                  children: [
                    const Text('home-route'),
                    ElevatedButton(
                      key: const Key('same-route-button'),
                      onPressed: () {
                        PrimaryNavigationBar.navigateToSection(
                          context,
                          PrimaryAppSection.home,
                        );
                      },
                      child: const Text('same-route'),
                    ),
                    ElevatedButton(
                      key: const Key('other-route-button'),
                      onPressed: () {
                        PrimaryNavigationBar.navigateToSection(
                          context,
                          PrimaryAppSection.library,
                        );
                      },
                      child: const Text('other-route'),
                    ),
                    ElevatedButton(
                      key: const Key('reset-route-button'),
                      onPressed: () {
                        PrimaryNavigationBar.navigateToSection(
                          context,
                          PrimaryAppSection.library,
                          resetScrollOffset: true,
                        );
                      },
                      child: const Text('reset-route'),
                    ),
                  ],
                ),
              ),
            ),
          );
      }
    },
  );
}

ScrollController _primaryListController(WidgetTester tester) {
  final listView = tester.widget<ListView>(find.byType(ListView).first);
  return listView.controller!;
}

void main() {
  setUp(() {
    PrimaryPageScrollMemory.clear();
    PrimaryPageViewStateMemory.library = null;
    PrimaryPageViewStateMemory.documents = null;
    PrimaryPageViewStateMemory.exports = null;
  });

  tearDown(() {
    PrimaryPageScrollMemory.clear();
    PrimaryPageViewStateMemory.library = null;
    PrimaryPageViewStateMemory.documents = null;
    PrimaryPageViewStateMemory.exports = null;
  });

  testWidgets('renders workspace shell', (tester) async {
    await tester.pumpWidget(const ShiTiApp());
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('跨平台教研工作流'), findsOneWidget);
    expect(find.text('把备题、整理、组卷和导出，收进同一套工作台。'), findsOneWidget);
  });

  testWidgets('primary navigation ignores same-route navigation',
      (tester) async {
    final observer = _TestNavigatorObserver();

    await tester.pumpWidget(
      _buildPrimaryNavTestApp(observer: observer),
    );
    await tester.pumpAndSettle();

    final initialPushCount = observer.pushCount;
    await tester.tap(find.byKey(const Key('same-route-button')));
    await tester.pumpAndSettle();

    expect(observer.pushCount, initialPushCount);
    expect(find.text('home-route'), findsOneWidget);
  });

  testWidgets('primary navigation still navigates to a different section',
      (tester) async {
    final observer = _TestNavigatorObserver();

    await tester.pumpWidget(
      _buildPrimaryNavTestApp(observer: observer),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('other-route-button')));
    await tester.pumpAndSettle();

    expect(find.text('library-route'), findsOneWidget);
    expect(observer.pushedRouteNames.contains(AppRouter.library), isTrue);
  });

  testWidgets('primary navigation can reset remembered scroll before routing',
      (tester) async {
    final observer = _TestNavigatorObserver();
    PrimaryPageScrollMemory.update('library', 180);

    await tester.pumpWidget(
      _buildPrimaryNavTestApp(observer: observer),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('reset-route-button')));
    await tester.pumpAndSettle();

    expect(find.text('library-route'), findsOneWidget);
    expect(PrimaryPageScrollMemory.offsetFor('library'), 0);
  });

  testWidgets('documents page skips remembered query on contextual return',
      (tester) async {
    PrimaryPageViewStateMemory.documents = const PrimaryDocumentsViewState(
      query: 'should-not-restore',
      kindFilter: 'paper',
      exportStatusFilter: 'failed',
      sortBy: 'name',
      showOnlySelectedDocuments: true,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: DocumentsPage(
          args: DocumentsPageArgs(
            focusDocumentId: 'doc-1',
            flashMessage: '刚从详情页返回',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('should-not-restore'), findsNothing);
    expect(find.text('刚从详情页返回'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  });

  testWidgets('documents page restores remembered query without context',
      (tester) async {
    PrimaryPageViewStateMemory.documents = const PrimaryDocumentsViewState(
      query: 'restore-documents-query',
      kindFilter: 'paper',
      exportStatusFilter: 'failed',
      sortBy: 'name',
      showOnlySelectedDocuments: true,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: DocumentsPage(),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('restore-documents-query'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  });

  testWidgets('documents page skips remembered scroll on contextual return',
      (tester) async {
    PrimaryPageScrollMemory.update('documents', 180);

    await tester.pumpWidget(
      const MaterialApp(
        home: DocumentsPage(
          args: DocumentsPageArgs(
            focusDocumentId: 'doc-1',
            flashMessage: '刚从详情页返回',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    final controller = _primaryListController(tester);
    expect(controller.offset, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  });

  testWidgets('library page skips remembered query on contextual entry',
      (tester) async {
    PrimaryPageViewStateMemory.library = const PrimaryLibraryViewState(
      filters: LibraryFilterState(query: 'should-not-restore'),
      showOnlySelectedQuestions: true,
      basketFilter: 'in_basket',
      gradeFilter: 'grade-7',
      chapterFilter: 'chapter-1',
      sortBy: 'updated_at',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: LibraryPage(
          args: LibraryPageArgs(
            preferredDocumentSnapshot: DocumentSummary(
              id: 'doc-1',
              name: '测试文档',
              kind: 'handout',
              questionCount: 0,
              layoutCount: 0,
              latestExportStatus: 'pending',
            ),
            insertAfterItemId: 'item-1',
            insertAfterItemTitle: '第一题后',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('should-not-restore'), findsNothing);
    expect(find.text('为文档找题'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  });

  testWidgets('library page restores remembered scroll without context',
      (tester) async {
    PrimaryPageScrollMemory.update('library', 180);

    await tester.pumpWidget(
      const MaterialApp(
        home: LibraryPage(),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    final controller = _primaryListController(tester);
    expect(controller.offset, greaterThan(0));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  });

  testWidgets('library page skips remembered scroll on contextual entry',
      (tester) async {
    PrimaryPageScrollMemory.update('library', 180);

    await tester.pumpWidget(
      const MaterialApp(
        home: LibraryPage(
          args: LibraryPageArgs(
            preferredDocumentSnapshot: DocumentSummary(
              id: 'doc-1',
              name: '测试文档',
              kind: 'handout',
              questionCount: 0,
              layoutCount: 0,
              latestExportStatus: 'pending',
            ),
            insertAfterItemId: 'item-1',
            insertAfterItemTitle: '第一题后',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    final controller = _primaryListController(tester);
    expect(controller.offset, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  });

  testWidgets('library page honors pending top reset request',
      (tester) async {
    PrimaryPageScrollMemory.update('library', 180);
    PrimaryPageScrollMemory.requestTopReset('library');

    await tester.pumpWidget(
      const MaterialApp(
        home: LibraryPage(),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    final controller = _primaryListController(tester);
    expect(controller.offset, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  });

  testWidgets('library page shows standalone mode with workspace shortcut',
      (tester) async {
    PrimaryPageViewStateMemory.library = const PrimaryLibraryViewState(
      filters: LibraryFilterState(query: 'restore-library-query'),
      showOnlySelectedQuestions: false,
      basketFilter: 'all',
      gradeFilter: 'all',
      chapterFilter: 'all',
      sortBy: 'results',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: LibraryPage(),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('独立浏览'), findsOneWidget);
    expect(find.text('返回工作区'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  });

  testWidgets('exports page skips remembered query on contextual return',
      (tester) async {
    PrimaryPageViewStateMemory.exports = const PrimaryExportsViewState(
      query: 'should-not-restore',
      statusFilter: 'failed',
      formatFilter: 'pdf',
      sortBy: 'status',
      showOnlySelectedJobs: true,
      showOnlyCurrentDocument: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ExportsPage(
          args: ExportsPageArgs(
            focusDocumentName: '测试文档',
            focusJobId: 'job-1',
            documentSnapshot: const DocumentSummary(
              id: 'doc-1',
              name: '测试文档',
              kind: 'handout',
              questionCount: 0,
              layoutCount: 0,
              latestExportStatus: 'pending',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('should-not-restore'), findsNothing);
    expect(find.text('只看当前文档'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  });

  testWidgets('exports page shows overview mode with workspace shortcut',
      (tester) async {
    PrimaryPageViewStateMemory.exports = const PrimaryExportsViewState(
      query: 'restore-exports-query',
      statusFilter: 'failed',
      formatFilter: 'pdf',
      sortBy: 'status',
      showOnlySelectedJobs: true,
      showOnlyCurrentDocument: false,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: ExportsPage(),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('全部导出'), findsOneWidget);
    expect(find.text('返回工作区'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  });

  testWidgets('exports page skips remembered scroll on contextual return',
      (tester) async {
    PrimaryPageScrollMemory.update('exports', 180);

    await tester.pumpWidget(
      MaterialApp(
        home: ExportsPage(
          args: ExportsPageArgs(
            focusDocumentName: '测试文档',
            focusJobId: 'job-1',
            documentSnapshot: const DocumentSummary(
              id: 'doc-1',
              name: '测试文档',
              kind: 'handout',
              questionCount: 0,
              layoutCount: 0,
              latestExportStatus: 'pending',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    final controller = _primaryListController(tester);
    expect(controller.offset, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  });
}
