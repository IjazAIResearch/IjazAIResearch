import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../models/psl_alphabet.dart';
import '../services/psl_camera_service.dart';
import '../services/psl_classifier.dart';
import '../services/speech_service.dart';

/// Fingerspelling tab: build words letter by letter from signs.
///
/// The user signs one PSL alphabet letter, waits until it is stable,
/// then taps "Add letter". This manual step is deliberate: automatic
/// letter-by-letter capture would insert a letter on every small hand
/// movement, and the user — not the app — decides when a letter is
/// meant. Space, backspace, clear and "speak word" complete the flow.
///
/// Requires a trained model. Without one, this tab explains what is
/// missing instead of showing a fake word builder.
class FingerspellScreen extends StatefulWidget {
  const FingerspellScreen({
    super.key,
    required this.classifier,
    required this.modelAvailable,
  });

  final PslClassifierService classifier;
  final bool modelAvailable;

  @override
  State<FingerspellScreen> createState() => _FingerspellScreenState();
}

class _FingerspellScreenState extends State<FingerspellScreen> {
  PslCameraService? _cameraService;
  StreamSubscription<PslPrediction>? _predictionSubscription;
  final _speech = SpeechService();
  PslPrediction? _current;
  String? _error;
  bool _ready = false;

  /// The word so far: letters and spaces, in order.
  final List<String> _wordParts = [];

  @override
  void initState() {
    super.initState();
    _speech.init();
    if (widget.modelAvailable) _startCamera();
  }

  Future<void> _startCamera() async {
    final service = PslCameraService(widget.classifier);
    _cameraService = service;
    try {
      await service.start();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
      return;
    }
    _predictionSubscription = service.stablePredictions.listen((pred) {
      if (mounted) setState(() => _current = pred);
    });
    if (mounted) setState(() => _ready = true);
  }

  @override
  void dispose() {
    _predictionSubscription?.cancel();
    _cameraService?.stop();
    _speech.stop();
    super.dispose();
  }

  String get _urduWord => _wordParts.join();

  String get _romanWord {
    final names = <String>[];
    for (final part in _wordParts) {
      if (part == ' ') {
        names.add('|');
      } else {
        names.add(pslLetterBySlug(_slugForUrdu(part))?.roman ?? part);
      }
    }
    return names.join(' ');
  }

  String _slugForUrdu(String urdu) {
    for (final letter in pslAlphabet) {
      if (letter.urdu == urdu) return letter.slug;
    }
    return urdu;
  }

  void _addLetter() {
    final current = _current;
    if (current == null) return;
    setState(() => _wordParts.add(current.letter.urdu));
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.modelAvailable) {
      return Scaffold(
        appBar: AppBar(title: const Text('Fingerspelling')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Fingerspelling needs the trained model. Train it first '
              '(see README), then this tab builds words from your signs.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Fingerspelling')),
        body: Center(child: Text('Camera error: $_error')),
      );
    }
    final controller = _cameraService?.controller;
    return Scaffold(
      appBar: AppBar(title: const Text('Fingerspelling')),
      body: Column(
        children: [
          Expanded(
            child: !_ready || controller == null
                ? const Center(child: CircularProgressIndicator())
                : CameraPreview(controller),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.black87,
            child: Column(
              children: [
                Text(
                  _urduWord.isEmpty ? '…' : _urduWord,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _romanWord,
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  _current == null
                      ? 'Show a sign…'
                      : 'Current: ${_current!.letter.urdu} '
                          '(${_current!.letter.roman})',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _current == null ? null : _addLetter,
                  child: const Text('Add letter'),
                ),
                ElevatedButton(
                  onPressed: () => setState(() => _wordParts.add(' ')),
                  child: const Text('Space'),
                ),
                ElevatedButton(
                  onPressed: _wordParts.isEmpty
                      ? null
                      : () => setState(() => _wordParts.removeLast()),
                  child: const Text('Backspace'),
                ),
                ElevatedButton(
                  onPressed: _wordParts.isEmpty
                      ? null
                      : () => setState(() => _wordParts.clear()),
                  child: const Text('Clear'),
                ),
                ElevatedButton(
                  onPressed: _wordParts.isEmpty
                      ? null
                      : () => _speech.speak(_romanWord),
                  child: const Text('Speak word'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
