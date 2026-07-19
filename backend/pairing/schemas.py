from typing import Optional
from pydantic import BaseModel


class PairingCreateResponse(BaseModel):
    session_id: str
    qr_payload: dict
    expires_at: int


class PairingStatusResponse(BaseModel):
    paired: bool
    user_id: Optional[str] = None
    device_name: Optional[str] = None


class PairDeviceRequest(BaseModel):
    pairing_token: str
    device_name: Optional[str] = "Android Device"


class PairDeviceResponse(BaseModel):
    message: str
    session_id: str
    device_name: str
