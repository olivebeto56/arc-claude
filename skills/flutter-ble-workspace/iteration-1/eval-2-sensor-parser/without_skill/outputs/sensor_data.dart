import 'dart:math' as math;

/// Holds all decoded and computed fields from a single BLE sensor packet.
class SensorData {
  // ── Raw decoded fields ──────────────────────────────────────────────────────

  /// Packet timestamp in milliseconds (uint16, wraps every ~65 s).
  final int timestampMs;

  /// Quaternion components, normalised (originally scaled ×10 000).
  final double qw;
  final double qx;
  final double qy;
  final double qz;

  /// Linear acceleration in m/s² (originally transmitted as milli-g int16).
  final double accelX;
  final double accelY;
  final double accelZ;

  // ── Derived Euler angles (radians) ─────────────────────────────────────────

  /// Roll angle in radians (rotation around X-axis).
  final double roll;

  /// Pitch angle in radians (rotation around Y-axis).
  final double pitch;

  /// Yaw angle in radians (rotation around Z-axis).
  final double yaw;

  const SensorData({
    required this.timestampMs,
    required this.qw,
    required this.qx,
    required this.qy,
    required this.qz,
    required this.accelX,
    required this.accelY,
    required this.accelZ,
    required this.roll,
    required this.pitch,
    required this.yaw,
  });

  // ── Convenience getters ────────────────────────────────────────────────────

  /// Roll in degrees.
  double get rollDeg => roll * 180.0 / math.pi;

  /// Pitch in degrees.
  double get pitchDeg => pitch * 180.0 / math.pi;

  /// Yaw in degrees.
  double get yawDeg => yaw * 180.0 / math.pi;

  /// Magnitude of the acceleration vector in m/s².
  double get accelMagnitude =>
      math.sqrt(accelX * accelX + accelY * accelY + accelZ * accelZ);

  @override
  String toString() {
    return 'SensorData{'
        'ts=${timestampMs}ms, '
        'q=[$qw, $qx, $qy, $qz], '
        'accel=[$accelX, $accelY, $accelZ] m/s², '
        'euler=[roll=${rollDeg.toStringAsFixed(1)}°, '
        'pitch=${pitchDeg.toStringAsFixed(1)}°, '
        'yaw=${yawDeg.toStringAsFixed(1)}°]}';
  }
}
