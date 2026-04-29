import os
import pytest

# Must be set before any test file imports app — app.py reads these at module
# load time to configure SQLAlchemy.
os.environ.setdefault("DB_HOST",        "localhost")
os.environ.setdefault("DB_PORT",        "5432")
os.environ.setdefault("DB_NAME",        "todo")
os.environ.setdefault("DB_USER",        "todo")
os.environ.setdefault("DB_PASSWORD",    "testpassword")
os.environ.setdefault("JWT_SECRET_KEY", "test-secret-key-not-for-production")
os.environ.setdefault("APP_ENV",        "test")


@pytest.fixture(scope="session", autouse=True)
def _db():
    """Create tables once for the whole test session, drop them at the end.
    Avoids the PostgreSQL 'drop table while connections are open' hang that
    occurs when drop_all() is called after every single test."""
    from app import app, db
    with app.app_context():
        db.create_all()
        yield db
        db.session.remove()
        db.engine.dispose()
        db.drop_all()


@pytest.fixture
def client(_db):
    from app import app
    app.config["TESTING"] = True
    with app.app_context():
        yield app.test_client()
        # Truncate all rows between tests — much faster than drop/recreate
        # and avoids connection contention with the session-level pool.
        _db.session.remove()
        for table in reversed(_db.metadata.sorted_tables):
            _db.session.execute(table.delete())
        _db.session.commit()


@pytest.fixture
def auth_client(client):
    """A client that is already signed up and carries a valid JWT."""
    res = client.post(
        "/api/auth/signup",
        json={"username": "fixture_user", "email": "fixture@test.com", "password": "pass1234"},
    )
    token = res.get_json()["token"]

    class _AuthClient:
        def __init__(self, raw, tok):
            self._c = raw
            self._h = {"Authorization": f"Bearer {tok}"}

        def get(self, path):
            return self._c.get(path, headers=self._h)

        def post(self, path, **kw):
            return self._c.post(path, headers=self._h, **kw)

        def put(self, path, **kw):
            return self._c.put(path, headers=self._h, **kw)

        def delete(self, path):
            return self._c.delete(path, headers=self._h)

    return _AuthClient(client, token)
