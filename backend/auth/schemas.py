from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, Field, ConfigDict


class SendOTPRequest(BaseModel):
    phone: str = Field(..., description="Phone number including country code or local format")


class SendOTPResponse(BaseModel):
    message: str
    dev_otp: Optional[str] = None


class VerifyOTPRequest(BaseModel):
    phone: str
    otp: str
    device_name: Optional[str] = "Android Device"
    device_id: Optional[str] = "default-device-id"


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int = 900
    user_id: str
    phone: str
    refresh_token: Optional[str] = None  # Returned in body as well as cookie for mobile app convenience


class LogoutRequest(BaseModel):
    device_id: str


class DeviceInfoResponse(BaseModel):
    id: str
    device_name: Optional[str]
    device_id: Optional[str]
    created_at: datetime
    expires_at: datetime
    revoked: bool

    model_config = ConfigDict(from_attributes=True)
