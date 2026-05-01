// models/sensor_data.dart
// Data model for a single IMU sample decoded from a BLE packet.
// Quaternion components are stored as normalized doubles; Euler angles
// (roll, pitch, yaw) are pre-computed in degrees on construction.

import 'dart:math' as math;

/// Represents one decoded sensor sample from a XIAO+BNO085 node.
class SensorData {
  /// Identifier of the node that produced this sample.
  /// Expected values: "LEFT_ANKLE" or "RIGHT_ANKLE".
  final String nodeId;

  /// Timestamp in milliseconds relative to the start of the session.
  /// Decoded from the uint16 at bytes 0–1 of the BLE packet.
  final int timestampMs;

  // --- Quaternion components (unit quaternion, dimensionless) ---
  final double qw;
  final double qx;
  final double qy;
  final double qz;

  // --- Linear acceleration without gravity (m/s²) ---
  final double accelX;
  final double accelY;
  final double accelZ;

  // --- Euler angles derived from the quaternion (degrees) ---
  /// Roll: rotation around the forward (X) axis.
  final double roll;

  /// Pitch: rotation around the lateral (Z) axis.
  /// Positive → heel-first contact; negative → forefoot contact.
  final double pitch;

  /// Yaw: rotation around the vertical (Y) axis.
  /// Captures pronation / supination when mounted on the ankle.
  final double yaw;

  const SensorData({
    required this.nodeId,
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

  /// Factory constructor that accepts raw quaternion components and
  /// computes the Euler angles automatically before returning the object.
  ///
  /// Euler conversion uses the ZYX (aerospace / Tait-Bryan) convention:
  ///   roll  = atan2(2(qw·qx + qy·qz), 1 − 2(qx² + qy²))
  ///   pitch = asin (2(qw·qy − qz·qx))         — clamped to ±90°
  ///   yaw   = atan2(2(qw·qz + qx·qy), 1 − 2(qy² + qz²))
  static SensorData fromQuaternion({
    required String nodeId,
    required int timestampMs,
    required double qw,
    required double qx,
    required double qy,
    required double qz,
    required double accelX,
    required double accelY,
    required double accelZ,
  }) {
    // Roll (X-axis rotation)
    final double roll = math.atan2(
          2.0 * (qw * qx + qy * qz),
          1.0 - 2.0 * (qx * qx + qy * qy),
        ) *
        (180.0 / math.pi);

    // Pitch (Y-axis rotation) — clamp the sine argument to [-1, 1]
    // to guard against floating-point rounding outside the valid range.
    final double sinp = 2.0 * (qw * qy - qz * qx);
    final double pitch;
    if (sinp.abs() >= 1.0) {
      // Gimbal-lock fallback: clamp to ±90°
      pitch = math.pi / 2.0 * sinp.sign * (180.0 / math.pi);
    } else {
      pitch = math.asin(sinp) * (180.0 / math.pi);
    }

    // Yaw (Z-axis rotation)
    final double yaw = math.atan2(
          2.0 * (qw * qz + qx * qy),
          1.0 - 2.0 * (qy * qy + qz * qz),
        ) *
        (180.0 / math.pi);

    return SensorData(
      nodeId: nodeId,
      timestampMs: timestampMs,
      qw: qw,
      qx: qx,
      qy: qy,
      qz: qz,
      accelX: accelX,
      accelY: accelY,
      accelZ: accelZ,
      roll: roll,
      pitch: pitch,
      yaw: yaw,
    );
  }

  @override
  String toString() =>
      'SensorData(node=$nodeId, ts=${timestampMs}ms, '
      'q=[$qw, $qx, $qy, $qz], '
      'accel=[$accelX, $accelY, $accelZ] m/s², '
      'euler=[r=${roll.toStringAsFixed(1)}° '
      'p=${pitch.toStringAsFixed(1)}° '
      'y=${yaw.toStringAsFixed(1)}°])';
}

/// Running-session aggregate metrics derived from one or both ankle nodes.
class RunningMetrics {
  /// Cadence in steps per minute (both feet combined).
  final double cadenceStepsPerMin;

  /// L/R symmetry percentage. 50 % = perfectly symmetric.
  /// Values below 45 % or above 55 % indicate significant asymmetry.
  final double symmetryPercent;

  /// Average ground-contact time in milliseconds.
  final double avgContactTimeMs;

  /// Foot-strike angle in degrees at the moment of impact.
  /// Positive → heel-first; negative → forefoot.
  final double strikeAngleDeg;

  /// Coefficient of variation of stride intervals (dimensionless, 0–1).
  /// Lower values indicate more consistent cadence.
  final double strideVariability;

  /// Total step count accumulated in the current session.
  final int stepCount;

  /// Optional real-time coaching recommendation (null when all metrics
  /// are within healthy ranges).
  final String? recommendation;

  const RunningMetrics({
    required this.cadenceStepsPerMin,
    required this.symmetryPercent,
    required this.avgContactTimeMs,
    required this.strikeAngleDeg,
    required this.strideVariability,
    required this.stepCount,
    this.recommendation,
  });
}
