import 'package:flutter_test/flutter_test.dart';
import 'package:print_inspector/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const App());

    expect(find.text('ESC/POS Virtual Printer'), findsOneWidget);
  });
}
