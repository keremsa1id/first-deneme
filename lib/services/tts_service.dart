import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// İngilizce kelimeleri sesli okur.
///
/// Uygulama genelinde tek bir örnek kullanılır: `TtsService.instance`.
class TtsService {
  TtsService._();

  static final TtsService instance = TtsService._();

  static const String language = 'en-US';
  static const double pitch = 1.05;
  static const double volume = 1.0;

  final FlutterTts _tts = FlutterTts();

  bool _initialized = false;
  Future<void>? _initFuture;

  /// Çocuklar için yavaş konuşma hızı.
  ///
  /// flutter_tts Android, iOS ve macOS'ta 0.5'i normal hız kabul eder,
  /// web'de ise normal hız 1.0'dır.
  static double get speechRate => kIsWeb ? 0.7 : 0.35;

  /// Motoru ilk kullanımda bir kez ayarlar.
  Future<void> _ensureInitialized() {
    if (_initialized) {
      return Future<void>.value();
    }
    return _initFuture ??= _init();
  }

  Future<void> _init() async {
    try {
      await _tts.setLanguage(language);
      await _tts.setSpeechRate(speechRate);
      await _tts.setPitch(pitch);
      await _tts.setVolume(volume);
      _initialized = true;
    } finally {
      // Hata olursa bir sonraki çağrıda yeniden denenir.
      _initFuture = null;
    }
  }

  /// [text] metnini okur. Önceki konuşma varsa önce durdurulur.
  ///
  /// Boş metin yok sayılır. Okuma hataları arayüze yansıtılmaz.
  Future<void> speak(String text) async {
    final String trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }
    try {
      await _ensureInitialized();
      await _tts.stop();
      await _tts.speak(trimmed);
    } catch (error) {
      debugPrint('TtsService.speak hatası: $error');
    }
  }

  /// Süren konuşmayı durdurur.
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (error) {
      debugPrint('TtsService.stop hatası: $error');
    }
  }

  /// Konuşmayı durdurur. Sonraki [speak] çağrısında ayarlar yeniden yapılır.
  Future<void> dispose() async {
    await stop();
    _initialized = false;
  }
}
