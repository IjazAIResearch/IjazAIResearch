import 'dart:async';

import 'package:camera/camera.dart';

import 'psl_classifier.dart';

/// Owns the camera and turns its frames into STABLE predictions.
///
///   Camera frames → [PslClassifierService] → raw predictions
///   → stability filter → [stablePredictions] stream
///
/// A prediction only becomes "stable" after the same letter is
/// predicted [stableFrames] times in a row with confidence at or
/// above [minConfidence]. This stops the UI flickering between
/// letters while the hand moves. Frames are throttled to at most one
/// inference every [minInterval] so the phone is not asked to run the
/// model on every camera frame.
///
/// One instance serves one screen. Create it when the screen opens,
/// dispose it when the screen closes — otherwise the camera stays
/// locked and the next tab cannot open it.
class PslCameraService {
  PslCameraService(this.classifier);

  static const stableFrames = 5;
  static const minConfidence = 0.6;
  static const minInterval = Duration(milliseconds: 400);

  final PslClassifierService classifier;

  CameraController? _controller;
  StreamController<PslPrediction>? _stableController;

  /// The controller behind the preview widget. Null until [start]
  /// has completed.
  CameraController? get controller => _controller;

  /// Stable predictions only (see class doc). Listen to this, not to
  /// raw frames, for display, speech and fingerspelling.
  Stream<PslPrediction> get stablePredictions {
    _stableController ??= StreamController<PslPrediction>.broadcast();
    return _stableController!.stream;
  }

  /// The most recent raw prediction, however confident. Shown as a
  /// "thinking…" hint; never spoken or added to a word on its own.
  PslPrediction? latestRaw;

  PslPrediction? _pending;
  PslPrediction? _lastEmitted;
  int _pendingCount = 0;
  bool _busy = false;
  DateTime _lastProcess = DateTime.fromMillisecondsSinceEpoch(0);

  /// Opens the front camera and starts classifying frames.
  Future<void> start() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw StateError('No camera found on this device.');
    }
    final controller = CameraController(
      cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      ),
      ResolutionPreset.medium,
      enableAudio: false,
    );
    _controller = controller;
    await controller.initialize();
    _stableController ??= StreamController<PslPrediction>.broadcast();
    await controller.startImageStream(_onImage);
  }

  Future<void> _onImage(CameraImage image) async {
    if (_busy) return;
    final now = DateTime.now();
    if (now.difference(_lastProcess) < minInterval) return;
    _lastProcess = now;
    _busy = true;
    try {
      final prediction = await classifier.classifyCameraImage(image);
      if (prediction == null) return;
      latestRaw = prediction;
      if (prediction.confidence < minConfidence) {
        _pending = null;
        _pendingCount = 0;
        return;
      }
      if (prediction.letter.slug == _pending?.letter.slug) {
        _pendingCount++;
      } else {
        _pending = prediction;
        _pendingCount = 1;
      }
      if (_pendingCount >= stableFrames &&
          prediction.letter.slug != _lastEmitted?.letter.slug) {
        _lastEmitted = prediction;
        _stableController?.add(prediction);
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> stop() async {
    try {
      await _controller?.stopImageStream();
    } catch (_) {
      // The stream may already be stopped when the screen closes.
    }
    await _controller?.dispose();
    _controller = null;
    await _stableController?.close();
    _stableController = null;
  }
}
