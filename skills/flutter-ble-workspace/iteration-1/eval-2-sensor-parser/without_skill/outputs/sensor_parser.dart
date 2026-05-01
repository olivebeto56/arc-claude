import 'dart:math' as math;
import 'dart:typed_data';

import 'sensor_data.dart';

/// Decodes raw BLE advertisement / notification packets from the wearable IMU
/// node into a strongly-typed [SensorData] object.
///
/// ## Packet layout (14–16 bytes, little-endian)
///
/// | Bytes  | Type   | Field                  | Scale           |
/// |--------|--------|------------------------|-----------------|
/// | 0 – 1  | uint16 | timestamp_ms           | 1 ms / LSB      |
/// | 2 – 3  | int16  | qw  (quaternion W)     | ÷ 10 000        |
/// | 4 – 5  | int16  | qx  (quaternion X)     | ÷ 10 000        |
/// | 6 – 7  | int16  | qy  (quaternion Y)     | ÷ 10 000        |
/// | 8 – 9  | int16  | qz  (quaternion Z)     | ÷ 10 000        |
/// | 10– 11 | int16  | accel_x  (milli-g)     | × 9.80665/1000  |
/// | 12– 13 | int16  | accel_y  (milli-g)     | × 9.80665/1000  |
/// | 14– 15 | int16  | accel_z  (milli-g)     | × 9.80665/1000  |
///
/// Bytes 14–15 are optional (some firmware revisions omit accel_z); if
/// absent the field defaults to 0.0.
class SensorParser {
  // ── Constants ───────────────────────────────────────────────────────────────

  /// Quaternion scale factor used by the firmware.
  static const double _kQuatScale = 10000.0;

  /// 1 milli-g expressed in m/s²  (1 g = 9.80665 m/s²).
  static const double _kMilliGToMs2 = 9.80665 / 1000.0;

  /// Minimum accepted packet length (no accel_z byte pair).
  static const int _kMinLength = 14;

  /// Maximum accepted / expected packet length.
  static const int _kMaxLength = 16;

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Parses [bytes] and returns a decoded [SensorData].
  ///
  /// Throws [ArgumentError] if the packet is shorter than [_kMinLength].
  /// Throws [FormatException] if the quaternion cannot be normalised (all
  /// components are zero).
  static SensorData parse(Uint8List bytes) {
    if (bytes.length < _kMinLength) {
      throw ArgumentError(
        'Packet too short: expected at least $_kMinLength bytes, '
        'got ${bytes.length}.',
      );
    }

    // Use a ByteData view for convenient little-endian reads.
    final bd = ByteData.sublistView(bytes);

    // ── Timestamp ──────────────────────────────────────────────────────────
    final int timestampMs = bd.getUint16(0, Endian.little);

    // ── Quaternion (raw int16 → normalised double) ─────────────────────────
    final double rawQw = bd.getInt16(2, Endian.little) / _kQuatScale;
    final double rawQx = bd.getInt16(4, Endian.little) / _kQuatScale;
    final double rawQy = bd.getInt16(6, Endian.little) / _kQuatScale;
    final double rawQz = bd.getInt16(8, Endian.little) / _kQuatScale;

    // Re-normalise to guard against firmware rounding errors.
    final norm =
        math.sqrt(rawQw * rawQw + rawQx * rawQx + rawQy * rawQy + rawQz * rawQz);
    if (norm < 1e-6) {
      throw FormatException(
        'Quaternion magnitude is near zero — packet may be corrupt.',
      );
    }
    final double qw = rawQw / norm;
    final double qx = rawQx / norm;
    final double qy = rawQy / norm;
    final double qz = rawQz / norm;

    // ── Acceleration (milli-g → m/s²) ─────────────────────────────────────
    final double accelX = bd.getInt16(10, Endian.little) * _kMilliGToMs2;
    final double accelY = bd.getInt16(12, Endian.little) * _kMilliGToMs2;
    final double accelZ = bytes.length >= _kMaxLength
        ? bd.getInt16(14, Endian.little) * _kMilliGToMs2
        : 0.0;

    // ── Euler angles from quaternion ───────────────────────────────────────
    final (roll, pitch, yaw) = _quaternionToEuler(qw, qx, qy, qz);

    return SensorData(
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

  // ── Private helpers ─────────────────────────────────────────────────────────

  /// Converts a unit quaternion (w, x, y, z) to intrinsic Tait-Bryan
  /// ZYX Euler angles (yaw → pitch → roll), returned in radians.
  ///
  /// Conventions:
  /// - Roll  φ : rotation around X-axis, range [−π,  π]
  /// - Pitch θ : rotation around Y-axis, range [−π/2, π/2]
  /// - Yaw   ψ : rotation around Z-axis, range [−π,  π]
  ///
  /// Gimbal-lock handling: when |sinθ| ≥ 1 (poles ±90°), yaw is set to 0
  /// and all rotation is absorbed into roll.
  static (double roll, double pitch, double yaw) _quaternionToEuler(
    double w,
    double x,
    double y,
    double z,
  ) {
    // Pre-compute reused products.
    final double sinr_cosp = 2.0 * (w * x + y * z);
    final double cosr_cosp = 1.0 - 2.0 * (x * x + y * y);
    final double roll = math.atan2(sinr_cosp, cosr_cosp);

    // Pitch — clamp argument to [−1, 1] to avoid NaN from floating-point drift.
    final double sinp = 2.0 * (w * y - z * x);
    final double pitch = sinp.abs() >= 1.0
        ? math.pi / 2.0 * sinp.sign // gimbal lock
        : math.asin(sinp.clamp(-1.0, 1.0));

    final double siny_cosp = 2.0 * (w * z + x * y);
    final double cosy_cosp = 1.0 - 2.0 * (y * y + z * z);
    final double yaw = math.atan2(siny_cosp, cosy_cosp);

    return (roll, pitch, yaw);
  }
}
