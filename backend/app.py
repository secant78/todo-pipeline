import os
import time
import logging
from datetime import timedelta
from flask import Flask, request, jsonify
from flask_sqlalchemy import SQLAlchemy
from flask_jwt_extended import (
    JWTManager, create_access_token, jwt_required,
    get_jwt_identity, get_jwt,
)
from flask_cors import CORS
from werkzeug.security import generate_password_hash, check_password_hash

# Structured logging so CloudWatch can parse and filter by level/name
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# ── Configuration ─────────────────────────────────────────────────────────────
# When DB_HOST is set (ECS/production) use PostgreSQL.
# Fall back to SQLite so tests run without a real database.
_db_host = os.environ.get("DB_HOST")
if _db_host:
    _db_user = os.environ.get("DB_USER", "todo")
    _db_pass = os.environ.get("DB_PASSWORD", "")
    _db_port = os.environ.get("DB_PORT", "5432")
    _db_name = os.environ.get("DB_NAME", "todo")
    _DATABASE_URI = f"postgresql://{_db_user}:{_db_pass}@{_db_host}:{_db_port}/{_db_name}"
else:
    _db_path = os.environ.get("DB_PATH", "/tmp/todo.db")
    _DATABASE_URI = f"sqlite:///{_db_path}"

app.config["SQLALCHEMY_DATABASE_URI"] = _DATABASE_URI
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False
app.config["JWT_SECRET_KEY"] = os.environ.get("JWT_SECRET_KEY", "dev-only-change-me")
app.config["JWT_ACCESS_TOKEN_EXPIRES"] = timedelta(hours=24)

db = SQLAlchemy(app)
jwt = JWTManager(app)
CORS(app, supports_credentials=True)

# In-memory blocklist for signed-out tokens.
# In production at scale this would move to Redis; fine for SQLite-scale deployments.
_token_blocklist: set[str] = set()


@jwt.token_in_blocklist_loader
def is_token_revoked(jwt_header, jwt_payload):
    return jwt_payload["jti"] in _token_blocklist


# ── Models ────────────────────────────────────────────────────────────────────
class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    todos = db.relationship("Todo", backref="user", lazy=True, cascade="all, delete-orphan")


class Todo(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(200), nullable=False)
    completed = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, server_default=db.func.now())
    user_id = db.Column(db.Integer, db.ForeignKey("user.id"), nullable=False)


# Create tables on startup.
# With PostgreSQL, the connection may not be immediately available
# (RDS warming up, transient DNS, credential propagation), so retry
# with exponential backoff before giving up and crashing.
with app.app_context():
    if not _db_host:
        os.makedirs(os.path.dirname(_db_path), exist_ok=True)

    _max_attempts = 8
    for _attempt in range(1, _max_attempts + 1):
        try:
            db.create_all()
            logger.info("Database ready (attempt %d/%d, %s)",
                        _attempt, _max_attempts,
                        "postgres" if _db_host else _db_path)
            break
        except Exception as _exc:
            if _attempt == _max_attempts:
                logger.error("Database unavailable after %d attempts: %s",
                             _max_attempts, _exc)
                raise
            _delay = min(2 ** _attempt, 30)   # 2 4 8 16 30 30 30 s
            logger.warning("DB not ready (attempt %d/%d): %s — retrying in %ds",
                           _attempt, _max_attempts, _exc, _delay)
            time.sleep(_delay)


# ── Health check ──────────────────────────────────────────────────────────────
# ALB target group health check hits this endpoint before routing traffic.
@app.route("/api/health")
def health():
    return jsonify({"status": "healthy", "env": os.environ.get("APP_ENV", "unknown")})


# ── Auth routes ───────────────────────────────────────────────────────────────
@app.route("/api/auth/signup", methods=["POST"])
def signup():
    data = request.get_json()
    username = (data.get("username") or "").strip()
    email = (data.get("email") or "").strip()
    password = data.get("password") or ""

    if not username or not email or not password:
        return jsonify({"error": "All fields are required"}), 400
    if User.query.filter_by(username=username).first():
        return jsonify({"error": "Username already taken"}), 409
    if User.query.filter_by(email=email).first():
        return jsonify({"error": "Email already registered"}), 409

    user = User(
        username=username,
        email=email,
        password_hash=generate_password_hash(password),
    )
    db.session.add(user)
    db.session.commit()
    logger.info("New user registered: %s", username)

    token = create_access_token(identity=str(user.id))
    return jsonify({"token": token, "username": user.username}), 201


@app.route("/api/auth/login", methods=["POST"])
def login():
    data = request.get_json()
    username = (data.get("username") or "").strip()
    password = data.get("password") or ""

    user = User.query.filter_by(username=username).first()
    if not user or not check_password_hash(user.password_hash, password):
        logger.warning("Failed login attempt for: %s", username)
        return jsonify({"error": "Invalid credentials"}), 401

    logger.info("User logged in: %s", username)
    token = create_access_token(identity=str(user.id))
    return jsonify({"token": token, "username": user.username})


@app.route("/api/auth/logout", methods=["POST"])
@jwt_required()
def logout():
    # Add the token's unique ID to the blocklist so it can't be reused
    _token_blocklist.add(get_jwt()["jti"])
    logger.info("User logged out: id=%s", get_jwt_identity())
    return jsonify({"message": "Logged out successfully"})


# ── Todo routes ───────────────────────────────────────────────────────────────
@app.route("/api/todos", methods=["GET"])
@jwt_required()
def get_todos():
    user_id = int(get_jwt_identity())
    todos = (
        Todo.query.filter_by(user_id=user_id)
        .order_by(Todo.created_at.desc())
        .all()
    )
    return jsonify(
        [
            {
                "id": t.id,
                "title": t.title,
                "completed": t.completed,
                "created_at": t.created_at.isoformat(),
            }
            for t in todos
        ]
    )


@app.route("/api/todos", methods=["POST"])
@jwt_required()
def create_todo():
    user_id = int(get_jwt_identity())
    data = request.get_json()
    title = (data.get("title") or "").strip()
    if not title:
        return jsonify({"error": "Title is required"}), 400

    todo = Todo(title=title, user_id=user_id)
    db.session.add(todo)
    db.session.commit()
    logger.info("Todo created by user %s: %s", user_id, title)
    return jsonify({"id": todo.id, "title": todo.title, "completed": todo.completed}), 201


@app.route("/api/todos/<int:todo_id>", methods=["PUT"])
@jwt_required()
def update_todo(todo_id):
    user_id = int(get_jwt_identity())
    todo = Todo.query.filter_by(id=todo_id, user_id=user_id).first_or_404()
    data = request.get_json()
    if "title" in data:
        todo.title = (data["title"] or "").strip()
    if "completed" in data:
        todo.completed = bool(data["completed"])
    db.session.commit()
    return jsonify({"id": todo.id, "title": todo.title, "completed": todo.completed})


@app.route("/api/todos/<int:todo_id>", methods=["DELETE"])
@jwt_required()
def delete_todo(todo_id):
    user_id = int(get_jwt_identity())
    todo = Todo.query.filter_by(id=todo_id, user_id=user_id).first_or_404()
    db.session.delete(todo)
    db.session.commit()
    logger.info("Todo %s deleted by user %s", todo_id, user_id)
    return jsonify({"message": "Deleted"})


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    debug = os.environ.get("APP_ENV", "production") == "development"
    app.run(host="0.0.0.0", port=port, debug=debug)
