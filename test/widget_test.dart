import 'package:flutter_test/flutter_test.dart';

import 'package:kelime_macerasi/main.dart';

void main() {
  testWidgets('Ana ekran üç menü butonunu gösterir', (WidgetTester tester) async {
    await tester.pumpWidget(const KelimeApp());

    expect(find.text('Kelimeler'), findsOneWidget);
    expect(find.text('Cümleler'), findsOneWidget);
    expect(find.text('Quiz'), findsOneWidget);
  });
}
