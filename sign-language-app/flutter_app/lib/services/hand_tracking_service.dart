import 'dart:async';

import '../models/hand_landmark.dart';

/// The single integration point for hand tracking.
///
/// Any tracking implementation must emit [HandPose] frames in MediaPipe
/// Hands order (see [HandPose]). The rest of the app — classifier, display,
/// speech — only depends on this interface, never on a specific plugin.
///
/// HOW TO WIRE UP REAL TRACKING (MediaPipe Hands):
///   1. Pick a Flutter plugin that exposes MediaPipe Hands landmarks
///      (for example a MediaPipe Tasks-Vision hand-landmarker binding).
///   2. Create a class that implements [HandTrackingService].
///   3. In its frame callback, map the plugin's 21 landmarks to
///      [HandLandmark] objects in MediaPipe order, x/y normalised to 0..1.
///   4. Pass your implementation to [CameraScreen] instead of
///      [DemoHandTrackingService].
/// Nothing else in the app needs to change.
abstract class HandTrackingService {
  /// A stream of hand poses. Emits nothing while no hand is visible.
  Stream<HandPose> get poses;

  /// Start the camera / tracker. Call once.
  Future<void> start();

  /// Stop the camera / tracker and free resources.
  Future<void> stop();
}

/// Demo implementation for testing the UI end-to-end WITHOUT a camera or a
/// tracking plugin. It cycles through the four demo gestures, building
/// plausible landmark sets for each one.
///
/// The landmark sets here are hand-written test data, NOT real hand
/// tracking and NOT real PSL data. The UI shows a "DEMO MODE" banner
/// whenever this service is active so a demo is never mistaken for
/// real detection.
class DemoHandTrackingService implements HandTrackingService {
  DemoHandTrackingService({this.gestureHold = const Duration(seconds: 2)});

  final Duration gestureHold;
  final _controller = StreamController<HandPose>.broadcast();
  Timer? _timer;
  int _index = 0;

  static const _demoGestures = <String>[
    'open_palm',
    'fist',
    'thumbs_up',
    'peace',
  ];

  @override
  Stream<HandPose> get poses => _controller.stream;

  @override
  Future<void> start() async {
    _timer?.cancel();
    _timer = Timer.periodic(gestureHold, (_) {
      final gesture = _demoGestures[_index % _demoGestures.length];
      _index++;
      _controller.add(_buildDemoPose(gesture));
    });
    // Emit the first pose immediately so the UI is not blank.
    _controller.add(_buildDemoPose(_demoGestures.first));
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    await _controller.close();
  }

  /// Builds 21 landmarks for a demo gesture.
  ///
  /// Layout (image coordinates, y grows downwards):
  /// wrist at the bottom centre, finger bases spread across the palm,
  /// extended fingers pointing up, folded fingers curled near the palm.
  HandPose _buildDemoPose(String gesture) {
    final extended = <String, bool>{
      'thumb': false,
      'index': false,
      'middle': false,
      'ring': false,
      'pinky': false,
    };
    switch (gesture) {
      case 'open_palm':
        extended.updateAll((_, __) => true);
      case 'fist':
        break; // all folded
      case 'thumbs_up':
        extended['thumb'] = true;
      case 'peace':
        extended['index'] = true;
        extended['middle'] = true;
    }

    // x positions of the five finger bases, left to right.
    const baseX = <String, double>{
      'thumb': 0.34,
      'index': 0.43,
      'middle': 0.50,
      'ring': 0.57,
      'pinky': 0.64,
    };

    HandLandmark pt(double x, double y) => HandLandmark(x, y, 0);

    final points = <HandLandmark>[];
    // 0: wrist
    points.add(pt(0.50, 0.90));
    // Thumb: CMC, MCP, IP, TIP. Extended thumb points out to the side.
    if (extended['thumb']!) {
      points.addAll([pt(0.38, 0.78), pt(0.32, 0.70), pt(0.26, 0.62), pt(0.20, 0.54)]);
    } else {
      points.addAll([pt(0.40, 0.78), pt(0.42, 0.72), pt(0.44, 0.68), pt(0.46, 0.66)]);
    }
    // Other fingers: MCP, PIP, DIP, TIP. Extended = straight up,
    // folded = curled back towards the palm.
    for (final finger in ['index', 'middle', 'ring', 'pinky']) {
      final bx = baseX[finger]!;
      if (extended[finger]!) {
        points.addAll([pt(bx, 0.68), pt(bx, 0.50), pt(bx, 0.34), pt(bx, 0.20)]);
      } else {
        points.addAll([pt(bx, 0.68), pt(bx, 0.62), pt(bx, 0.64), pt(bx, 0.70)]);
      }
    }
    return HandPose(points);
  }
}
