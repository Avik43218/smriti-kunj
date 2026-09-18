"""Pillar 3: Predictive Analytics & Anomaly Detection."""
from dataclasses import dataclass
from typing import List, Tuple

import numpy as np

from app.config import settings


@dataclass
class DriftResult:
    slope: float
    intercept: float
    r_squared: float
    sample_count: int
    declining: bool


def compute_drift(scores: List[float]) -> DriftResult:
    """Fit y_hat = beta_0 + beta_1 * x over a rolling window of performance
    scores. A meaningfully negative beta_1 indicates cognitive decline."""
    n = len(scores)
    if n < 2:
        return DriftResult(
            slope=0.0,
            intercept=scores[0] if scores else 0.0,
            r_squared=0.0,
            sample_count=n,
            declining=False,
        )

    x = np.arange(n)
    y = np.array(scores)
    beta_1, beta_0 = np.polyfit(x, y, 1)

    y_pred = beta_0 + beta_1 * x
    ss_res = float(np.sum((y - y_pred) ** 2))
    ss_tot = float(np.sum((y - y.mean()) ** 2))
    r_squared = 1 - ss_res / ss_tot if ss_tot > 0 else 0.0

    return DriftResult(
        slope=float(beta_1),
        intercept=float(beta_0),
        r_squared=r_squared,
        sample_count=n,
        declining=bool(beta_1 < -0.01),  # tune this threshold against real cohort data
    )


def detect_anomaly(
    baseline_accuracy: float,
    todays_accuracy: float,
    baseline_std: float,
    todays_hesitation: float,
    baseline_hesitation: float,
) -> Tuple[bool, str]:
    """Flags a >25% accuracy drop vs baseline, or a hesitation (latency) spike
    beyond 2 standard deviations of the recent baseline."""
    if baseline_accuracy > 0:
        drop = (baseline_accuracy - todays_accuracy) / baseline_accuracy
        if drop > settings.ALERT_ACCURACY_DROP_THRESHOLD:
            return True, f"Recall accuracy dropped {drop:.0%} vs baseline"

    if baseline_std > 0:
        z = (todays_hesitation - baseline_hesitation) / baseline_std
        if z > 2:
            return True, f"Hesitation spike: {z:.1f} std devs above baseline"

    return False, ""
