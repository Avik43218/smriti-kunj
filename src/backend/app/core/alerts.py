"""Persist caregiver-facing alerts and (stub) dispatch them out-of-band."""
from app.models.analytics import Alert, AlertSeverity


async def raise_alert(
    patient_id,
    alert_type: str,
    message: str,
    severity: AlertSeverity = AlertSeverity.high,
) -> Alert:
    alert = Alert(patient_id=patient_id, alert_type=alert_type, message=message, severity=severity)
    await alert.insert()
    # TODO: push to caregiver portal in real time — FCM push, email, or SMS.
    return alert
