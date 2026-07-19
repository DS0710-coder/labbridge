from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from core.config import settings
from core.database import engine, Base
from core.redis import init_redis, close_redis
from auth.router import router as auth_router
from pairing.router import router as pairing_router
from transfer.router import router as transfer_router
from organizer.router import router as organizer_router, files_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: init database tables and redis
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    await init_redis()
    yield
    # Shutdown
    await close_redis()
    await engine.dispose()


app = FastAPI(
    title="LabBridge API",
    description="Backend relay service for LabBridge file transfer and academic organizer.",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router)
app.include_router(pairing_router)
app.include_router(transfer_router)
app.include_router(organizer_router)
app.include_router(files_router)


@app.get("/health")
async def health_check():
    return {"status": "ok", "service": "LabBridge Backend"}
