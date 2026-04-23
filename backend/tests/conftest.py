import os
import tempfile
import pytest

# Set DB_PATH BEFORE any test file imports app, because app.py reads the env
# var at module load time to configure SQLAlchemy.
_tmp = tempfile.mkdtemp()
os.environ["DB_PATH"] = os.path.join(_tmp, "test.db")
os.environ["JWT_SECRET_KEY"] = "test-secret-key-not-for-production"
os.environ["APP_ENV"] = "test"


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
