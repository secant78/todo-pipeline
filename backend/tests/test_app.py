"""
Backend unit tests.  Run with:  pytest backend/tests/ -v
"""


# ── Health ────────────────────────────────────────────────────────────────────

def test_health(client):
    r = client.get("/api/health")
    assert r.status_code == 200
    assert r.get_json()["status"] == "healthy"


# ── Signup ────────────────────────────────────────────────────────────────────

def test_signup_returns_token(client):
    r = client.post(
        "/api/auth/signup",
        json={"username": "alice", "email": "alice@test.com", "password": "secret"},
    )
    assert r.status_code == 201
    body = r.get_json()
    assert "token" in body
    assert body["username"] == "alice"


def test_signup_duplicate_username(client):
    payload = {"username": "bob", "email": "bob@test.com", "password": "secret"}
    client.post("/api/auth/signup", json=payload)
    r = client.post("/api/auth/signup", json={**payload, "email": "bob2@test.com"})
    assert r.status_code == 409


def test_signup_duplicate_email(client):
    client.post(
        "/api/auth/signup",
        json={"username": "carol", "email": "shared@test.com", "password": "secret"},
    )
    r = client.post(
        "/api/auth/signup",
        json={"username": "carol2", "email": "shared@test.com", "password": "secret"},
    )
    assert r.status_code == 409


def test_signup_missing_fields(client):
    r = client.post("/api/auth/signup", json={"username": "dave"})
    assert r.status_code == 400


# ── Login ─────────────────────────────────────────────────────────────────────

def test_login_success(client):
    client.post(
        "/api/auth/signup",
        json={"username": "eve", "email": "eve@test.com", "password": "mypassword"},
    )
    r = client.post("/api/auth/login", json={"username": "eve", "password": "mypassword"})
    assert r.status_code == 200
    assert "token" in r.get_json()


def test_login_wrong_password(client):
    client.post(
        "/api/auth/signup",
        json={"username": "frank", "email": "frank@test.com", "password": "right"},
    )
    r = client.post("/api/auth/login", json={"username": "frank", "password": "wrong"})
    assert r.status_code == 401


def test_login_unknown_user(client):
    r = client.post("/api/auth/login", json={"username": "nobody", "password": "x"})
    assert r.status_code == 401


# ── Logout ────────────────────────────────────────────────────────────────────

def test_logout_invalidates_token(client):
    r = client.post(
        "/api/auth/signup",
        json={"username": "grace", "email": "grace@test.com", "password": "pw"},
    )
    token = r.get_json()["token"]
    headers = {"Authorization": f"Bearer {token}"}

    client.post("/api/auth/logout", headers=headers)

    # Token should now be rejected
    r2 = client.get("/api/todos", headers=headers)
    assert r2.status_code == 401


# ── Todos ─────────────────────────────────────────────────────────────────────

def test_create_todo(auth_client):
    r = auth_client.post("/api/todos", json={"title": "Buy milk"})
    assert r.status_code == 201
    body = r.get_json()
    assert body["title"] == "Buy milk"
    assert body["completed"] is False


def test_create_todo_missing_title(auth_client):
    r = auth_client.post("/api/todos", json={"title": "   "})
    assert r.status_code == 400


def test_get_todos(auth_client):
    auth_client.post("/api/todos", json={"title": "Task A"})
    auth_client.post("/api/todos", json={"title": "Task B"})
    r = auth_client.get("/api/todos")
    assert r.status_code == 200
    titles = [t["title"] for t in r.get_json()]
    assert "Task A" in titles
    assert "Task B" in titles


def test_update_todo(auth_client):
    todo_id = auth_client.post("/api/todos", json={"title": "Old"}).get_json()["id"]
    r = auth_client.put(f"/api/todos/{todo_id}", json={"title": "New", "completed": True})
    assert r.status_code == 200
    body = r.get_json()
    assert body["title"] == "New"
    assert body["completed"] is True


def test_delete_todo(auth_client):
    todo_id = auth_client.post("/api/todos", json={"title": "Doomed"}).get_json()["id"]
    auth_client.delete(f"/api/todos/{todo_id}")
    todos = auth_client.get("/api/todos").get_json()
    assert not any(t["id"] == todo_id for t in todos)


def test_todos_isolated_between_users(client):
    # User A creates a todo
    r_a = client.post(
        "/api/auth/signup",
        json={"username": "user_a", "email": "a@test.com", "password": "pw"},
    )
    token_a = r_a.get_json()["token"]
    client.post(
        "/api/todos",
        json={"title": "User A secret"},
        headers={"Authorization": f"Bearer {token_a}"},
    )

    # User B should not see User A's todos
    r_b = client.post(
        "/api/auth/signup",
        json={"username": "user_b", "email": "b@test.com", "password": "pw"},
    )
    token_b = r_b.get_json()["token"]
    todos_b = client.get(
        "/api/todos", headers={"Authorization": f"Bearer {token_b}"}
    ).get_json()
    assert all(t["title"] != "User A secret" for t in todos_b)


def test_unauthenticated_request_rejected(client):
    r = client.get("/api/todos")
    assert r.status_code == 401
