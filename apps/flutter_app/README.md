# apps/flutter_app

Flutter client scaffold for the ShiTi user-facing teaching workspace.

Current scope:

- `pubspec.yaml`
- `lib/main.dart`
- `lib/app.dart`
- `lib/router/app_router.dart`
- `lib/features/home/*`
- `lib/features/library/*`
- `lib/features/library/question_detail_page.dart`
- `lib/features/basket/*`
- `lib/features/documents/*`
- `lib/features/exports/*`
- `lib/features/auth/*`
- `lib/features/tenants/*`
- `lib/core/api/*`
- `lib/core/models/*`
- `lib/core/repositories/*`
- `lib/core/services/*`
- `lib/core/config/*`

Planned targets:

- iOS
- Android
- web
- desktop

Current limitation:

- `flutter create` has now generated `android/`, `ios/`, `macos/`, `web/`, and `windows/` directories
- `flutter analyze` passes
- `flutter test` passes when proxy variables are unset for the test process
- local Flutter doctor still reports gaps for Android cmdline-tools/licenses, CocoaPods, Simulator runtimes, and Chrome executable path

Runtime mode:

- default mode is local mock data
- switch to remote backend mode with:
  - `flutter run --dart-define=SHITI_USE_MOCK_DATA=false`
  - optionally override the API host with `--dart-define=SHITI_API_BASE_URL=http://localhost:3000`
- login, tenant switch, and library pages now surface remote HTTP failures explicitly instead of failing silently
- home, documents, and exports pages now also surface current mode/session/tenant context and remote-mode failure states

Current local workflow highlights:

- create a document in the documents workspace
- add a question from question detail or basket into a selected target document
- insert a layout element into a handout from document detail
- reorder and remove document items
- create a local export record and jump into the exports page
- see explicit remote-mode failure feedback in document detail when loading or mutating a document fails
- see direct “登录 / 选择租户” guidance actions in remote mode when required context is missing
