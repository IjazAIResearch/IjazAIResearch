import 'dart:async';

import 'package:flutter/material.dart';

import '../models/hand_landmark.dart';
import '../services/gesture_classifier.dart';
import '../services/hand_tracking_service.dart';
import '../services/speech_service.dart';
import '../widgets/gesture_display.dart';

/// DEMO FALLBACK screen — shown ONLY when no trained TFLite model is
/// present (see main.dart). It cycles simulated hand shapes through
/// the old rule-based demo classifier so the UI, display and speech
/// can be tested without a camera or a model.
///
/// The amber banner is part of the contract: a demo must never be
/// mistaken for real PSL recognition. Do not remove it, and do not
/// route fingerspelling or Learn practice through this screen.
class DemoScreen extends StatefulWidget {
  const DemoScreen({super.key});

  @override
  State<DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<DemoScreen> {
  static const stableFrames = 5;

  final _classifier = GestureClassifier();
  final _speech = SpeechService();
  final _trackingService = DemoHandTrackingService();
  StreamSubscription<HandPose>? _poseSubscription;

  DemoGesture? _currentGesture;
  DemoGesture? _pendingGesture;
  int _pendingCount = 0;
  bool _speechOn = true;

  @override
  void initState() {
    super.initState();
    _speech.init();
    _poseSubscription = _trackingService.poses.listen(_onPose);
    _trackingService.start();
  }

  void _onPose(HandPose pose) {
    final detected = _classifier.classify(pose);
    if (detected == DemoGesture.unknown) return;
    if (detected == _pendingGesture) {
      _pendingCount++;
    } else {
      _pendingGesture = detected;
      _pendingCount = 1;
    }
    if (_pendingCount >= stableFrames && detected != _currentGesture) {
      setState(() => _currentGesture = detected);
      _speech.speak(detected.label);
    }
  }

  @override
  void dispose() {
    _poseSubscription?.cancel();
    _trackingService.stop();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PSL Translator — Demo'),
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: Colors.amber,
            child: const Text(
              'DEMO MODE — no trained model found. Gestures are '
              'simulated, not real PSL recognition. Train the model '
              '(see README) to unlock Camera, Fingerspelling and '
              'Learn practice.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.grey[900],
              child: const Center(
                child: Icon(Icons.back_hand, size: 120, color: Colors.white54),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: GestureDisplay(gesture: _currentGesture),
          ),
          const Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Demo gestures: Open Palm, Fist, Thumbs Up, Peace Sign, Pointing',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
