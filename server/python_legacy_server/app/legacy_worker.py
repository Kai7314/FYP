import asyncio
from datetime import datetime
from html import escape
from typing import Any
from zoneinfo import ZoneInfo

from .brevo_gateway import BrevoGateway, EmailResult
from .config import Settings
from .domain import iso_z, utc_now
from .supabase_gateway import SupabaseGateway


MALAYSIA_TIME = ZoneInfo("Asia/Kuala_Lumpur")


class LegacyInactivityWorker:
    def __init__(
        self,
        settings: Settings,
        database: SupabaseGateway,
        email: BrevoGateway,
    ) -> None:
        self._settings = settings
        self._database = database
        self._email = email

    async def run(self) -> dict[str, Any]:
        run_at = iso_z(utc_now())
        refresh = await self._database.refresh_status(run_at)

        if not self._email.configured:
            return {
                "ok": False,
                "processedAt": run_at,
                "refresh": refresh,
                "error": (
                    "Heartbeat status was refreshed, but Brevo email "
                    "configuration is missing."
                ),
            }

        candidates = await self._database.claim_notices(run_at)
        sent = 0
        failed = 0
        errors: list[str] = []

        for candidate in candidates:
            delivery = await self._send_notice(candidate)
            completed = await self._complete_with_retry(candidate, delivery)
            if delivery.ok and completed:
                sent += 1
            else:
                failed += 1
                if delivery.error:
                    errors.append(delivery.error)
                elif not completed:
                    errors.append(
                        f"Window {candidate['window_id']} was not finalized."
                    )

        return {
            "ok": failed == 0,
            "processedAt": run_at,
            "refresh": refresh,
            "claimed": len(candidates),
            "sent": sent,
            "failed": failed,
            "errors": errors[:10],
        }

    async def _send_notice(self, candidate: dict[str, Any]) -> EmailResult:
        owner_name = str(candidate.get("owner_name") or "EthernaCare user")
        contact_name = str(
            candidate.get("contact_name") or "Primary trusted contact"
        )
        heartbeat = _malaysia_datetime(candidate["heartbeat_at"])
        expires = _malaysia_datetime(candidate["proposed_expires_at"])
        days = int(candidate["no_heartbeat_days"])
        owner_uid = str(candidate["owner_user_id"])
        instructions = (
            f"Open {self._settings.legacy_check_url} and choose Legacy Check."
            if self._settings.legacy_check_url
            else "Open EthernaCare and choose Legacy Check from the sign-in page."
        )
        text_content = "\n".join(
            [
                f"Hello {contact_name},",
                "",
                f"{owner_name} has had no EthernaCare check-in for {days} days.",
                f"Their last recorded heartbeat was {heartbeat}.",
                "",
                "Legacy Checking is available for seven days.",
                f"Access closes on {expires}.",
                instructions,
                f"Legacy UID: {owner_uid}",
                "Use the verified primary phone and complete SMS verification.",
            ]
        )
        html_content = (
            "<h1>Legacy Checking is available</h1>"
            f"<p>Hello {escape(contact_name)},</p>"
            f"<p><strong>{escape(owner_name)}</strong> has had no check-in "
            f"for <strong>{days} days</strong>.</p>"
            f"<p>Last heartbeat: {escape(heartbeat)}</p>"
            f"<p>Access closes: <strong>{escape(expires)}</strong></p>"
            f"<p>Legacy UID: <code>{escape(owner_uid)}</code></p>"
            f"<p>{escape(instructions)}</p>"
            "<p>SMS verification is still required.</p>"
        )
        return await self._email.send(
            to_email=str(candidate["contact_email"]),
            to_name=contact_name,
            subject=f"EthernaCare Legacy Checking available for {owner_name}",
            text_content=text_content,
            html_content=html_content,
        )

    async def _complete_with_retry(
        self, candidate: dict[str, Any], delivery: EmailResult
    ) -> bool:
        for attempt in range(3):
            try:
                completed = await self._database.complete_notice(
                    window_id=str(candidate["window_id"]),
                    success=delivery.ok,
                    error=delivery.error,
                    run_at=iso_z(utc_now()),
                )
                return completed
            except Exception:
                if attempt == 2:
                    return False
                await asyncio.sleep(0.25 * (attempt + 1))
        return False


def _malaysia_datetime(value: str) -> str:
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    return parsed.astimezone(MALAYSIA_TIME).strftime("%d %B %Y, %I:%M %p")
