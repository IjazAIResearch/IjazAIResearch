import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../models/psl_alphabet.dart';
import '../services/psl_camera_service.dart';
import '../services/psl_classifier.dart';

/// Learn tab: the full 37-letter alphabet as a list.
///
/// Tap a letter to practise it. Practice shows the target letter and,
/// when a model is present, checks the camera prediction against it.
/// The practice hint is deliberately generic — it does NOT invent a
/// handshape description for each letter. Handshape reference images
/// belong in `flutter_app/assets/learn/<slug>.jpg` (copied from the
/// dataset you trained on); until one is present, the practice screen
/// says so plainly instead of showing a guessed diagram.
///
/// The list itself always works, model or not: learning the alphabet
/// order and names does not need inference.
class LearnScreen extends StatelessWidget {
  const LearnScreen({
    super.key,
    required this.classifier,
    required this.modelAvailable,
  });

  final PslClassifierService classifier;
  final bool modelAvailable;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Learn — PSL Alphabet')),
      body: ListView.builder(
        itemCount: pslAlphabet.length,
        itemBuilder: (context, index) {
          final letter = pslAlphabet[index];
          return ListTile(
            leading: Text(
              letter.urdu,
              style: const TextStyle(fontSize: 32),
            ),
            title: Text(letter.roman),
            subtitle: Text('Sign for ${letter.roman} (${letter.urdu})'),
            trailing: const Icon(Icons.play_arrow),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LearnPracticeScreen(
                    letter: letter,
                    index: index,
                    classifier: classifier,
                    modelAvailable: modelAvailable,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Practice screen for one letter: target on top, camera below,
/// match feedback when the stable prediction equals the target.
class LearnPracticeScreen extends StatefulWidget {
  const LearnPracticeScreen({
    super.key,
    required this.letter,
    required this.index,
    required this.classifier,
    required this.modelAvailable,
  });

  final PslLetter letter;
  final int index;
  final PslClassifierService classifier;
  final bool modelAvailable;

  @override
  State<LearnPracticeScreen> createState() => _LearnPracticeScreenState();
}

class _LearnPracticeScreenState extends State<LearnPracticeScreen> {
  PslCameraService? _cameraService;
  StreamSubscription<PslPrediction>? _predictionSubscription;
  PslPrediction? _current;
  int _matches = 0;
  String? _error;
  bool _ready = false;
  bool _countedForCurrent = false;

  @override
  void initState() {
    super.initState();
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
      if (!mounted) return;
      setState(() {
        _current = pred;
        if (pred.letter.slug == widget.letter.slug) {
          if (!_countedForCurrent) {
            _matches++;
            _countedForCurrent = true;
          }
        } else {
          _countedForCurrent = false;
        }
      });
    });
    if (mounted) setState(() => _ready = true);
  }

  @override
  void dispose() {
    _predictionSubscription?.cancel();
    _cameraService?.stop();
    super.dispose();
  }

  void _nextLetter() {
    final nextIndex = (widget.index + 1) % pslAlphabet.length;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => LearnPracticeScreen(
          letter: pslAlphabet[nextIndex],
          index: nextIndex,
          classifier: widget.classifier,
          modelAvailable: widget.modelAvailable,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final matched = _current?.letter.slug == widget.letter.slug;
    final controller = _cameraService?.controller;
    return Scaffold(
      appBar: AppBar(title: Text('Practise — ${widget.letter.roman}')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  widget.letter.urdu,
                  style: const TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.letter.roman,
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Practice hint: form the sign for this letter and '
                  'hold it steady. Compare your hand with the '
                  'reference image from your dataset — no handshape '
                  'diagram is shown here until a verified reference '
                  'image is added under assets/learn/.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.modelAvailable
                      ? (matched
                          ? 'Matched ✓ — nice! (matches: $_matches)'
                          : 'Not yet matched — keep trying.')
                      : 'Camera check needs the trained model. '
                          'You can still study the letter order here.',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: matched ? Colors.green : null,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: !widget.modelAvailable
                ? const Center(
                    child: Text(
                      'No model yet — see README to train one.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : _error != null
                    ? Center(child: Text('Camera error: $_error'))
                    : !_ready || controller == null
                        ? const Center(
                            child: CircularProgressIndicator())
                        : CameraPreview(controller),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: _nextLetter,
              child: const Text('Next letter'),
            ),
          ),
        ],
      ),
    );
  }
}
