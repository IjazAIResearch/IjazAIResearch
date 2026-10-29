import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../services/psl_camera_service.dart';
import '../services/psl_classifier.dart';
import '../services/speech_service.dart';
import 'demo_screen.dart';

/// Camera tab: live PSL alphabet recognition with the on-device model.
///
/// Shows the camera preview, the current stable letter (Urdu glyph +
/// Roman name + confidence), and speaks the letter when it changes.
/// If no trained model is present, this widget shows [DemoScreen]
/// instead — the clearly-labelled demo fallback. It never pretends
/// the demo is recognition.
class CameraScreen extends StatefulWidget {
  const CameraScreen({
    super.key,
    required this.classifier,
    required this.modelAvailable,
  });

  final PslClassifierService classifier;
  final bool modelAvailable;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  PslCameraService? _cameraService;
  StreamSubscription<PslPrediction>? _predictionSubscription;
  final _speech = SpeechService();
  PslPrediction? _current;
  String? _error;
  bool _ready = false;
  bool _speechOn = true;

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
      if (!mounted) return;
      setState(() => _current = pred);
      _speech.speak(pred.letter.roman);
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

  @override
  Widget build(BuildContext context) {
    if (!widget.modelAvailable) return const DemoScreen();
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Camera')),
        body: Center(child: Text('Camera error: $_error')),
      );
    }
    final controller = _cameraService?.controller;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Camera — PSL Alphabet'),
        actions: [
          IconButton(
            icon: Icon(_speechOn ? Icons.volume_up : Icons.volume_off),
            tooltip: _speechOn ? 'Mute speech' : 'Unmute speech',
            onPressed: () {
              setState(() {
                _speechOn = !_speechOn;
                _speech.enabled = _speechOn;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: !_ready || controller == null
                ? const Center(child: CircularProgressIndicator())
                : CameraPreview(controller),
          ),
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            color: Colors.black87,
            child: Column(
              children: [
                Text(
                  _current?.letter.urdu ?? '…',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _current == null
                      ? 'Show a PSL alphabet sign…'
                      : '${_current!.letter.roman} '
                          '(${(100 * _current!.confidence).round()}%)',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 20),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Hold the sign steady — a letter is accepted after '
              'several consistent frames.',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
