import secrets

from fastapi import FastAPI, Header, HTTPException
import httpx

from .brevo_gateway import BrevoGateway
from .config import Settings
from .legacy_worker import LegacyInactivityWorker
from .supabase_gateway import SupabaseGateway


app = FastAPI(title="EthernaCare Legacy Inactivity Server", version="1.0.0")


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok", "service": "legacy-inactivity"}


@app.post("/jobs/legacy-inactivity")
async def process_legacy_inactivity(
    x_legacy_cron_secret: str = Header(default=""),
) -> dict:
    settings = Settings.from_environment()
    if not secrets.compare_digest(
        x_legacy_cron_secret, settings.cron_secret
    ):
        raise HTTPException(status_code=401, detail="Unauthorized cron request")

    async with httpx.AsyncClient(timeout=30.0) as client:
        database = SupabaseGateway(
            settings.supabase_url,
            settings.supabase_service_role_key,
            client,
        )
        email = BrevoGateway(
            settings.brevo_api_key,
            settings.notice_from_email,
            settings.notice_from_name,
            client,
        )
        worker = LegacyInactivityWorker(settings, database, email)
        return await worker.run()
