from typing import Any

import httpx


class SupabaseGateway:
    def __init__(
        self,
        base_url: str,
        service_role_key: str,
        client: httpx.AsyncClient,
    ) -> None:
        self._rpc_url = f"{base_url}/rest/v1/rpc"
        self._client = client
        self._headers = {
            "apikey": service_role_key,
            "Authorization": f"Bearer {service_role_key}",
            "Content-Type": "application/json",
        }

    async def refresh_status(self, run_at: str) -> dict[str, Any]:
        return await self._rpc(
            "refresh_legacy_heartbeat_status", {"p_now": run_at}
        )

    async def claim_notices(
        self, run_at: str, limit: int = 50
    ) -> list[dict[str, Any]]:
        result = await self._rpc(
            "claim_legacy_notice_candidates",
            {"p_limit": limit, "p_now": run_at},
        )
        return result if isinstance(result, list) else []

    async def claim_owner_notices(
        self, run_at: str, limit: int = 50
    ) -> list[dict[str, Any]]:
        result = await self._rpc(
            "claim_legacy_owner_notice_candidates",
            {"p_limit": limit, "p_now": run_at},
        )
        return result if isinstance(result, list) else []

    async def complete_owner_notice(
        self,
        window_id: str,
        success: bool,
        error: str | None,
        run_at: str,
    ) -> bool:
        result = await self._rpc(
            "complete_legacy_owner_notice",
            {
                "p_window_id": window_id,
                "p_success": success,
                "p_error": error,
                "p_now": run_at,
            },
        )
        return result is True

    async def complete_notice(
        self,
        window_id: str,
        success: bool,
        error: str | None,
        run_at: str,
    ) -> bool:
        result = await self._rpc(
            "complete_legacy_notice",
            {
                "p_window_id": window_id,
                "p_success": success,
                "p_error": error,
                "p_now": run_at,
            },
        )
        return result is True

    async def _rpc(self, function_name: str, body: dict[str, Any]) -> Any:
        response = await self._client.post(
            f"{self._rpc_url}/{function_name}",
            headers=self._headers,
            json=body,
        )
        response.raise_for_status()
        return response.json()
