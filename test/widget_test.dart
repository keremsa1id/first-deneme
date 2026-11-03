import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:kelime_macerasi/main.dart';
import 'package:kelime_macerasi/models/word.dart';
import 'package:kelime_macerasi/models/word_category.dart';
import 'package:kelime_macerasi/screens/category_screen.dart';
import 'package:kelime_macerasi/screens/quiz_screen.dart';
import 'package:kelime_macerasi/screens/sentence_screen.dart';

void main() {
  testWidgets('Ana ekran dört menü butonunu gösterir',
      (WidgetTester tester) async {
    await tester.pumpWidget(const KelimeApp());

    expect(find.text('Words'), findsOneWidget);
    expect(find.text('Sentences'), findsOneWidget);
    expect(find.text('Quiz'), findsOneWidget);
    expect(find.text('Mixed Test'), findsOneWidget);
  });

  testWidgets('Sentences butonu grup seçme ekranını açar',
      (WidgetTester tester) async {
    await tester.pumpWidget(const KelimeApp());

    await tester.tap(find.text('Sentences'));
    // Yükleme göstergesi sürekli döndüğü için pumpAndSettle kullanılmıyor.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(CategoryScreen), findsOneWidget);
  });

  testWidgets('Quiz butonu grup seçme ekranını açar',
      (WidgetTester tester) async {
    await tester.pumpWidget(const KelimeApp());

    await tester.tap(find.text('Quiz'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(CategoryScreen), findsOneWidget);
  });

  testWidgets('Mixed Test butonu quiz ekranını açar',
      (WidgetTester tester) async {
    await tester.pumpWidget(const KelimeApp());

    await tester.tap(find.text('Mixed Test'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(QuizScreen), findsOneWidget);
  });

  test('words.json: kelimeler tekrar etmez, grupları tanımlı ve '
      'cümlede kelime geçer', () {
    final List<Object?> data = jsonDecode(
      File('assets/data/words.json').readAsStringSync(),
    ) as List<Object?>;
    final Set<String> categoryIds =
        wordCategories.map((WordCategory c) => c.id).toSet();
    final Set<String> seen = <String>{};

    for (final Object? item in data) {
      final Word word = Word.fromJson(item! as Map<String, dynamic>);
      expect(seen.add(word.english.toLowerCase()), isTrue,
          reason: '${word.english} iki kez var');
      expect(categoryIds, contains(word.category),
          reason: '${word.english} grubu tanımsız');
      expect(
        splitSentence(word.exampleSentence, word.english)
            .any((SentencePart part) => part.isHighlighted),
        isTrue,
        reason: '${word.english} cümlesinde geçmiyor',
      );
    }
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
