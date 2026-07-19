import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_auth_flow_and_rate_limit(client: AsyncClient):
    phone = "+1234567890"

    # 1. Send OTP
    response = await client.post("/api/auth/send-otp", json={"phone": phone})
    assert response.status_code == 200
    data = response.json()
    assert data["message"] == "OTP sent successfully via SMS"
    dev_otp = data["dev_otp"]
    assert dev_otp == "123456"

    # 2. Verify OTP
    response = await client.post(
        "/api/auth/verify-otp",
        json={"phone": phone, "otp": dev_otp, "device_name": "Test Phone", "device_id": "test-device-1"},
    )
    assert response.status_code == 200
    token_data = response.json()
    assert "access_token" in token_data
    assert token_data["token_type"] == "bearer"
    access_token = token_data["access_token"]
    refresh_token = token_data["refresh_token"]
    assert refresh_token is not None

    # Check that HttpOnly cookie was set
    assert "refresh_token" in response.cookies

    # 3. Rate Limit Test: Send OTP 3 more times within 10 minutes
    await client.post("/api/auth/send-otp", json={"phone": phone})
    await client.post("/api/auth/send-otp", json={"phone": phone})
    # 4th request (or 3rd after first verify depending on count) should trigger 429
    # Note: verify_otp does not delete the ratelimit key, so we have made:
    # Req 1 (top of test), Req 2, Req 3 -> total 3 requests. Next request should fail!
    rl_resp = await client.post("/api/auth/send-otp", json={"phone": phone})
    assert rl_resp.status_code == 429
    assert "Rate limit exceeded" in rl_resp.json()["detail"]

    # 4. List Devices with access token
    headers = {"Authorization": f"Bearer {access_token}"}
    dev_resp = await client.get("/api/auth/devices", headers=headers)
    assert dev_resp.status_code == 200
    devices = dev_resp.json()
    assert len(devices) == 1
    assert devices[0]["device_name"] == "Test Phone"
    assert devices[0]["device_id"] == "test-device-1"

    # 5. Refresh token endpoint
    ref_resp = await client.post("/api/auth/refresh", cookies={"refresh_token": refresh_token})
    assert ref_resp.status_code == 200
    assert "access_token" in ref_resp.json()

    # 6. Logout device
    logout_resp = await client.post(
        "/api/auth/logout",
        headers=headers,
        json={"device_id": "test-device-1"},
    )
    assert logout_resp.status_code == 200

    # After logout, refresh should fail
    ref_fail = await client.post("/api/auth/refresh", cookies={"refresh_token": refresh_token})
    assert ref_fail.status_code == 401
