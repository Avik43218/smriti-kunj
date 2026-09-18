"""Glue between sync ingestion and Pillar 3 drift/anomaly detection.
Runs synchronously after each batch for this scaffold; move to a scheduled
worker (Celery beat / APScheduler) once volume makes per-request recompute
costly."""
from datetime import datetime, timedelta

from app.config import settings
from app.core.alerts import raise_alert
from app.core.drift import compute_drift, detect_anomaly
from app.models.analytics import AlertSeverity, DriftMetric
from app.models.session import GameSession


async def _scores_since(patient_id, days: int):
    since = datetime.utcnow() - timedelta(days=days)
    rows = (
        await GameSession.find(
            GameSession.patient_id == patient_id,
            GameSession.client_timestamp >= since,
        )
        .sort("+client_timestamp")
        .to_list()
    )
    return [r.performance_score for r in rows if r.performance_score is not None], rows


async def run_anomaly_check(patient_id) -> int:
    alerts_triggered = 0

    for window in (settings.DRIFT_WINDOW_SHORT_DAYS, settings.DRIFT_WINDOW_LONG_DAYS):
        scores, _ = await _scores_since(patient_id, window)
        if len(scores) < 3:
            continue

        drift = compute_drift(scores)
        await DriftMetric(
            patient_id=patient_id,
            window_days=window,
            slope=drift.slope,
            intercept=drift.intercept,
            r_squared=drift.r_squared,
            sample_count=drift.sample_count,
        ).insert()

        if drift.declining:
            await raise_alert(
                patient_id,
                "cognitive_drift",
                f"{window}-day performance trend is declining (slope={drift.slope:.3f})",
                severity=AlertSeverity.medium,
            )
            alerts_triggered += 1

    _, rows_7 = await _scores_since(patient_id, 7)
    if len(rows_7) >= 2:
        history, today = rows_7[:-1], rows_7[-1]
        baseline_accuracy = sum(r.accuracy for r in history) / len(history)
        baseline_hesitation = sum(r.avg_latency_ms for r in history) / len(history)
        baseline_std = (
            sum((r.avg_latency_ms - baseline_hesitation) ** 2 for r in history) / len(history)
        ) ** 0.5

        is_anomaly, message = detect_anomaly(
            baseline_accuracy, today.accuracy, baseline_std, today.avg_latency_ms, baseline_hesitation
        )
        if is_anomaly:
            await raise_alert(patient_id, "anomaly", message, severity=AlertSeverity.high)
            alerts_triggered += 1

    return alerts_triggered
