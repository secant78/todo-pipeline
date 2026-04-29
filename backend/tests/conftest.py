import os
import pytest

# Tests run against a real PostgreSQL instance (provided by the GitHub Actions
# service container, or a local Postgres when developing).
# Required env vars: DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD
# These must be set before any test file imports app, because app.py reads them
# at module load time to configure SQLAlchemy.
os.environ.setdefault("DB_HOST",     "localhost")
os.environ.setdefault("DB_PORT",     "5432")
os.environ.setdefault("DB_NAME",     "todo")
os.environ.setdefault("DB_USER",     "todo")
os.environ.setdefault("DB_PASSWORD", "testpassword")
os.environ.setdefault("JWT_SECRET_KEY", "test-secret-key-not-for-production")
os.environ.setdefault("APP_ENV", "test")


@pytest.fixture
def client():
    from app import app, db

    app.config["TESTING"] = True
    with app.app_context():
        db.create_all()
        yield app.test_client()
        db.drop_all()


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
