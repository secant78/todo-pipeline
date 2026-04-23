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
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--access-logfile", "-", "--error-logfile", "-", "app:app"]
