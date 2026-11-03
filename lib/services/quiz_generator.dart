import 'dart:math';

import '../models/word.dart';

/// Quiz'deki tek bir soru: [answer] kelimesi sorulur, [options] arasından
/// doğru resim seçilir. [options] her zaman [answer]'ı içerir.
class QuizQuestion {
  const QuizQuestion({required this.answer, required this.options});

  final Word answer;
  final List<Word> options;
}

/// Kelime listesinden rastgele quiz soruları üretir.
class QuizGenerator {
  QuizGenerator({Random? random}) : _random = random ?? Random();

  final Random _random;

  /// En fazla [questionCount] soru üretir; her soru farklı bir kelimeyi sorar.
  ///
  /// Yanlış şıklar önce aynı kategoriden seçilir (ör. hayvan sorusunda başka
  /// hayvanlar), yetmezse diğer kategorilerden tamamlanır. Kelime sayısı
  /// [optionCount]'tan azsa şık sayısı kelime sayısına düşer.
  /// Kelime listesi boşsa boş liste döner.
  List<QuizQuestion> generate(
    List<Word> words, {
    int questionCount = 10,
    int optionCount = 4,
  }) {
    // Aynı İngilizce kelime iki kez gelirse şıklarda tekrar olmasın.
    final Map<String, Word> unique = <String, Word>{};
    for (final Word word in words) {
      unique.putIfAbsent(word.english.toLowerCase(), () => word);
    }
    final List<Word> pool = unique.values.toList();
    if (pool.isEmpty) {
      return const <QuizQuestion>[];
    }

    final List<Word> answers = List<Word>.of(pool)..shuffle(_random);
    final int count = min(questionCount, answers.length);
    final int optionsPerQuestion = min(optionCount, pool.length);

    return <QuizQuestion>[
      for (final Word answer in answers.take(count))
        QuizQuestion(
          answer: answer,
          options: _optionsFor(answer, pool, optionsPerQuestion),
        ),
    ];
  }

  List<Word> _optionsFor(Word answer, List<Word> pool, int optionCount) {
    final List<Word> sameCategory = <Word>[];
    final List<Word> otherCategory = <Word>[];
    for (final Word word in pool) {
      if (identical(word, answer)) {
        continue;
      }
      (word.category == answer.category ? sameCategory : otherCategory)
          .add(word);
    }
    sameCategory.shuffle(_random);
    otherCategory.shuffle(_random);

    final List<Word> options = <Word>[
      answer,
      ...<Word>[...sameCategory, ...otherCategory].take(optionCount - 1),
    ]..shuffle(_random);
    return List<Word>.unmodifiable(options);
  }
}
