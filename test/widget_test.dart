import 'package:flutter_test/flutter_test.dart';
import 'package:aegixa/main.dart';

void main() {
  testWidgets('AegixaApp renders', (WidgetTester tester) async {
    await tester.pumpWidget(const AegixaApp());
    // Basic smoke test — app should render without crashing
    expect(find.byType(AegixaApp), findsOneWidget);
  });
}
