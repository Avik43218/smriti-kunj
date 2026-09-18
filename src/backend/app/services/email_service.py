"""
Brevo (formerly Sendinblue) Transactional Email Service
======================================================
Dispatches one-time verification passwords (OTP) to caregivers and administrators
via the Brevo REST API (v3/smtp/email).
"""

import logging
from typing import Optional
import httpx

from app.config import settings

logger = logging.getLogger(__name__)

BREVO_API_URL = "https://api.brevo.com/v3/smtp/email"


def _build_otp_html_content(otp_code: str, expire_minutes: int, email: str) -> str:
    """Renders a responsive, culturally dignified HTML email template."""
    return f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Smriti Kunj Verification Code</title>
</head>
<body style="margin:0;padding:0;background-color:#FBF5EA;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;color:#2E2A24;">
  <table width="100%" border="0" cellspacing="0" cellpadding="0" style="background-color:#FBF5EA;padding:40px 10px;">
    <tr>
      <td align="center">
        <table width="100%" max-width="540" border="0" cellspacing="0" cellpadding="0" style="max-width:540px;background-color:#FFFFFF;border-radius:16px;overflow:hidden;box-shadow:0 8px 24px rgba(46,42,36,0.08);border:1px solid #EBE0D0;">
          
          <!-- Header Bar with Traditional Terracotta Accent -->
          <tr>
            <td style="background-color:#2E2A24;padding:28px 32px;text-align:center;border-bottom:3px solid #B5562F;">
              <h1 style="margin:0;color:#FBF5EA;font-size:22px;font-weight:700;letter-spacing:0.5px;">
                স্মৃতি কুঞ্জ <span style="color:#B5562F;margin:0 4px;">|</span> Smriti Kunj
              </h1>
              <p style="margin:6px 0 0 0;color:#C9962C;font-size:12px;font-weight:600;letter-spacing:1px;text-transform:uppercase;">
                Cognitive Assist & Dignified Care Platform
              </p>
            </td>
          </tr>

          <!-- Main Content -->
          <tr>
            <td style="padding:36px 32px 28px 32px;">
              <h2 style="margin:0 0 12px 0;color:#2E2A24;font-size:18px;font-weight:600;">
                Your Verification Code
              </h2>
              <p style="margin:0 0 24px 0;color:#635C51;font-size:14px;line-height:1.6;">
                Hello, we received a sign-in or registration request for <strong>{email}</strong>. Use the 6-digit security code below to complete your authentication:
              </p>

              <!-- OTP Code Display Card -->
              <table width="100%" border="0" cellspacing="0" cellpadding="0" style="margin:0 0 24px 0;">
                <tr>
                  <td align="center" style="background-color:#FAF6F0;border:2px dashed #B5562F;border-radius:12px;padding:24px 16px;">
                    <div style="font-family:'Courier New',Courier,monospace;font-size:36px;font-weight:bold;letter-spacing:8px;color:#B5562F;text-align:center;">
                      {otp_code}
                    </div>
                    <p style="margin:10px 0 0 0;font-size:12px;color:#635C51;font-weight:500;">
                      ⏱ Expires in <strong>{expire_minutes} minutes</strong>
                    </p>
                  </td>
                </tr>
              </table>

              <p style="margin:0 0 16px 0;color:#635C51;font-size:13px;line-height:1.5;">
                If you did not request this verification code, please ignore this email or reach out to your system administrator immediately. No changes have been made to your account.
              </p>

              <hr style="border:none;border-top:1px solid #EBE0D0;margin:28px 0 20px 0;" />

              <p style="margin:0;color:#9E9689;font-size:12px;line-height:1.4;text-align:center;">
                For security reasons, never share this code or your password with anyone.
              </p>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="background-color:#FAF6F0;padding:16px 32px;text-align:center;border-top:1px solid #EBE0D0;">
              <p style="margin:0;color:#9E9689;font-size:11px;">
                © Smriti Kunj • Empowering Caregivers & Families
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>
"""


async def send_otp_email(email: str, otp: str, expire_minutes: int = 10) -> bool:
    """
    Asynchronously sends an OTP email challenge through Brevo's transactional API.

    Returns:
        bool: True if the email was successfully accepted by Brevo, False otherwise.
    """
    api_key = (settings.BREVO_API_KEY or "").strip()

    # If no valid API key is configured or it is a placeholder, log and return early
    if not api_key or api_key.startswith("<") or api_key == "YOUR_BREVO_API_KEY":
        print(
            f"[Brevo Email] Notice: BREVO_API_KEY is not configured or contains placeholder. "
            f"OTP for {email} will be visible in terminal logs only.",
            flush=True,
        )
        return False

    sender_email = (settings.BREVO_SENDER_EMAIL or "").strip() or "noreply@smritikunj.org"
    sender_name = settings.BREVO_SENDER_NAME or "Smriti Kunj"

    payload = {
        "sender": {
            "name": sender_name,
            "email": sender_email,
        },
        "to": [
            {
                "email": email,
            }
        ],
        "subject": f"Smriti Kunj | Your Verification Code: {otp}",
        "htmlContent": _build_otp_html_content(otp, expire_minutes, email),
    }

    headers = {
        "api-key": api_key,
        "Content-Type": "application/json",
        "Accept": "application/json",
    }

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.post(BREVO_API_URL, json=payload, headers=headers)
            
            if response.status_code in (200, 201, 202):
                data = response.json()
                message_id = data.get("messageId", "N/A")
                print(
                    f"[Brevo Email] Successfully sent OTP email to {email} (Message ID: {message_id})",
                    flush=True,
                )
                return True
            else:
                print(
                    f"[Brevo Email Error] HTTP {response.status_code}: {response.text}",
                    flush=True,
                )
                return False

    except Exception as exc:
        print(f"[Brevo Email Exception] Failed to send email to {email}: {exc}", flush=True)
        return False
