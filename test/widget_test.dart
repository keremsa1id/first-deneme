import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:kelime_macerasi/main.dart';
import 'package:kelime_macerasi/models/word.dart';
import 'package:kelime_macerasi/models/word_category.dart';
import 'package:kelime_macerasi/screens/category_screen.dart';
import 'package:kelime_macerasi/screens/quiz_mode_screen.dart';
import 'package:kelime_macerasi/screens/quiz_screen.dart';
import 'package:kelime_macerasi/screens/sentence_screen.dart';

/// Ana ekran kaydırılabilir; butona dokunmadan önce görünür alana getirir.
Future<void> _tapMenu(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  // Yükleme göstergesi sürekli döndüğü için pumpAndSettle kullanılmıyor.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('Ana ekran menü butonlarını ve günlük hedefi gösterir',
      (WidgetTester tester) async {
    await tester.pumpWidget(const KelimeApp());

    for (final String label in <String>[
      'Words',
      'Sentences',
      'Quiz',
      'Mixed Test',
      'Review',
      'Favorites',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.textContaining('Today:'), findsOneWidget);
  });

  testWidgets('Sentences butonu grup seçme ekranını açar',
      (WidgetTester tester) async {
    await tester.pumpWidget(const KelimeApp());
    await _tapMenu(tester, 'Sentences');

    expect(find.byType(CategoryScreen), findsOneWidget);
  });

  testWidgets('Quiz butonu tür seçme ekranını açar',
      (WidgetTester tester) async {
    await tester.pumpWidget(const KelimeApp());
    await _tapMenu(tester, 'Quiz');

    expect(find.byType(QuizModeScreen), findsOneWidget);
    expect(find.text('Listen & Choose'), findsOneWidget);
    expect(find.text('Type the Word'), findsOneWidget);
  });

  testWidgets('Mixed Test butonu quiz ekranını açar',
      (WidgetTester tester) async {
    await tester.pumpWidget(const KelimeApp());
    await _tapMenu(tester, 'Mixed Test');

    expect(find.byType(QuizScreen), findsOneWidget);
  });

  testWidgets('Review butonu quiz ekranını açar', (WidgetTester tester) async {
    await tester.pumpWidget(const KelimeApp());
    await _tapMenu(tester, 'Review');

    expect(find.byType(QuizScreen), findsOneWidget);
  });

  test('words.json: kelimeler tekrar etmez, grupları tanımlı, '
      'cümlede kelime geçer ve tanım cevabı ele vermez', () {
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
      expect(
        word.exampleSentence.split(' ').length,
        lessThanOrEqualTo(6),
        reason: '${word.english} cümlesi 6 kelimeden uzun',
      );
      final String? definition = word.definition;
      expect(definition, isNotNull, reason: '${word.english} tanımı yok');
      expect(
        splitSentence(definition!, word.english)
            .any((SentencePart part) => part.isHighlighted),
        isFalse,
        reason: '${word.english} tanımında kelimenin kendisi geçiyor',
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
