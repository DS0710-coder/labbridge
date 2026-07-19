import asyncio
import pytest
import pytest_asyncio
from httpx import AsyncClient, ASGITransport
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from fakeredis.aioredis import FakeRedis

from main import app
from core.database import Base, get_db
from core.redis import get_redis

# In-memory SQLite engine for unit tests
test_engine = create_async_engine("sqlite+aiosqlite:///:memory:", echo=False, future=True)
test_async_session = async_sessionmaker(test_engine, class_=AsyncSession, expire_on_commit=False)
fake_redis_client = FakeRedis(decode_responses=True)


@pytest.fixture(scope="session")
def event_loop():
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()


@pytest_asyncio.fixture(autouse=True)
async def init_test_db_and_redis():
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    await fake_redis_client.flushall()
    yield
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
    await fake_redis_client.flushall()


async def override_get_db():
    async with test_async_session() as session:
        yield session


async def override_get_redis():
    yield fake_redis_client


app.dependency_overrides[get_db] = override_get_db
app.dependency_overrides[get_redis] = override_get_redis


@pytest_asyncio.fixture
async def client():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://testserver") as ac:
        yield ac


@pytest_asyncio.fixture
async def db_session():
    async with test_async_session() as session:
        yield session


@pytest_asyncio.fixture
async def redis():
    yield fake_redis_client
