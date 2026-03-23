import 'package:flutter/material.dart';

import 'primary_page_scroll_memory.dart';
import 'workspace_module_shell.dart';

void navigateToWorkspaceModule(
  BuildContext context,
  WorkspaceModule module,
) {
  final targetRoute = _routeFor(module);
  if (ModalRoute.of(context)?.settings.name == targetRoute) {
    return;
  }
  final pageKey = _pageKeyFor(module);
  if (pageKey != null) {
    PrimaryPageScrollMemory.requestTopReset(pageKey);
  }
  Navigator.of(context).pushNamedAndRemoveUntil(targetRoute, (route) => false);
}

String _routeFor(WorkspaceModule module) {
  switch (module) {
    case WorkspaceModule.home:
      return '/';
    case WorkspaceModule.library:
      return '/library';
    case WorkspaceModule.documents:
      return '/documents';
    case WorkspaceModule.students:
      return '/students';
    case WorkspaceModule.classes:
      return '/classes';
    case WorkspaceModule.lessons:
      return '/lessons';
    case WorkspaceModule.exports:
      return '/exports';
    case WorkspaceModule.account:
      return '/me';
    case WorkspaceModule.settings:
      return '/settings';
  }
}

String? _pageKeyFor(WorkspaceModule module) {
  switch (module) {
    case WorkspaceModule.home:
      return 'home';
    case WorkspaceModule.library:
      return 'library';
    case WorkspaceModule.documents:
      return 'documents';
    case WorkspaceModule.exports:
      return 'exports';
    case WorkspaceModule.account:
      return 'account';
    case WorkspaceModule.students:
    case WorkspaceModule.classes:
    case WorkspaceModule.lessons:
    case WorkspaceModule.settings:
      return null;
  }
}
