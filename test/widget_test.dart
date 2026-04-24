import 'package:flutter_test/flutter_test.dart';
import 'package:protego/main.dart';

void main() {
  testWidgets('ProtegoApp renders', (WidgetTester tester) async {
    await tester.pumpWidget(const ProtegoApp());
    // Basic smoke test — app should render without crashing
    expect(find.byType(ProtegoApp), findsOneWidget);
  });
}
