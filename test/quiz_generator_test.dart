import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:kelime_macerasi/models/word.dart';
import 'package:kelime_macerasi/services/quiz_generator.dart';

Word _word(String english, String category) => Word(
      english: english,
      turkish: english,
      category: category,
      imagePath: '',
      exampleSentence: '',
    );

void main() {
  final List<Word> words = <Word>[
    _word('cat', 'animals'),
    _word('dog', 'animals'),
    _word('bird', 'animals'),
    _word('fish', 'animals'),
    _word('cow', 'animals'),
    _word('ball', 'objects'),
    _word('cup', 'objects'),
    _word('book', 'objects'),
  ];

  QuizGenerator generator() => QuizGenerator(random: Random(1));

  test('istenen sayıda soru üretir ve her soru farklı kelimeyi sorar', () {
    final List<QuizQuestion> questions =
        generator().generate(words, questionCount: 5);

    expect(questions, hasLength(5));
    expect(questions.map((QuizQuestion q) => q.answer).toSet(), hasLength(5));
  });

  test('kelime sayısından fazla soru üretmez', () {
    expect(generator().generate(words, questionCount: 50), hasLength(8));
  });

  test('şıklar doğru cevabı içerir ve tekrar etmez', () {
    for (final QuizQuestion q in generator().generate(words)) {
      expect(q.options, hasLength(4));
      expect(q.options, contains(q.answer));
      expect(q.options.toSet(), hasLength(4));
    }
  });

  test('yanlış şıklar önce aynı kategoriden seçilir', () {
    for (final QuizQuestion q in generator().generate(words)) {
      if (q.answer.category == 'animals') {
        // 4 hayvan daha var, 3 yanlış şıkkın hepsi hayvan olmalı.
        expect(
          q.options.every((Word w) => w.category == 'animals'),
          isTrue,
        );
      }
    }
  });

  test('az kelimede şık sayısı kelime sayısına düşer', () {
    final List<QuizQuestion> questions =
        generator().generate(words.take(2).toList());

    expect(questions, hasLength(2));
    expect(questions.first.options, hasLength(2));
  });

  test('karışık modda sorular gruplara dengeli dağılır', () {
    for (int seed = 0; seed < 20; seed++) {
      final List<QuizQuestion> questions = QuizGenerator(random: Random(seed))
          .generate(words, questionCount: 4, mixCategories: true);

      expect(questions, hasLength(4));
      expect(questions.map((QuizQuestion q) => q.answer).toSet(), hasLength(4));
      // 2 grup, 4 soru: her gruptan tam 2 soru gelmeli.
      expect(
        questions.where((QuizQuestion q) => q.answer.category == 'objects'),
        hasLength(2),
      );
    }
  });

  test('karışık modda kelime sayısından fazla soru üretmez', () {
    expect(
      generator().generate(words, questionCount: 50, mixCategories: true),
      hasLength(8),
    );
  });

  test('boş listede soru üretmez', () {
    expect(generator().generate(const <Word>[]), isEmpty);
  });
}
