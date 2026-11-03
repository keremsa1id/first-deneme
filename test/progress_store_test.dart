import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kelime_macerasi/models/word.dart';
import 'package:kelime_macerasi/services/progress_store.dart';

Word _word(String english) => Word(
      english: english,
      turkish: english,
      category: 'animals',
      imagePath: '',
      exampleSentence: '',
    );

void main() {
  DateTime now = DateTime(2026, 11, 3, 10);
  ProgressStore store() => ProgressStore(clock: () => now);

  setUp(() {
    now = DateTime(2026, 11, 3, 10);
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('ilk denemede bilinen kelime öğrenilir', () {
    final ProgressStore progress = store();
    final Word cat = _word('cat');

    progress.recordAnswer(cat, firstTry: true);

    expect(progress.isLearned(cat), isTrue);
    expect(progress.learnedCount(<Word>[cat, _word('dog')]), 1);
    expect(progress.reviewCount, 0);
  });

  test('yanlış bilinen kelime tekrar destesine düşer, art arda iki doğruyla '
      'çıkar', () {
    final ProgressStore progress = store();
    final Word cat = _word('cat');

    progress.recordAnswer(cat, firstTry: false);
    expect(progress.reviewWords, contains('cat'));
    expect(progress.isLearned(cat), isFalse);

    progress.recordAnswer(cat, firstTry: true);
    expect(progress.reviewWords, contains('cat'));

    progress.recordAnswer(cat, firstTry: true);
    expect(progress.reviewWords, isEmpty);
    expect(progress.isLearned(cat), isTrue);
  });

  test('tekrar destesinde yeniden yanlış yapılırsa sayaç baştan başlar', () {
    final ProgressStore progress = store();
    final Word cat = _word('cat');

    progress.recordAnswer(cat, firstTry: false);
    progress.recordAnswer(cat, firstTry: true);
    progress.recordAnswer(cat, firstTry: false);
    progress.recordAnswer(cat, firstTry: true);

    expect(progress.reviewWords, contains('cat'));
  });

  test('favori eklenir ve çıkarılır', () {
    final ProgressStore progress = store();
    final Word cat = _word('Cat');

    progress.toggleFavorite(cat);
    expect(progress.isFavorite(cat), isTrue);
    expect(progress.favorites, <String>{'cat'});

    progress.toggleFavorite(cat);
    expect(progress.isFavorite(cat), isFalse);
  });

  test('en iyi skor sadece daha iyi skorla güncellenir', () {
    final ProgressStore progress = store();

    expect(progress.saveScore('picture:animals', 6, 10), isTrue);
    expect(progress.saveScore('picture:animals', 5, 10), isFalse);
    expect(progress.saveScore('picture:animals', 9, 10), isTrue);
    expect(progress.bestScore('picture:animals')?.score, 9);
    expect(progress.bestScore('listen:animals'), isNull);
  });

  test('günlük hedef: aynı kelime bir kez sayılır, ertesi gün sıfırlanır', () {
    final ProgressStore progress = store();

    progress.markStudied(_word('cat'));
    progress.markStudied(_word('cat'));
    progress.markStudied(_word('dog'));
    expect(progress.todayCount, 2);

    now = DateTime(2026, 11, 4, 9);
    expect(progress.todayCount, 0);
  });

  test('seri: hedef art arda tutunca artar, bir gün atlanınca sıfırlanır', () {
    final ProgressStore progress = store();
    void reachGoal(String prefix) {
      for (int i = 0; i < ProgressStore.dailyGoal; i++) {
        progress.markStudied(_word('$prefix$i'));
      }
    }

    reachGoal('a');
    expect(progress.goalMetToday, isTrue);
    expect(progress.streak, 1);

    now = DateTime(2026, 11, 4, 9);
    // Bugün henüz hedef tutmadı ama dünkü seri hâlâ geçerli.
    expect(progress.streak, 1);
    reachGoal('b');
    expect(progress.streak, 2);

    now = DateTime(2026, 11, 6, 9);
    expect(progress.streak, 0);
    reachGoal('c');
    expect(progress.streak, 1);
  });

  test('kaydedilen ilerleme yeniden yüklenince geri gelir', () async {
    final ProgressStore first = store();
    await first.load();
    first.recordAnswer(_word('cat'), firstTry: true);
    first.recordAnswer(_word('dog'), firstTry: false);
    first.toggleFavorite(_word('bird'));
    first.saveScore('mixed', 12, 15);

    final ProgressStore second = store();
    await second.load();

    expect(second.isLearned(_word('cat')), isTrue);
    expect(second.reviewWords, <String>{'dog'});
    expect(second.isFavorite(_word('bird')), isTrue);
    expect(second.bestScore('mixed')?.score, 12);
    expect(second.todayCount, 2);
  });
}
