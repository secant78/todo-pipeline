# ── Build stage ───────────────────────────────────────────────────────────────
FROM python:3.12-slim AS builder

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ── Runtime stage ─────────────────────────────────────────────────────────────
FROM python:3.12-slim

# Non-root user for security
RUN addgroup --system app && adduser --system --ingroup app app

WORKDIR /app
COPY --from=builder /install /usr/local
COPY app.py .

# /data is the EFS mount point where SQLite writes its file
RUN mkdir -p /data && chown app:app /data

USER app

EXPOSE 5000

# Gunicorn in production; 2 workers is sufficient for SQLite's write serialization
# --preload: load app code in the master process before forking workers.
# This means db.create_all() (+ its retry loop) runs once in the master;
# workers start only after the DB is confirmed ready, avoiding the 30-second
# worker-timeout that would kill a slow retry loop in a worker process.
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--preload", "--access-logfile", "-", "--error-logfile", "-", "app:app"]
