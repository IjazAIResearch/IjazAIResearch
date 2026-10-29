import 'dart:math' show sqrt;

/// A single hand landmark, in the same order and coordinate space as
/// MediaPipe Hands (21 points, x/y normalised to 0..1, z is relative depth).
///
/// MediaPipe Hands landmark order:
///   0 wrist
///   1..4   thumb: CMC, MCP, IP, TIP
///   5..8   index: MCP, PIP, DIP, TIP
///   9..12  middle: MCP, PIP, DIP, TIP
///   13..16 ring: MCP, PIP, DIP, TIP
///   17..20 pinky: MCP, PIP, DIP, TIP
class HandLandmark {
  const HandLandmark(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  double distanceTo(HandLandmark other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return sqrt(dx * dx + dy * dy);
  }
}

/// A full hand: exactly 21 landmarks, index = MediaPipe order above.
class HandPose {
  const HandPose(this.landmarks)
      : assert(landmarks.length == 21, 'A hand pose needs 21 landmarks');

  final List<HandLandmark> landmarks;

  HandLandmark get wrist => landmarks[0];
  HandLandmark get thumbTip => landmarks[4];
  HandLandmark get thumbIp => landmarks[3];
  HandLandmark get indexTip => landmarks[8];
  HandLandmark get indexPip => landmarks[6];
  HandLandmark get middleTip => landmarks[12];
  HandLandmark get middlePip => landmarks[10];
  HandLandmark get ringTip => landmarks[16];
  HandLandmark get ringPip => landmarks[14];
  HandLandmark get pinkyTip => landmarks[20];
  HandLandmark get pinkyPip => landmarks[18];
  HandLandmark get pinkyMcp => landmarks[17];
  HandLandmark get indexMcp => landmarks[5];
}
