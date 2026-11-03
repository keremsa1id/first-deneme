/// Uygulamadaki tek bir kelimeyi temsil eder.
class Word {
  const Word({
    required this.english,
    required this.turkish,
    required this.category,
    required this.imagePath,
    required this.exampleSentence,
  });

  final String english;
  final String turkish;
  final String category;
  final String imagePath;
  final String exampleSentence;

  /// JSON verisinden [Word] oluşturur.
  ///
  /// Zorunlu bir alan eksikse veya String değilse [FormatException] fırlatır.
  factory Word.fromJson(Map<String, dynamic> json) {
    return Word(
      english: _readString(json, 'english'),
      turkish: _readString(json, 'turkish'),
      category: _readString(json, 'category'),
      imagePath: _readString(json, 'imagePath'),
      exampleSentence: _readString(json, 'exampleSentence'),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'english': english,
      'turkish': turkish,
      'category': category,
      'imagePath': imagePath,
      'exampleSentence': exampleSentence,
    };
  }

  static String _readString(Map<String, dynamic> json, String key) {
    if (!json.containsKey(key) || json[key] == null) {
      throw FormatException(
        'Word JSON verisinde "$key" alanı eksik.',
        json,
      );
    }
    final Object? value = json[key];
    if (value is! String) {
      throw FormatException(
        'Word JSON verisinde "$key" alanı String olmalı, '
        'ama ${value.runtimeType} geldi.',
        json,
      );
    }
    return value;
  }

  @override
  String toString() => 'Word($english, $turkish, $category)';
}
