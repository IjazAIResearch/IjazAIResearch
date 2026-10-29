import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/psl_alphabet.dart';

/// One model prediction: a PSL letter plus the model's confidence
/// (the softmax probability for that class, 0.0–1.0).
class PslPrediction {
  const PslPrediction(this.letter, this.confidence);

  final PslLetter letter;
  final double confidence;
}

/// On-device PSL alphabet classifier (the app's MAIN recognition path).
///
/// Loads `assets/model.tflite` + `assets/labels.txt` — the files
/// produced by `python/train_psl.py`. If either file is missing (the
/// normal state before a real model has been trained), [load] returns
/// false and [available] stays false; the app then falls back to the
/// clearly-labelled demo mode instead of pretending to recognise
/// signs. Nothing here ever claims a prediction without a model.
///
/// Input preprocessing MUST match training: the training script feeds
/// MobileNetV2 `preprocess_input` images, i.e. pixels scaled to
/// [-1, 1] via (pixel / 127.5) - 1, on a centre-cropped 224x224 frame.
/// The same scaling is applied here.
///
/// Supported export: the DEFAULT dynamic-range quantized model from
/// train_psl.py (float input/output, int8 weights). A full-integer
/// quantized model (uint8 input/output) is NOT supported by this
/// service yet — do not ship one without adding uint8 handling here.
class PslClassifierService {
  Interpreter? _interpreter;
  List<PslLetter> _labels = [];
  String? error;

  bool get available => _interpreter != null && _labels.isNotEmpty;

  List<PslLetter> get labels => List.unmodifiable(_labels);

  /// Tries to load the model and labels. Returns true on success.
  /// On any failure, sets [error] and returns false — callers must
  /// then use the demo fallback, not this service.
  Future<bool> load() async {
    try {
      final labelsText = await rootBundle.loadString('assets/labels.txt');
      final slugs = labelsText
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
      if (slugs.isEmpty) {
        error = 'labels.txt is empty.';
        return false;
      }
      final letters = <PslLetter>[];
      for (final slug in slugs) {
        final letter = pslLetterBySlug(slug);
        if (letter == null) {
          // Refuse rather than shift every later index by one.
          error = 'labels.txt contains unknown class "$slug" — '
              'it does not match the 37-letter alphabet. '
              'Re-export labels from train_psl.py.';
          return false;
        }
        letters.add(letter);
      }
      _interpreter = await Interpreter.fromAsset('assets/model.tflite');
      _labels = letters;
      return true;
    } catch (e) {
      error = 'Model not loaded: $e';
      return false;
    }
  }

  /// Classifies one camera frame. Returns null when the model is not
  /// available, or when the frame format is unsupported (see below).
  ///
  /// Frames are throttled by the caller (PslCameraService); this method
  /// itself does one full conversion + inference per call.
  Future<PslPrediction?> classifyCameraImage(CameraImage image) async {
    final interpreter = _interpreter;
    if (interpreter == null || _labels.isEmpty) return null;
    final frame = _convertCameraImage(image);
    if (frame == null) return null;

    // Centre-crop to a square, then resize to the model's 224x224 input.
    final side = math.min(frame.width, frame.height);
    final cropped = img.copyCrop(
      frame,
      x: (frame.width - side) ~/ 2,
      y: (frame.height - side) ~/ 2,
      width: side,
      height: side,
    );
    final resized = img.copyResize(cropped, width: 224, height: 224);

    // Build a [1, 224, 224, 3] float input, MobileNetV2 scaling.
    final input = List.generate(
      1,
      (_) => List.generate(
        224,
        (y) => List.generate(224, (x) {
          final pixel = resized.getPixel(x, y);
          return <double>[
            (pixel.r / 127.5) - 1.0,
            (pixel.g / 127.5) - 1.0,
            (pixel.b / 127.5) - 1.0,
          ];
        }),
      ),
    );
    final output =
        List.generate(1, (_) => List.filled(_labels.length, 0.0));
    interpreter.run(input, output);

    var bestIndex = 0;
    var bestScore = output[0][0];
    for (var i = 1; i < output[0].length; i++) {
      if (output[0][i] > bestScore) {
        bestScore = output[0][i];
        bestIndex = i;
      }
    }
    return PslPrediction(_labels[bestIndex], bestScore);
  }

  /// Converts a camera frame to an RGB image.
  ///
  /// Android YUV420 is implemented (Y plane + subsampled U/V planes).
  /// If colours look wrong on a device, the U and V planes are the
  /// first thing to swap — some devices report them in the other
  /// order. iOS BGRA frames are handled via the image package.
  /// Any other format returns null (frame skipped, not misread).
  img.Image? _convertCameraImage(CameraImage image) {
    if (image.format.group == ImageFormatGroup.bgra8888) {
      final plane = image.planes[0];
      return img.Image.fromBytes(
        width: image.width,
        height: image.height,
        bytes: plane.bytes.buffer,
        format: img.Format.uint8,
        numChannels: 4,
        order: img.ChannelOrder.bgra,
      );
    }
    if (image.format.group != ImageFormatGroup.yuv420 ||
        image.planes.length < 3) {
      return null;
    }
    final width = image.width;
    final height = image.height;
    final out = img.Image(width: width, height: height);
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];
    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel ?? 1;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final yIndex = y * yPlane.bytesPerRow + x;
        final uvIndex =
            (y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;
        final yp = yPlane.bytes[yIndex].toDouble();
        final up = uPlane.bytes[uvIndex].toDouble() - 128.0;
        final vp = vPlane.bytes[uvIndex].toDouble() - 128.0;
        final r = (yp + 1.402 * vp).round().clamp(0, 255);
        final g =
            (yp - 0.344136 * up - 0.714136 * vp).round().clamp(0, 255);
        final b = (yp + 1.772 * up).round().clamp(0, 255);
        out.setPixelRgb(x, y, r, g, b);
      }
    }
    return out;
  }

  void close() {
    _interpreter?.close();
    _interpreter = null;
  }
}
