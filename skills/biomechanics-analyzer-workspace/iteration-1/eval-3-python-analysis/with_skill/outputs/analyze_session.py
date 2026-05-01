"""
analyze_session.py — Análisis offline de sesiones del wearable deportivo.

Carga un CSV con columnas:
    timestamp_ms, node_id, accel_x, accel_y, accel_z, pitch

Detecta impactos con scipy.signal.find_peaks, calcula cadencia rolling
y genera una figura de 3 paneles:
  1. Magnitud de aceleración con picos marcados
  2. Pitch en los instantes de impacto
  3. Cadencia rolling de 10 pasos (spm)

Uso:
    python analyze_session.py session.csv [NODE_ID]

Dependencias:
    pip install pandas numpy matplotlib scipy

Referencias de umbrales:
    running_biomechanics.md — Heiderscheit 2011, Lieberman 2010, Morin 2011
"""

import sys
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from scipy.signal import find_peaks

# ──────────────────────────────────────────────────────────────────────────────
# Parámetros configurables (calibrar con datos reales del prototipo)
# ──────────────────────────────────────────────────────────────────────────────

# Detección de impactos
IMPACT_THRESHOLD_MS2 = 12.0   # m/s²  — umbral de pico (BNO085 a tobillo, ~10–12 km/h)
MIN_STEP_DISTANCE_MS = 200    # ms     — 300 spm es el máximo fisiológico → 200 ms mínimo
SAMPLE_RATE_HZ       = 100    # Hz     — frecuencia de muestreo del sensor

# Ventana de cadencia rolling
CADENCE_WINDOW_STEPS = 10     # pasos — ventana deslizante (igual que MetricsCalculator en Dart)

# Umbrales normativos de cadencia (running_biomechanics.md)
CADENCE_LOW_SPM      = 160    # spm — cadencia baja
CADENCE_OPTIMAL_SPM  = 180    # spm — cadencia óptima

# Umbrales de ángulo de pisada (running_biomechanics.md — Lieberman 2010)
STRIKE_ANGLE_WARNING_DEG  = 10.0   # ° — heel strike moderado
STRIKE_ANGLE_CRITICAL_DEG = 20.0   # ° — heel strike severo


# ──────────────────────────────────────────────────────────────────────────────
# Carga y validación del CSV
# ──────────────────────────────────────────────────────────────────────────────

REQUIRED_COLUMNS = {"timestamp_ms", "node_id", "accel_x", "accel_y", "accel_z", "pitch"}


def load_session(csv_path: str) -> pd.DataFrame:
    """Carga el CSV de sesión y valida las columnas requeridas."""
    df = pd.read_csv(csv_path)
    missing = REQUIRED_COLUMNS - set(df.columns)
    if missing:
        raise ValueError(
            f"Columnas faltantes en el CSV: {missing}\n"
            f"Columnas esperadas: {REQUIRED_COLUMNS}"
        )
    df = df.sort_values("timestamp_ms").reset_index(drop=True)
    return df


# ──────────────────────────────────────────────────────────────────────────────
# Cálculo de magnitud de aceleración
# ──────────────────────────────────────────────────────────────────────────────

def accel_magnitude(df: pd.DataFrame) -> pd.Series:
    """Magnitud del vector de aceleración lineal (sin gravedad, ya filtrada por BNO085)."""
    return np.sqrt(df.accel_x**2 + df.accel_y**2 + df.accel_z**2)


# ──────────────────────────────────────────────────────────────────────────────
# Detección de impactos
# ──────────────────────────────────────────────────────────────────────────────

def detect_impacts(
    mag: pd.Series,
    sample_rate_hz: float = SAMPLE_RATE_HZ,
    threshold: float = IMPACT_THRESHOLD_MS2,
    min_distance_ms: int = MIN_STEP_DISTANCE_MS,
) -> np.ndarray:
    """
    Detecta picos de impacto usando scipy.signal.find_peaks.

    Parámetros:
        mag             — Serie de magnitud de aceleración (m/s²)
        sample_rate_hz  — Frecuencia de muestreo del sensor (Hz)
        threshold       — Altura mínima del pico (m/s²)
        min_distance_ms — Distancia mínima entre picos consecutivos (ms)

    Retorna:
        Índices de los picos en el array de magnitud.

    Nota: min_distance se convierte a muestras usando el sample rate para
    que sea independiente del rate de captura real del CSV.
    """
    min_distance_samples = max(1, int(min_distance_ms * sample_rate_hz / 1000))
    peaks, _ = find_peaks(mag, height=threshold, distance=min_distance_samples)
    return peaks


# ──────────────────────────────────────────────────────────────────────────────
# Cálculo de cadencia rolling
# ──────────────────────────────────────────────────────────────────────────────

def cadence_timeseries(
    impact_timestamps_ms: np.ndarray,
    window: int = CADENCE_WINDOW_STEPS,
) -> pd.Series:
    """
    Calcula cadencia rolling (pasos/min) a partir de timestamps de impactos.

    Cada intervalo entre impactos consecutivos del mismo nodo representa un paso
    (running_biomechanics.md: cadencia = 60000 / intervalo_promedio_entre_pasos).

    Retorna:
        Serie con cadencia en spm para cada paso desde el segundo impacto en adelante.
        Longitud = len(impact_timestamps_ms) - 1
    """
    intervals_ms = np.diff(impact_timestamps_ms)
    # Filtrar intervalos fuera de rango fisiológico (200 ms – 2000 ms)
    valid_mask = (intervals_ms >= 200) & (intervals_ms <= 2000)
    cadence_per_step = np.where(valid_mask, 60000.0 / intervals_ms, np.nan)
    rolling = pd.Series(cadence_per_step).rolling(window=window, min_periods=1).mean()
    return rolling


# ──────────────────────────────────────────────────────────────────────────────
# Métricas de resumen
# ──────────────────────────────────────────────────────────────────────────────

def compute_summary(
    node_df: pd.DataFrame,
    peaks: np.ndarray,
    cadence_series: pd.Series,
) -> dict:
    """Calcula métricas de resumen de la sesión para un nodo."""
    impact_pitches = node_df.pitch.iloc[peaks].values

    summary = {
        "total_impacts": len(peaks),
        "avg_cadence_spm": float(cadence_series.mean()) if len(cadence_series) > 0 else 0.0,
        "min_cadence_spm": float(cadence_series.min()) if len(cadence_series) > 0 else 0.0,
        "max_cadence_spm": float(cadence_series.max()) if len(cadence_series) > 0 else 0.0,
        "avg_strike_angle_deg": float(np.mean(impact_pitches)) if len(impact_pitches) > 0 else 0.0,
        "avg_impact_load_ms2": float(accel_magnitude(node_df).iloc[peaks].mean()) if len(peaks) > 0 else 0.0,
    }

    # Variabilidad de zancada (CV de intervalos)
    if len(peaks) > 2:
        intervals_ms = np.diff(node_df.timestamp_ms.iloc[peaks].values)
        valid = intervals_ms[(intervals_ms >= 200) & (intervals_ms <= 2000)]
        if len(valid) > 1 and np.mean(valid) > 0:
            summary["stride_variability_pct"] = float(
                (np.std(valid) / np.mean(valid)) * 100.0
            )
        else:
            summary["stride_variability_pct"] = 0.0
    else:
        summary["stride_variability_pct"] = 0.0

    return summary


def print_summary(node_id: str, summary: dict) -> None:
    """Imprime el resumen de métricas en consola."""
    print(f"\n{'='*55}")
    print(f"  Resumen de sesión — Nodo: {node_id}")
    print(f"{'='*55}")
    print(f"  Impactos detectados : {summary['total_impacts']}")
    print(f"  Cadencia promedio   : {summary['avg_cadence_spm']:.1f} spm")
    print(f"  Cadencia mín/máx    : {summary['min_cadence_spm']:.1f} / {summary['max_cadence_spm']:.1f} spm")
    print(f"  Ángulo pisada (avg) : {summary['avg_strike_angle_deg']:.1f}°")
    print(f"  Carga impacto (avg) : {summary['avg_impact_load_ms2']:.1f} m/s²")
    print(f"  Variabilidad zancada: {summary['stride_variability_pct']:.1f}%")

    # Evaluación cualitativa (running_biomechanics.md)
    c = summary["avg_cadence_spm"]
    if c > 0:
        if c < 150:
            cad_label = "Muy baja — riesgo articular"
        elif c < 160:
            cad_label = "Baja — aumentar frecuencia"
        elif c <= 185:
            cad_label = "Optima"
        elif c <= 200:
            cad_label = "Alta — aceptable"
        else:
            cad_label = "Muy alta"
        print(f"  Evaluacion cadencia : {cad_label}")

    a = summary["avg_strike_angle_deg"]
    if a > STRIKE_ANGLE_CRITICAL_DEG:
        print(f"  Evaluacion pisada   : Heel strike severo (>{STRIKE_ANGLE_CRITICAL_DEG}°) — aterriza bajo tu centro de masa")
    elif a > STRIKE_ANGLE_WARNING_DEG:
        print(f"  Evaluacion pisada   : Heel strike moderado ({STRIKE_ANGLE_WARNING_DEG}–{STRIKE_ANGLE_CRITICAL_DEG}°)")
    elif a >= 0:
        print(f"  Evaluacion pisada   : Midfoot strike — eficiente")
    else:
        print(f"  Evaluacion pisada   : Forefoot strike")

    if summary["stride_variability_pct"] > 8:
        print(f"  Evaluacion ritmo    : Alta variabilidad — posible fatiga")
    elif summary["stride_variability_pct"] > 6:
        print(f"  Evaluacion ritmo    : Ligeramente irregular")
    else:
        print(f"  Evaluacion ritmo    : Regular")

    print(f"{'='*55}\n")


# ──────────────────────────────────────────────────────────────────────────────
# Visualización: 3 paneles
# ──────────────────────────────────────────────────────────────────────────────

def plot_session(df: pd.DataFrame, node_id: str, threshold: float = IMPACT_THRESHOLD_MS2) -> None:
    """
    Genera figura de 3 paneles para un nodo:
      Panel 1 — Magnitud de aceleración con picos de impacto marcados
      Panel 2 — Pitch en los instantes de impacto (ángulo de pisada)
      Panel 3 — Cadencia rolling de CADENCE_WINDOW_STEPS pasos
    """
    node = df[df.node_id == node_id].copy().reset_index(drop=True)
    if node.empty:
        print(f"[AVISO] No hay datos para el nodo '{node_id}'")
        return

    mag = accel_magnitude(node)
    peaks = detect_impacts(mag, threshold=threshold)

    # ── Cadencia ────────────────────────────────────────────────────────────
    cadence_series = pd.Series(dtype=float)
    cadence_times  = np.array([])
    if len(peaks) > 1:
        cadence_series = cadence_timeseries(node.timestamp_ms.iloc[peaks].values)
        cadence_times  = node.timestamp_ms.iloc[peaks[1:]].values  # empieza en el 2° pico

    # ── Resumen ──────────────────────────────────────────────────────────────
    summary = compute_summary(node, peaks, cadence_series)
    print_summary(node_id, summary)

    # ── Figura ───────────────────────────────────────────────────────────────
    fig, axes = plt.subplots(3, 1, figsize=(14, 9), sharex=True)
    fig.suptitle(
        f"Análisis de sesión — Nodo: {node_id}  |  "
        f"{summary['total_impacts']} impactos  |  "
        f"Cadencia avg: {summary['avg_cadence_spm']:.1f} spm",
        fontsize=12,
        fontweight="bold",
    )

    t = node.timestamp_ms / 1000.0  # convertir a segundos para el eje X

    # ── Panel 1: Magnitud de aceleración ─────────────────────────────────────
    ax0 = axes[0]
    ax0.plot(t, mag, lw=0.7, color="#1f77b4", alpha=0.85, label="|accel| (m/s²)")
    ax0.axhline(
        threshold, color="red", ls="--", lw=1.0, alpha=0.7,
        label=f"Umbral impacto = {threshold} m/s²",
    )
    if len(peaks) > 0:
        ax0.scatter(
            t.iloc[peaks], mag.iloc[peaks],
            c="red", s=25, zorder=5, label=f"{len(peaks)} impactos",
        )
    ax0.axhspan(8, 15, alpha=0.07, color="green", label="Rango normal (8–15 m/s²)")
    ax0.set_ylabel("Aceleración (m/s²)")
    ax0.legend(fontsize=7, loc="upper right")
    ax0.grid(True, alpha=0.3)

    # ── Panel 2: Pitch en los instantes de impacto ───────────────────────────
    ax1 = axes[1]
    ax1.plot(t, node.pitch, lw=0.6, color="#2ca02c", alpha=0.5, label="Pitch continuo")
    if len(peaks) > 0:
        ax1.scatter(
            t.iloc[peaks], node.pitch.iloc[peaks],
            c="darkgreen", s=30, zorder=5, label="Pitch en impacto",
        )
    ax1.axhline(
        STRIKE_ANGLE_WARNING_DEG, color="orange", ls=":", lw=1.2, alpha=0.8,
        label=f"{STRIKE_ANGLE_WARNING_DEG}° — heel strike moderado",
    )
    ax1.axhline(
        STRIKE_ANGLE_CRITICAL_DEG, color="red", ls=":", lw=1.2, alpha=0.8,
        label=f"{STRIKE_ANGLE_CRITICAL_DEG}° — heel strike severo",
    )
    ax1.axhline(0, color="gray", ls="-", lw=0.5, alpha=0.4)
    ax1.set_ylabel("Pitch en impacto (°)")
    ax1.legend(fontsize=7, loc="upper right")
    ax1.grid(True, alpha=0.3)

    # ── Panel 3: Cadencia rolling ─────────────────────────────────────────────
    ax2 = axes[2]
    if len(cadence_times) > 0 and len(cadence_series) > 0:
        cadence_t = cadence_times / 1000.0  # a segundos
        ax2.plot(
            cadence_t, cadence_series.values,
            lw=1.5, color="#9467bd",
            label=f"Cadencia rolling {CADENCE_WINDOW_STEPS} pasos",
        )
        ax2.fill_between(cadence_t, cadence_series.values, alpha=0.15, color="#9467bd")
        ax2.axhline(
            CADENCE_LOW_SPM, color="orange", ls=":", lw=1.2, alpha=0.8,
            label=f"{CADENCE_LOW_SPM} spm — límite bajo",
        )
        ax2.axhline(
            CADENCE_OPTIMAL_SPM, color="green", ls=":", lw=1.2, alpha=0.8,
            label=f"{CADENCE_OPTIMAL_SPM} spm — óptimo",
        )
        ax2.axhspan(
            CADENCE_LOW_SPM, CADENCE_OPTIMAL_SPM, alpha=0.07, color="green",
        )
        ax2.set_ylim(bottom=max(0, cadence_series.dropna().min() - 20) if not cadence_series.dropna().empty else 0)
    else:
        ax2.text(
            0.5, 0.5, "No hay suficientes impactos para calcular cadencia",
            transform=ax2.transAxes, ha="center", va="center", color="gray",
        )
    ax2.set_ylabel("Cadencia (pasos/min)")
    ax2.set_xlabel("Tiempo (s)")
    ax2.legend(fontsize=7, loc="upper right")
    ax2.grid(True, alpha=0.3)

    plt.tight_layout()
    plt.show()


# ──────────────────────────────────────────────────────────────────────────────
# Punto de entrada
# ──────────────────────────────────────────────────────────────────────────────

def main():
    if len(sys.argv) < 2:
        print(__doc__)
        print("Uso: python analyze_session.py <session.csv> [NODE_ID]")
        sys.exit(1)

    csv_path = sys.argv[1]
    target_node = sys.argv[2] if len(sys.argv) > 2 else None

    print(f"Cargando sesión: {csv_path}")
    df = load_session(csv_path)

    nodes = [target_node] if target_node else df.node_id.unique().tolist()
    print(f"Nodos encontrados: {df.node_id.unique().tolist()}")
    print(f"Analizando: {nodes}")

    for nid in nodes:
        plot_session(df, nid, threshold=IMPACT_THRESHOLD_MS2)


if __name__ == "__main__":
    main()
