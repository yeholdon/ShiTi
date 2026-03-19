import 'package:flutter/material.dart';

import '../../router/app_router.dart';
import 'primary_page_scroll_memory.dart';

enum PrimaryAppSection {
  home,
  library,
  documents,
  exports,
  account,
}

class PrimaryNavigationBar extends StatelessWidget {
  const PrimaryNavigationBar({
    required this.currentSection,
    super.key,
  });

  final PrimaryAppSection currentSection;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentSection.index,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          label: '工作台',
        ),
        NavigationDestination(
          icon: Icon(Icons.search_outlined),
          label: '题库',
        ),
        NavigationDestination(
          icon: Icon(Icons.description_outlined),
          label: '文档',
        ),
        NavigationDestination(
          icon: Icon(Icons.cloud_outlined),
          label: '导出',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: '我的',
        ),
      ],
      onDestinationSelected: (index) {
        final targetSection = PrimaryAppSection.values[index];
        if (targetSection == currentSection) {
          return;
        }
        navigateToSection(context, targetSection);
      },
    );
  }

  static void navigateToSection(
    BuildContext context,
    PrimaryAppSection section,
    {bool resetScrollOffset = false}
  ) {
    if (resetScrollOffset) {
      PrimaryPageScrollMemory.requestTopReset(_pageKeyFor(section));
    }
    final targetRoute = _routeFor(section);
    final currentRoute = ModalRoute.of(context)?.settings.name;
    if (currentRoute == targetRoute) {
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil(
      targetRoute,
      (route) => false,
    );
  }

  static String _routeFor(PrimaryAppSection section) {
    switch (section) {
      case PrimaryAppSection.home:
        return AppRouter.home;
      case PrimaryAppSection.library:
        return AppRouter.library;
      case PrimaryAppSection.documents:
        return AppRouter.documents;
      case PrimaryAppSection.exports:
        return AppRouter.exports;
      case PrimaryAppSection.account:
        return AppRouter.account;
    }
  }

  static String _pageKeyFor(PrimaryAppSection section) {
    switch (section) {
      case PrimaryAppSection.home:
        return 'home';
      case PrimaryAppSection.library:
        return 'library';
      case PrimaryAppSection.documents:
        return 'documents';
      case PrimaryAppSection.exports:
        return 'exports';
      case PrimaryAppSection.account:
        return 'account';
    }
  }
}
