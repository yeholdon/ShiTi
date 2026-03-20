import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiti_flutter_app/core/models/auth_session.dart';
import 'package:shiti_flutter_app/core/models/tenant_summary.dart';
import 'package:shiti_flutter_app/core/services/app_services.dart';
import 'package:shiti_flutter_app/features/account/account_page.dart';

Widget _buildTestApp() {
  return const MaterialApp(
    home: AccountPage(),
  );
}

void main() {
  setUp(() {
    AppServices.instance.clearSession();
  });

  tearDown(() {
    AppServices.instance.clearSession();
  });

  testWidgets('account page shows login guidance when no session exists',
      (tester) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    expect(find.text('账号安全'), findsOneWidget);
    expect(find.text('需先登录'), findsOneWidget);
    expect(find.text('先去登录'), findsOneWidget);
  });

  testWidgets('account page opens change password dialog for active session',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    AppServices.instance.setSession(
      const AuthSession(
        userId: 'user-1',
        username: 'teacher_demo',
        accessLevel: 'member',
        accessToken: 'token-1',
        tokenPreview: 'token-1',
      ),
    );
    AppServices.instance.setActiveTenant(
      const TenantSummary(
        id: 'tenant-1',
        code: 'math-studio',
        name: '数学工作室',
        role: 'owner',
      ),
    );

    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    final changePasswordButton = find.widgetWithText(
      FilledButton,
      '修改密码',
    );
    await tester.tap(changePasswordButton);
    await tester.pumpAndSettle();

    expect(find.text('修改完成后会退出当前会话，需要用新密码重新登录。'), findsOneWidget);
    expect(find.text('当前密码'), findsOneWidget);
    expect(find.text('新密码'), findsOneWidget);
    expect(find.text('确认修改'), findsOneWidget);
  });
}
