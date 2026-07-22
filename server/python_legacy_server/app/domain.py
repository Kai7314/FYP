from datetime import datetime, timedelta, timezone


INACTIVITY_THRESHOLD_DAYS = 90
ACCESS_WINDOW_DAYS = 7


def no_heartbeat_days(last_heartbeat: datetime, now: datetime) -> int:
    """Return complete consecutive days since the latest check-in."""
    heartbeat = _as_utc(last_heartbeat)
    current = _as_utc(now)
    elapsed = current - heartbeat
    return max(0, int(elapsed.total_seconds() // 86_400))


def threshold_reached(last_heartbeat: datetime, now: datetime) -> bool:
    return no_heartbeat_days(last_heartbeat, now) >= INACTIVITY_THRESHOLD_DAYS


def access_expires_at(notice_sent_at: datetime) -> datetime:
    return _as_utc(notice_sent_at) + timedelta(days=ACCESS_WINDOW_DAYS)


def access_is_open(notice_sent_at: datetime, now: datetime) -> bool:
    current = _as_utc(now)
    started = _as_utc(notice_sent_at)
    return started <= current < access_expires_at(started)


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def iso_z(value: datetime) -> str:
    return _as_utc(value).isoformat().replace("+00:00", "Z")


def _as_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)
