"""
analyze_session.py
------------------
Offline biomechanical analysis of running data from IMU wearables.

Expected CSV columns:
    timestamp_ms  : integer, milliseconds since session start
    node_id       : string/int identifying the wearable node
    accel_x       : float, m/s²
    accel_y       : float, m/s²
    accel_z       : float, m/s²
    pitch         : float, degrees

Usage:
    python analyze_session.py <path_to_csv>
    python analyze_session.py  # uses built-in synthetic data for testing
"""

import sys
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec
from scipy.signal import find_peaks


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
SAMPLE_RATE_HZ = 100          # samples per second
IMPACT_THRESHOLD = 12.0       # m/s² — minimum peak height to count as impact
IMPACT_MIN_DISTANCE = 20      # samples — ~200 ms at 100 Hz between consecutive impacts
CADENCE_WINDOW = 10           # number of steps used for rolling cadence
CADENCE_REF_LOW = 160         # spm reference line (lower target)
CADENCE_REF_HIGH = 180        # spm reference line (upper target)


# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------

def compute_accel_magnitude(df: pd.DataFrame) -> pd.Series:
    """Return the Euclidean magnitude of the 3-axis acceleration vector."""
    return np.sqrt(df["accel_x"] ** 2 + df["accel_y"] ** 2 + df["accel_z"] ** 2)


def detect_impacts(magnitude: np.ndarray) -> np.ndarray:
    """
    Detect ground-contact impact events using peak detection.

    Parameters
    ----------
    magnitude : array of acceleration magnitudes (m/s²)

    Returns
    -------
    indices : array of sample indices where impacts were detected
    """
    peaks, _ = find_peaks(
        magnitude,
        height=IMPACT_THRESHOLD,
        distance=IMPACT_MIN_DISTANCE,
    )
    return peaks


def compute_rolling_cadence(impact_indices: np.ndarray, total_samples: int) -> np.ndarray:
    """
    Compute a rolling cadence (steps per minute) over a window of CADENCE_WINDOW steps.

    The cadence at step k is estimated from the interval between the first and
    last impact in the window [k - CADENCE_WINDOW + 1 ... k].

    Returns a full-length array (NaN outside of valid windows) aligned to the
    original sample axis so it can be plotted with the same x-axis.
    """
    cadence = np.full(total_samples, np.nan)

    if len(impact_indices) < CADENCE_WINDOW:
        return cadence

    for i in range(CADENCE_WINDOW - 1, len(impact_indices)):
        window = impact_indices[i - CADENCE_WINDOW + 1 : i + 1]
        # Duration in seconds between first and last impact in the window
        duration_s = (window[-1] - window[0]) / SAMPLE_RATE_HZ
        if duration_s > 0:
            steps_in_window = CADENCE_WINDOW - 1          # intervals = steps - 1
            cadence_spm = (steps_in_window / duration_s) * 60.0
            # Assign value at the last impact sample of the window
            cadence[window[-1]] = cadence_spm

    return cadence


# ---------------------------------------------------------------------------
# Plotting
# ---------------------------------------------------------------------------

def plot_node(df_node: pd.DataFrame, node_id, fig_index: int):
    """Create a 3-panel figure (sharex) for a single node."""

    time_s = df_node["timestamp_ms"].values / 1000.0
    magnitude = df_node["accel_magnitude"].values
    pitch = df_node["pitch"].values
    impact_idx = df_node["impact"].values.astype(bool)
    cadence = df_node["cadence_spm"].values

    fig = plt.figure(figsize=(14, 9))
    fig.suptitle(f"Running Session Analysis — Node: {node_id}", fontsize=14, fontweight="bold")

    gs = gridspec.GridSpec(3, 1, figure=fig, hspace=0.45)
    ax1 = fig.add_subplot(gs[0])
    ax2 = fig.add_subplot(gs[1], sharex=ax1)
    ax3 = fig.add_subplot(gs[2], sharex=ax1)

    # --- Panel 1: Acceleration magnitude + detected impacts ---
    ax1.plot(time_s, magnitude, color="#1f77b4", linewidth=0.8, label="Accel magnitude (m/s²)")
    ax1.axhline(IMPACT_THRESHOLD, color="orange", linestyle="--", linewidth=1.0,
                label=f"Threshold ({IMPACT_THRESHOLD} m/s²)")
    impact_times = time_s[impact_idx]
    impact_vals = magnitude[impact_idx]
    ax1.scatter(impact_times, impact_vals, color="red", s=25, zorder=5, label="Detected impacts")
    ax1.set_ylabel("Magnitude (m/s²)")
    ax1.set_title("Acceleration Magnitude & Impact Detection")
    ax1.legend(loc="upper right", fontsize=8)
    ax1.grid(True, alpha=0.3)

    # --- Panel 2: Pitch at impact moments ---
    pitch_at_impacts = np.where(impact_idx, pitch, np.nan)
    ax2.plot(time_s, pitch, color="#aec7e8", linewidth=0.6, alpha=0.6, label="Pitch (all samples)")
    ax2.scatter(
        time_s[impact_idx],
        pitch[impact_idx],
        color="#d62728",
        s=25,
        zorder=5,
        label="Pitch at impact",
    )
    ax2.set_ylabel("Pitch (°)")
    ax2.set_title("Pitch Angle at Ground-Contact Impacts")
    ax2.legend(loc="upper right", fontsize=8)
    ax2.grid(True, alpha=0.3)

    # --- Panel 3: Rolling cadence ---
    valid = ~np.isnan(cadence)
    if valid.any():
        ax3.plot(time_s[valid], cadence[valid], color="#2ca02c", linewidth=1.5,
                 marker="o", markersize=3, label="Cadence (spm)")
    ax3.axhline(CADENCE_REF_LOW, color="purple", linestyle="--", linewidth=1.0,
                label=f"{CADENCE_REF_LOW} spm")
    ax3.axhline(CADENCE_REF_HIGH, color="magenta", linestyle="--", linewidth=1.0,
                label=f"{CADENCE_REF_HIGH} spm")
    ax3.fill_between(
        [time_s[0], time_s[-1]],
        CADENCE_REF_LOW,
        CADENCE_REF_HIGH,
        alpha=0.08,
        color="green",
        label="Target zone",
    )
    ax3.set_ylabel("Cadence (spm)")
    ax3.set_xlabel("Time (s)")
    ax3.set_title(f"Rolling Cadence ({CADENCE_WINDOW}-step window)")
    ax3.legend(loc="upper right", fontsize=8)
    ax3.grid(True, alpha=0.3)

    plt.tight_layout()
    return fig


# ---------------------------------------------------------------------------
# Main pipeline
# ---------------------------------------------------------------------------

def analyze_csv(filepath: str):
    """Load CSV, run analysis per node, display figures."""

    print(f"Loading data from: {filepath}")
    df = pd.read_csv(filepath)

    required_cols = {"timestamp_ms", "node_id", "accel_x", "accel_y", "accel_z", "pitch"}
    missing = required_cols - set(df.columns)
    if missing:
        raise ValueError(f"CSV is missing required columns: {missing}")

    df.sort_values(["node_id", "timestamp_ms"], inplace=True)
    df.reset_index(drop=True, inplace=True)

    node_ids = df["node_id"].unique()
    print(f"Found {len(node_ids)} node(s): {list(node_ids)}")

    for fig_idx, node_id in enumerate(node_ids):
        df_node = df[df["node_id"] == node_id].copy().reset_index(drop=True)
        n = len(df_node)

        print(f"\n--- Node: {node_id} | Samples: {n} | "
              f"Duration: {(df_node['timestamp_ms'].iloc[-1] - df_node['timestamp_ms'].iloc[0]) / 1000:.1f}s ---")

        # 1. Acceleration magnitude
        df_node["accel_magnitude"] = compute_accel_magnitude(df_node)

        # 2. Impact detection
        impact_indices = detect_impacts(df_node["accel_magnitude"].values)
        impact_mask = np.zeros(n, dtype=bool)
        impact_mask[impact_indices] = True
        df_node["impact"] = impact_mask

        print(f"  Detected impacts : {len(impact_indices)}")

        # 3. Rolling cadence
        cadence = compute_rolling_cadence(impact_indices, n)
        df_node["cadence_spm"] = cadence

        valid_cadence = cadence[~np.isnan(cadence)]
        if len(valid_cadence) > 0:
            print(f"  Cadence — mean: {np.nanmean(cadence):.1f} spm  "
                  f"min: {np.nanmin(cadence):.1f}  max: {np.nanmax(cadence):.1f}")
        else:
            print("  Not enough impacts to compute cadence.")

        # 4. Plot
        plot_node(df_node, node_id, fig_idx)

    plt.show()


# ---------------------------------------------------------------------------
# Synthetic data generator (for standalone testing without a real CSV)
# ---------------------------------------------------------------------------

def generate_synthetic_csv(filepath: str = "/tmp/synthetic_running.csv",
                            duration_s: int = 30,
                            nodes: list = None):
    """
    Write a synthetic running CSV for testing.
    Simulates two nodes with realistic gait signals.
    """
    if nodes is None:
        nodes = ["left_ankle", "right_ankle"]

    rng = np.random.default_rng(42)
    rows = []
    samples = duration_s * SAMPLE_RATE_HZ
    t = np.arange(samples)
    t_s = t / SAMPLE_RATE_HZ

    for node in nodes:
        # Simulate vertical acceleration with impact spikes at ~170 spm (~2.83 Hz)
        cadence_hz = 170 / 60
        phase_offset = np.pi if node == "right_ankle" else 0.0

        base_accel_y = 9.81 + 3.0 * np.sin(2 * np.pi * cadence_hz * t_s + phase_offset)
        # Add impact spikes
        impact_period = int(SAMPLE_RATE_HZ / cadence_hz)
        spike = np.zeros(samples)
        for start in range(int(impact_period * 0.1), samples, impact_period):
            if start < samples:
                spike[start] = rng.uniform(5.0, 8.0)

        accel_y = base_accel_y + spike
        accel_x = rng.normal(0.5, 0.3, samples)
        accel_z = rng.normal(0.2, 0.2, samples)
        pitch = -5 + 10 * np.sin(2 * np.pi * cadence_hz * t_s + phase_offset) + rng.normal(0, 1, samples)

        for i in range(samples):
            rows.append({
                "timestamp_ms": int(t[i] * 10),  # 100 Hz -> 10 ms steps
                "node_id": node,
                "accel_x": round(float(accel_x[i]), 4),
                "accel_y": round(float(accel_y[i]), 4),
                "accel_z": round(float(accel_z[i]), 4),
                "pitch": round(float(pitch[i]), 4),
            })

    pd.DataFrame(rows).to_csv(filepath, index=False)
    print(f"Synthetic CSV written to: {filepath}")
    return filepath


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    if len(sys.argv) >= 2:
        csv_path = sys.argv[1]
    else:
        print("No CSV path provided — generating synthetic data for demonstration.")
        csv_path = generate_synthetic_csv()

    analyze_csv(csv_path)
