import '../models/hand_landmark.dart';

/// The gestures the rule-based demo classifier can recognise.
///
/// These are generic hand shapes used to prove the pipeline works
/// end-to-end. They are NOT a PSL vocabulary: real PSL signs need a
/// trained model on real PSL data (see the README roadmap).
enum DemoGesture {
  openPalm('Open Palm'),
  fist('Fist'),
  thumbsUp('Thumbs Up'),
  peace('Peace Sign'),
  point('Pointing'),
  unknown('Unknown');

  const DemoGesture(this.label);
  final String label;
}

/// Rule-based classifier: decides from landmark geometry only, no ML model.
///
/// A finger counts as "extended" when its tip is clearly farther from the
/// wrist than its PIP joint is. The thumb is special: it counts as
/// extended when its tip is clearly farther from the pinky base than its
/// IP joint is (this works for both hands and avoids handedness checks).
class GestureClassifier {
  DemoGesture classify(HandPose pose) {
    final index = _isExtended(pose.indexTip, pose.indexPip, pose.wrist);
    final middle = _isExtended(pose.middleTip, pose.middlePip, pose.wrist);
    final ring = _isExtended(pose.ringTip, pose.ringPip, pose.wrist);
    final pinky = _isExtended(pose.pinkyTip, pose.pinkyPip, pose.wrist);
    // Threshold 1.1 (not 1.2): with the demo hand geometry the
    // extended-thumb ratio sits near 1.2, so 1.2 flips on tiny noise.
    // Folded thumbs sit near 0.9, so 1.1 separates both cleanly.
    final thumb = pose.thumbTip.distanceTo(pose.pinkyMcp) >
        pose.thumbIp.distanceTo(pose.pinkyMcp) * 1.1;

    final extendedCount = [index, middle, ring, pinky].where((e) => e).length;

    if (thumb && extendedCount == 4) return DemoGesture.openPalm;
    if (!thumb && extendedCount == 0) return DemoGesture.fist;
    if (thumb && extendedCount == 0) return DemoGesture.thumbsUp;
    if (!thumb && index && middle && !ring && !pinky) {
      return DemoGesture.peace;
    }
    if (!thumb && index && !middle && !ring && !pinky) {
      return DemoGesture.point;
    }
    return DemoGesture.unknown;
  }

  bool _isExtended(HandLandmark tip, HandLandmark pip, HandLandmark wrist) {
    return tip.distanceTo(wrist) > pip.distanceTo(wrist) * 1.1;
  }
}
