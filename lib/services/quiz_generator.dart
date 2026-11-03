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
  ///
  /// [mixCategories] true ise sorular gruplara sırayla dağıtılır; böylece
  /// karışık testte her gruptan soru gelir, tek bir grup baskın olmaz.
  List<QuizQuestion> generate(
    List<Word> words, {
    int questionCount = 10,
    int optionCount = 4,
    bool mixCategories = false,
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

    final int count = min(questionCount, pool.length);
    final List<Word> answers = mixCategories
        ? _mixedAnswers(pool, count)
        : (List<Word>.of(pool)..shuffle(_random)).take(count).toList();
    final int optionsPerQuestion = min(optionCount, pool.length);

    return <QuizQuestion>[
      for (final Word answer in answers)
        QuizQuestion(
          answer: answer,
          options: _optionsFor(answer, pool, optionsPerQuestion),
        ),
    ];
  }

  /// Her gruptan sırayla birer kelime alarak [count] cevap seçer,
  /// sonra soruların sırasını karıştırır.
  List<Word> _mixedAnswers(List<Word> pool, int count) {
    final Map<String, List<Word>> groups = <String, List<Word>>{};
    for (final Word word in pool) {
      groups.putIfAbsent(word.category, () => <Word>[]).add(word);
    }
    final List<List<Word>> queues = groups.values
        .map((List<Word> group) => List<Word>.of(group)..shuffle(_random))
        .toList()
      ..shuffle(_random);

    final List<Word> picked = <Word>[];
    int round = 0;
    while (picked.length < count) {
      for (final List<Word> queue in queues) {
        if (round < queue.length && picked.length < count) {
          picked.add(queue[round]);
        }
      }
      round++;
    }
    return picked..shuffle(_random);
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
