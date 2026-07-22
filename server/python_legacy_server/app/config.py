from dataclasses import dataclass
import os


def _required(name: str) -> str:
    value = os.getenv(name, "").strip()
    if not value:
        raise RuntimeError(f"Missing required environment variable: {name}")
    return value


@dataclass(frozen=True)
class Settings:
    supabase_url: str
    supabase_service_role_key: str
    cron_secret: str
    brevo_api_key: str
    notice_from_email: str
    notice_from_name: str
    legacy_check_url: str

    @classmethod
    def from_environment(cls) -> "Settings":
        return cls(
            supabase_url=_required("SUPABASE_URL").rstrip("/"),
            supabase_service_role_key=_required("SUPABASE_SERVICE_ROLE_KEY"),
            cron_secret=_required("LEGACY_CRON_SECRET"),
            brevo_api_key=os.getenv("BREVO_API_KEY", "").strip(),
            notice_from_email=os.getenv(
                "LEGACY_NOTICE_FROM_EMAIL", ""
            ).strip(),
            notice_from_name=os.getenv(
                "LEGACY_NOTICE_FROM_NAME", "EthernaCare"
            ).strip(),
            legacy_check_url=os.getenv("LEGACY_CHECK_URL", "").strip(),
        )
