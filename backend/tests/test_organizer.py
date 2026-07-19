import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_organizer_folders_and_files(client: AsyncClient):
    # Authenticate first
    auth_resp = await client.post(
        "/api/auth/verify-otp",
        json={"phone": "+17778889999", "otp": "123456", "device_name": "Organizer Phone"},
    )
    access_token = auth_resp.json()["access_token"]
    headers = {"Authorization": f"Bearer {access_token}"}

    # 1. List initial folders (empty)
    list_resp = await client.get("/api/folders", headers=headers)
    assert list_resp.status_code == 200
    assert list_resp.json() == []

    # 2. Create Semester folder
    create_sem = await client.post(
        "/api/folders",
        headers=headers,
        json={"name": "Semester 5", "color": "#6C63FF"},
    )
    assert create_sem.status_code == 200
    sem_data = create_sem.json()
    assert sem_data["name"] == "Semester 5"
    sem_id = sem_data["id"]

    # 3. Create Subject folder under Semester
    create_subj = await client.post(
        "/api/folders",
        headers=headers,
        json={"name": "Java Lab", "parent_id": sem_id, "color": "#22C55E"},
    )
    assert create_subj.status_code == 200
    subj_data = create_subj.json()
    assert subj_data["parent_id"] == sem_id
    subj_id = subj_data["id"]

    # 4. Create File item under Subject
    create_file = await client.post(
        "/api/files",
        headers=headers,
        json={
            "name": "experiment1.java",
            "size": 2048,
            "mime_type": "text/x-java-source",
            "folder_id": subj_id,
            "device_name": "Organizer Phone",
            "tags": "lab,java,experiment",
        },
    )
    assert create_file.status_code == 200
    file_data = create_file.json()
    assert file_data["name"] == "experiment1.java"
    assert file_data["folder_id"] == subj_id

    # 5. List files
    files_list = await client.get("/api/files", headers=headers)
    assert files_list.status_code == 200
    assert len(files_list.json()) == 1

    # 6. Update folder (pin it)
    update_resp = await client.patch(
        f"/api/folders/{subj_id}",
        headers=headers,
        json={"pinned": True, "name": "Java Lab (Pinned)"},
    )
    assert update_resp.status_code == 200
    assert update_resp.json()["pinned"] is True
    assert update_resp.json()["name"] == "Java Lab (Pinned)"

    # 7. Delete folder
    del_resp = await client.delete(f"/api/folders/{subj_id}", headers=headers)
    assert del_resp.status_code == 200
