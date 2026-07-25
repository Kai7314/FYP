from datetime import datetime, timedelta, timezone
import unittest

from app.domain import (
    access_expires_at,
    access_is_open,
    no_heartbeat_days,
    owner_cancel_deadline,
    owner_grace_elapsed,
    threshold_reached,
)


class LegacyDomainTests(unittest.TestCase):
    def setUp(self) -> None:
        self.now = datetime(2026, 7, 22, 4, 0, tzinfo=timezone.utc)

    def test_day_89_is_still_waiting(self) -> None:
        heartbeat = self.now - timedelta(days=89)
        self.assertEqual(no_heartbeat_days(heartbeat, self.now), 89)
        self.assertFalse(threshold_reached(heartbeat, self.now))

    def test_day_90_reaches_threshold(self) -> None:
        heartbeat = self.now - timedelta(days=90)
        self.assertTrue(threshold_reached(heartbeat, self.now))

    def test_access_is_open_for_exactly_seven_days(self) -> None:
        notice_sent = self.now
        self.assertEqual(access_expires_at(notice_sent), self.now + timedelta(days=7))
        self.assertTrue(access_is_open(notice_sent, self.now + timedelta(days=6)))
        self.assertFalse(access_is_open(notice_sent, self.now + timedelta(days=7)))

    def test_owner_has_a_full_day_to_cancel(self) -> None:
        notice_sent = self.now
        self.assertEqual(
            owner_cancel_deadline(notice_sent),
            self.now + timedelta(hours=24),
        )
        self.assertFalse(
            owner_grace_elapsed(notice_sent, self.now + timedelta(hours=23))
        )
        self.assertTrue(
            owner_grace_elapsed(notice_sent, self.now + timedelta(hours=24))
        )

    def test_future_heartbeat_never_creates_negative_days(self) -> None:
        heartbeat = self.now + timedelta(hours=1)
        self.assertEqual(no_heartbeat_days(heartbeat, self.now), 0)


if __name__ == "__main__":
    unittest.main()
