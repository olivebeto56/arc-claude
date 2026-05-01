// services/sensor_parser.dart
// Decodes raw BLE notification bytes from the XIAO nRF52840 + BNO085 node
// into a SensorData object (quaternion + linear acceleration + Euler angles).
//
// Packet format (little-endian, 14–16 bytes):
//
//   Offset  Type    Field         Scale            Description
//   ──────  ──────  ────────────  ───────────────  ──────────────────────────────
//   0–1     uint16  timestamp_ms  1 ms/LSB         Time relative to session start
//   2–3     int16   qw            ÷ 10 000         Quaternion real part
//   4–5     int16   qx            ÷ 10 000         Quaternion i component
//   6–7     int16   qy            ÷ 10 000         Quaternion j component
//   8–9     int16   qz            ÷ 10 000         Quaternion k component
//   10–11   int16   accel_x       × 9.81 / 1000    Linear acceleration X (m/s²)
//   12–13   int16   accel_y       × 9.81 / 1000    Linear acceleration Y (m/s²)
//   14–15   int16   accel_z       × 9.81 / 1000    Linear acceleration Z (m/s²)
//
// The 14-byte variant (firmware v1) omits accel_z; the parser substitutes 0.0.
// Packets shorter than 14 bytes are considered malformed and return null.

import 'dart:typed_data';

import 'sensor_data.dart';

/// Stateless parser for BLE sensor packets.
///
/// Usage:
/// ```dart
/// final data = SensorParser.parse(bytes, 'LEFT_ANKLE');
/// if (data != null) { /* use data */ }
/// ```
class SensorParser {
  // ---------------------------------------------------------------------------
  // Scaling constants
  // ---------------------------------------------------------------------------

  /// Converts the int16 quaternion fields (scaled × 10 000 by firmware) back
  /// to the normalised [-1, 1] range expected by the Euler-angle formulas.
  static const double _quatScale = 1.0 / 10000.0;

  /// Converts the int16 acceleration fields from milli-g to m/s².
  /// 1 g = 9.81 m/s²  →  1 milli-g = 9.81 / 1000 m/s²
  static const double _accelScale = 9.81 / 1000.0;

  // ---------------------------------------------------------------------------
  // Byte offsets (avoids magic numbers throughout the method body)
  // ---------------------------------------------------------------------------
  static const int _offsetTimestamp = 0;
  static const int _offsetQw = 2;
  static const int _offsetQx = 4;
  static const int _offsetQy = 6;
  static const int _offsetQz = 8;
  static const int _offsetAccelX = 10;
  static const int _offsetAccelY = 12;
  static const int _offsetAccelZ = 14;

  /// Minimum packet length required for a valid parse (no accel_z).
  static const int _minPacketLength = 14;

  /// Full packet length including accel_z.
  static const int _fullPacketLength = 16;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Decodes [bytes] received from the BLE notification characteristic and
  /// returns a [SensorData] instance, or `null` if the packet is malformed.
  ///
  /// [nodeId] identifies which node sent the packet
  /// ("LEFT_ANKLE" or "RIGHT_ANKLE").
  ///
  /// This method is safe to call on every BLE notification callback; it never
  /// throws — any decoding error produces a `null` return value.
  static SensorData? parse(List<int> bytes, String nodeId) {
    // Guard: reject packets that are too short to contain all mandatory fields.
    if (bytes.length < _minPacketLength) {
      return null;
    }

    try {
      // Wrap the byte list in a ByteData view for typed little-endian reads.
      final ByteData buf =
          ByteData.sublistView(Uint8List.fromList(bytes));

      // --- Timestamp (uint16, little-endian) ----------------------------------
      final int timestampMs = buf.getUint16(_offsetTimestamp, Endian.little);

      // --- Quaternion components (int16 → double) ----------------------------
      // The BNO085 outputs unit quaternions; the firmware multiplies each
      // component by 10 000 before packing into int16 to preserve four decimal
      // places of precision without using floats over BLE.
      final double qw = buf.getInt16(_offsetQw, Endian.little) * _quatScale;
      final double qx = buf.getInt16(_offsetQx, Endian.little) * _quatScale;
      final double qy = buf.getInt16(_offsetQy, Endian.little) * _quatScale;
      final double qz = buf.getInt16(_offsetQz, Endian.little) * _quatScale;

      // --- Linear acceleration (int16 milli-g → double m/s²) -----------------
      // The BNO085 reports linear acceleration with gravity already removed.
      // Axis convention when mounted on the ankle (flat side up):
      //   X → forward (direction of travel)
      //   Y → upward  (perpendicular to ground) — used for impact detection
      //   Z → right   (lateral)
      final double accelX =
          buf.getInt16(_offsetAccelX, Endian.little) * _accelScale;
      final double accelY =
          buf.getInt16(_offsetAccelY, Endian.little) * _accelScale;

      // accel_z is only present in the full 16-byte packet (firmware v1 sends
      // 14 bytes without accel_z; substitute 0.0 to keep the struct complete).
      final double accelZ = bytes.length >= _fullPacketLength
          ? buf.getInt16(_offsetAccelZ, Endian.little) * _accelScale
          : 0.0;

      // --- Build SensorData (Euler angles computed inside fromQuaternion) -----
      return SensorData.fromQuaternion(
        nodeId: nodeId,
        timestampMs: timestampMs,
        qw: qw,
        qx: qx,
        qy: qy,
        qz: qz,
        accelX: accelX,
        accelY: accelY,
        accelZ: accelZ,
      );
    } catch (_) {
      // Any unexpected error (e.g. a buffer view that's shorter than expected
      // at runtime) is silently swallowed and reported as a null sample so
      // that a single bad packet does not crash the stream.
      return null;
    }
  }

  /// Validates that [bytes] looks like a plausible sensor packet before
  /// attempting a full parse.
  ///
  /// Returns `true` when the packet length falls in the expected [14, 16]
  /// range. This can be used as a cheap pre-filter inside the BLE callback
  /// before calling [parse].
  static bool isValidLength(List<int> bytes) =>
      bytes.length >= _minPacketLength && bytes.length <= _fullPacketLength;
}
