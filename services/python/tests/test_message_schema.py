from sre_platform.queue import make_message


def test_make_message_has_required_fields():
    msg = make_message("event", {"hello": "world"})
    assert msg["type"] == "event"
    assert msg["payload"]["hello"] == "world"
    assert "id" in msg
    assert "created_at_ms" in msg

