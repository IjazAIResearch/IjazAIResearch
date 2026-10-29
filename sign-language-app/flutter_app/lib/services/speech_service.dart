import 'package:flutter_tts/flutter_tts.dart';

/// Tiny wrapper around flutter_tts so the screen only deals with
/// "speak this text" and "is speech on?".
class SpeechService {
  SpeechService({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  bool enabled = true;

  Future<void> init() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
  }

  /// Speaks [text] only if speech is enabled. Stops any ongoing speech
  /// first so rapid gesture changes do not queue up.
  Future<void> speak(String text) async {
    if (!enabled) return;
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stop() => _tts.stop();
}
