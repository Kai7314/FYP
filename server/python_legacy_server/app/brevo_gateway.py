from dataclasses import dataclass

import httpx


@dataclass(frozen=True)
class EmailResult:
    ok: bool
    error: str | None = None


class BrevoGateway:
    def __init__(
        self,
        api_key: str,
        from_email: str,
        from_name: str,
        client: httpx.AsyncClient,
    ) -> None:
        self._api_key = api_key
        self._from_email = from_email
        self._from_name = from_name
        self._client = client

    @property
    def configured(self) -> bool:
        return bool(self._api_key and self._from_email)

    async def send(
        self,
        to_email: str,
        to_name: str,
        subject: str,
        text_content: str,
        html_content: str,
    ) -> EmailResult:
        try:
            response = await self._client.post(
                "https://api.brevo.com/v3/smtp/email",
                headers={
                    "api-key": self._api_key,
                    "Accept": "application/json",
                    "Content-Type": "application/json",
                },
                json={
                    "sender": {
                        "name": self._from_name,
                        "email": self._from_email,
                    },
                    "to": [{"name": to_name, "email": to_email}],
                    "subject": subject,
                    "textContent": text_content,
                    "htmlContent": html_content,
                    "tags": ["legacy-access-python"],
                },
            )
            if response.is_success:
                return EmailResult(ok=True)
            try:
                message = response.json().get("message")
            except (ValueError, AttributeError):
                message = None
            return EmailResult(
                ok=False,
                error=message or f"Brevo returned HTTP {response.status_code}",
            )
        except httpx.HTTPError as error:
            return EmailResult(ok=False, error=str(error))
