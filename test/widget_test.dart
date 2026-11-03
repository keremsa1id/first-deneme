import 'package:flutter_test/flutter_test.dart';

import 'package:kelime_macerasi/main.dart';
import 'package:kelime_macerasi/screens/quiz_screen.dart';
import 'package:kelime_macerasi/screens/sentence_screen.dart';

void main() {
  testWidgets('Ana ekran üç menü butonunu gösterir', (WidgetTester tester) async {
    await tester.pumpWidget(const KelimeApp());

    expect(find.text('Kelimeler'), findsOneWidget);
    expect(find.text('Cümleler'), findsOneWidget);
    expect(find.text('Quiz'), findsOneWidget);
  });

  testWidgets('Cümleler butonu cümle ekranını açar', (WidgetTester tester) async {
    await tester.pumpWidget(const KelimeApp());

    await tester.tap(find.text('Cümleler'));
    // Yükleme göstergesi sürekli döndüğü için pumpAndSettle kullanılmıyor.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(SentenceScreen), findsOneWidget);
  });

  testWidgets('Quiz butonu quiz ekranını açar', (WidgetTester tester) async {
    await tester.pumpWidget(const KelimeApp());

    await tester.tap(find.text('Quiz'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(QuizScreen), findsOneWidget);
  });

  group('splitSentence', () {
    test('kelimeyi vurgulu parça olarak ayırır', () {
      expect(splitSentence('The cat is sleeping.', 'cat'), const <SentencePart>[
        SentencePart('The '),
        SentencePart('cat', isHighlighted: true),
        SentencePart(' is sleeping.'),
      ]);
    });

    test('büyük/küçük harfe bakmaz ve orijinal yazımı korur', () {
      expect(splitSentence('Ball is red.', 'ball'), const <SentencePart>[
        SentencePart('Ball', isHighlighted: true),
        SentencePart(' is red.'),
      ]);
    });

    test('kelimenin içindeki eşleşmeyi vurgulamaz', () {
      expect(splitSentence('I catch it.', 'cat'), const <SentencePart>[
        SentencePart('I catch it.'),
      ]);
    });

    test('kelime yoksa cümleyi tek parça döndürür', () {
      expect(splitSentence('Hello!', 'dog'), const <SentencePart>[
        SentencePart('Hello!'),
      ]);
    });
  });
}
