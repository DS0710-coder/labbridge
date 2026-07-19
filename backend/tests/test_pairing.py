import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_pairing_lifecycle_and_single_use(client: AsyncClient):
    # 1. PC creates pairing session
    create_resp = await client.post("/api/pairing/create")
    assert create_resp.status_code == 200
    create_data = create_resp.json()
    session_id = create_data["session_id"]
    qr_payload = create_data["qr_payload"]
    pairing_token = qr_payload["pairing_token"]
    assert qr_payload["session_id"] == session_id

    # 2. Check status initially (unpaired)
    status_resp = await client.get(f"/api/pairing/{session_id}")
    assert status_resp.status_code == 200
    assert status_resp.json()["paired"] is False

    # 3. Authenticate a mobile user
    auth_resp = await client.post(
        "/api/auth/verify-otp",
        json={"phone": "+19998887777", "otp": "123456", "device_name": "My Android Phone", "device_id": "dev-1"},
    )
    access_token = auth_resp.json()["access_token"]
    headers = {"Authorization": f"Bearer {access_token}"}

    # 4. Mobile app scans QR and sends pair request
    pair_resp = await client.post(
        f"/api/pairing/{session_id}/pair",
        headers=headers,
        json={"pairing_token": pairing_token, "device_name": "My Android Phone"},
    )
    assert pair_resp.status_code == 200
    assert pair_resp.json()["message"] == "Paired successfully"

    # 5. Check status now (paired)
    status_resp2 = await client.get(f"/api/pairing/{session_id}")
    assert status_resp2.status_code == 200
    status_data2 = status_resp2.json()
    assert status_data2["paired"] is True
    assert status_data2["device_name"] == "My Android Phone"

    # 6. Single-use token check: attempting to pair again with the same token must fail!
    pair_fail = await client.post(
        f"/api/pairing/{session_id}/pair",
        headers=headers,
        json={"pairing_token": pairing_token, "device_name": "Attacker Phone"},
    )
    assert pair_fail.status_code == 400
    assert "already paired" in pair_fail.json()["detail"].lower() or "used" in pair_fail.json()["detail"].lower()

    # 7. Disconnect / delete session
    del_resp = await client.delete(f"/api/pairing/{session_id}")
    assert del_resp.status_code == 200

    status_fail = await client.get(f"/api/pairing/{session_id}")
    assert status_fail.status_code == 404
