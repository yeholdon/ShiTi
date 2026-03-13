import 'package:flutter_test/flutter_test.dart';
import 'package:shiti_flutter_app/app.dart';

void main() {
  testWidgets('renders workspace shell', (tester) async {
    await tester.pumpWidget(const ShiTiApp());
    await tester.pumpAndSettle();

    expect(find.text('跨平台教研工作流'), findsOneWidget);
    expect(find.text('把备题、整理、组卷和导出，收进同一套工作台。'), findsOneWidget);
  });
}
