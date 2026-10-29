import 'package:flutter/material.dart';

import '../services/gesture_classifier.dart';

/// Big, readable display of the currently detected gesture.
/// Shows a placeholder until the first stable gesture arrives.
class GestureDisplay extends StatelessWidget {
  const GestureDisplay({super.key, required this.gesture});

  final DemoGesture? gesture;

  @override
  Widget build(BuildContext context) {
    final label = gesture?.label ?? 'Show your hand…';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
