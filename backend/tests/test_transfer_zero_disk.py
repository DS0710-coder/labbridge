import os
import glob
import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_transfer_relay_and_zero_disk(client: AsyncClient):
    # Setup: Create pairing session and pair a device
    create_resp = await client.post("/api/pairing/create")
    session_id = create_resp.json()["session_id"]
    pairing_token = create_resp.json()["qr_payload"]["pairing_token"]

    auth_resp = await client.post(
        "/api/auth/verify-otp",
        json={"phone": "+15554443333", "otp": "123456", "device_name": "Test Phone", "device_id": "dev-transfer"},
    )
    headers = {"Authorization": f"Bearer {auth_resp.json()['access_token']}"}
    await client.post(
        f"/api/pairing/{session_id}/pair",
        headers=headers,
        json={"pairing_token": pairing_token, "device_name": "Test Phone"},
    )

    # 1. Init Transfer
    init_payload = {
        "session_id": session_id,
        "filename": "experiment3_output.pdf",
        "size": 102400,  # 100 KB
        "total_chunks": 2,
        "mime_type": "application/pdf",
    }
    init_resp = await client.post("/api/transfer/init", json=init_payload)
    assert init_resp.status_code == 200
    transfer_id = init_resp.json()["transfer_id"]
    assert transfer_id is not None

    # Snapshot of tmp and current directory files before chunk upload
    files_before = set(glob.glob("/tmp/labbridge_*") + glob.glob("./*chunk*") + glob.glob("./*.pdf"))

    # 2. Upload Chunk 0 (Base64 encrypted string)
    dummy_encrypted_b64 = "U2FsdGVkX1+v1a2b3c4d5e6f7g8h9i0j1k2l3m4n5o6p7q8r9s0t"
    chunk_resp = await client.post(
        f"/api/transfer/{transfer_id}/chunk",
        json={"chunk_index": 0, "encrypted_data": dummy_encrypted_b64},
    )
    assert chunk_resp.status_code == 200
    assert chunk_resp.json()["message"] == "Chunk relayed"
    assert chunk_resp.json()["chunk_index"] == 0

    # Verify zero disk writes: check that NO new files were created in /tmp or local workspace
    files_after = set(glob.glob("/tmp/labbridge_*") + glob.glob("./*chunk*") + glob.glob("./*.pdf"))
    assert files_after == files_before, "Server must not write any temporary chunk files to disk!"

    # 3. Check transfer status after chunk 0 relay (before ACK)
    status_resp = await client.get(f"/api/transfer/{transfer_id}/status")
    assert status_resp.status_code == 200
    assert status_resp.json()["received_chunks"] == []
    assert status_resp.json()["status"] == "in_progress"

    # 4. ACK Chunk 0
    ack_resp0 = await client.post(f"/api/transfer/{transfer_id}/ack?chunk_index=0")
    assert ack_resp0.status_code == 200
    assert ack_resp0.json()["received_chunks_count"] == 1
    assert ack_resp0.json()["status"] == "in_progress"

    # 5. Upload Chunk 1
    await client.post(
        f"/api/transfer/{transfer_id}/chunk",
        json={"chunk_index": 1, "encrypted_data": dummy_encrypted_b64},
    )

    # 6. ACK Chunk 1 -> should mark transfer as completed
    ack_resp1 = await client.post(f"/api/transfer/{transfer_id}/ack?chunk_index=1")
    assert ack_resp1.status_code == 200
    assert ack_resp1.json()["received_chunks_count"] == 2
    assert ack_resp1.json()["status"] == "completed"

    # Verify final status
    status_final = await client.get(f"/api/transfer/{transfer_id}/status")
    assert status_final.json()["status"] == "completed"
