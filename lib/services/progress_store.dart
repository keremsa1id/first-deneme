import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/word.dart';

/// Bir quiz türünün en iyi skoru.
class QuizScore {
  const QuizScore(this.score, this.total);

  final int score;
  final int total;

  double get ratio => total == 0 ? 0 : score / total;
}

/// Çocuğun ilerlemesini cihazda saklar: öğrenilen kelimeler, quiz skorları,
/// tekrar destesi (Review), favoriler, günlük hedef ve seri.
///
/// Uygulama genelinde tek bir örnek kullanılır: `ProgressStore.instance`.
/// Değişiklikler dinleyicilere bildirilir, böylece ekranlar kendini yeniler.
/// [load] çağrılmadan da çalışır; o durumda veriler sadece bellekte tutulur.
class ProgressStore extends ChangeNotifier {
  @visibleForTesting
  ProgressStore({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static final ProgressStore instance = ProgressStore();

  /// Günlük hedef: bugün çalışılacak farklı kelime sayısı.
  static const int dailyGoal = 10;

  /// Tekrar destesindeki bir kelime, art arda bu kadar doğru bilinince çıkar.
  static const int correctToLeaveReview = 2;

  static const String _learnedKey = 'learned';
  static const String _favoritesKey = 'favorites';
  static const String _reviewKey = 'review';
  static const String _scoresKey = 'bestScores';
  static const String _todayDateKey = 'todayDate';
  static const String _todayWordsKey = 'todayWords';
  static const String _streakKey = 'streak';
  static const String _goalMetDateKey = 'goalMetDate';

  final DateTime Function() _clock;
  SharedPreferences? _prefs;
  Future<void>? _loadFuture;

  final Set<String> _learned = <String>{};
  final Set<String> _favorites = <String>{};

  /// Kelime -> çıkması için gereken art arda doğru sayısı.
  final Map<String, int> _review = <String, int>{};
  final Map<String, QuizScore> _bestScores = <String, QuizScore>{};

  String? _todayDate;
  final Set<String> _todayWords = <String>{};
  int _streak = 0;
  String? _goalMetDate;

  static String _keyOf(Word word) => word.english.toLowerCase();

  /// Kayıtlı ilerlemeyi okur. Okunamazsa uygulama boş ilerlemeyle devam eder.
  Future<void> load() => _loadFuture ??= _load();

  Future<void> _load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      _learned.addAll(prefs.getStringList(_learnedKey) ?? const <String>[]);
      _favorites
          .addAll(prefs.getStringList(_favoritesKey) ?? const <String>[]);
      final Object? review = _decode(prefs.getString(_reviewKey));
      if (review is Map<String, dynamic>) {
        review.forEach((String key, dynamic value) {
          if (value is int) {
            _review[key] = value;
          }
        });
      }
      final Object? scores = _decode(prefs.getString(_scoresKey));
      if (scores is Map<String, dynamic>) {
        scores.forEach((String key, dynamic value) {
          if (value is List &&
              value.length == 2 &&
              value[0] is int &&
              value[1] is int) {
            _bestScores[key] = QuizScore(value[0] as int, value[1] as int);
          }
        });
      }
      _todayDate = prefs.getString(_todayDateKey);
      _todayWords
          .addAll(prefs.getStringList(_todayWordsKey) ?? const <String>[]);
      _streak = prefs.getInt(_streakKey) ?? 0;
      _goalMetDate = prefs.getString(_goalMetDateKey);
      _prefs = prefs;
      notifyListeners();
    } catch (error) {
      debugPrint('ProgressStore.load hatası: $error');
    }
  }

  static Object? _decode(String? raw) {
    if (raw == null) {
      return null;
    }
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }

  // --- Öğrenilen kelimeler ---

  /// Quiz'de ilk denemede doğru bilinen kelimeler öğrenilmiş sayılır.
  bool isLearned(Word word) => _learned.contains(_keyOf(word));

  int learnedCount(Iterable<Word> words) => words.where(isLearned).length;

  /// Bir quiz sorusu bittiğinde çağrılır.
  ///
  /// İlk denemede bilinirse kelime öğrenildi sayılır ve tekrar destesindeyse
  /// çıkmaya bir adım yaklaşır. Yanlış bilinirse tekrar destesine girer
  /// (ya da sayacı baştan başlar) ve öğrenilenlerden çıkar.
  void recordAnswer(Word word, {required bool firstTry}) {
    final String key = _keyOf(word);
    if (firstTry) {
      _learned.add(key);
      final int? remaining = _review[key];
      if (remaining != null) {
        if (remaining <= 1) {
          _review.remove(key);
        } else {
          _review[key] = remaining - 1;
        }
      }
    } else {
      _learned.remove(key);
      _review[key] = correctToLeaveReview;
    }
    _prefs?.setStringList(_learnedKey, _learned.toList());
    _prefs?.setString(_reviewKey, jsonEncode(_review));
    _markStudied(key);
    notifyListeners();
  }

  // --- Tekrar destesi ---

  Set<String> get reviewWords => Set<String>.unmodifiable(_review.keys);

  int get reviewCount => _review.length;

  // --- Favoriler ---

  bool isFavorite(Word word) => _favorites.contains(_keyOf(word));

  Set<String> get favorites => Set<String>.unmodifiable(_favorites);

  void toggleFavorite(Word word) {
    final String key = _keyOf(word);
    if (!_favorites.remove(key)) {
      _favorites.add(key);
    }
    _prefs?.setStringList(_favoritesKey, _favorites.toList());
    notifyListeners();
  }

  // --- Quiz skorları ---

  QuizScore? bestScore(String key) => _bestScores[key];

  /// Skoru kaydeder. Yeni rekorsa true döner.
  bool saveScore(String key, int score, int total) {
    final QuizScore? best = _bestScores[key];
    final QuizScore current = QuizScore(score, total);
    if (best != null && best.ratio >= current.ratio) {
      return false;
    }
    _bestScores[key] = current;
    _prefs?.setString(
      _scoresKey,
      jsonEncode(<String, List<int>>{
        for (final MapEntry<String, QuizScore> entry in _bestScores.entries)
          entry.key: <int>[entry.value.score, entry.value.total],
      }),
    );
    notifyListeners();
    return true;
  }

  // --- Günlük hedef ve seri ---

  /// Kart veya cümle ekranında bir kelime görüldüğünde çağrılır.
  void markStudied(Word word) {
    if (_markStudied(_keyOf(word))) {
      notifyListeners();
    }
  }

  /// Bugün çalışılan kelimelere ekler. Bir şey değiştiyse true döner.
  bool _markStudied(String key) {
    final String today = _dayKey(_clock());
    if (_todayDate != today) {
      _todayDate = today;
      _todayWords.clear();
      _prefs?.setString(_todayDateKey, today);
    }
    if (!_todayWords.add(key)) {
      return false;
    }
    _prefs?.setStringList(_todayWordsKey, _todayWords.toList());

    if (_todayWords.length >= dailyGoal && _goalMetDate != today) {
      // Hedef dün de tutturulduysa seri uzar, yoksa yeniden başlar.
      _streak = _goalMetDate == _yesterday() ? _streak + 1 : 1;
      _goalMetDate = today;
      _prefs?.setInt(_streakKey, _streak);
      _prefs?.setString(_goalMetDateKey, today);
    }
    return true;
  }

  /// Bugün çalışılan farklı kelime sayısı.
  int get todayCount =>
      _todayDate == _dayKey(_clock()) ? _todayWords.length : 0;

  bool get goalMetToday => _goalMetDate == _dayKey(_clock());

  /// Art arda hedefin tutturulduğu gün sayısı. Dün de bugün de
  /// tutturulmadıysa seri bozulmuştur ve 0 döner.
  int get streak {
    if (_goalMetDate == _dayKey(_clock()) || _goalMetDate == _yesterday()) {
      return _streak;
    }
    return 0;
  }

  String _yesterday() {
    final DateTime now = _clock();
    return _dayKey(DateTime(now.year, now.month, now.day - 1));
  }

  static String _dayKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
