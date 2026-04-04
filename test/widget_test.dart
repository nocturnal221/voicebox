import 'package:flutter_test/flutter_test.dart';
import 'package:voicebox/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(VoiceBoxApp());
    expect(find.text('VoiceBox'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });
}
