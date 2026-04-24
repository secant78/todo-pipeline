# todo-pipeline

A production-grade todo application with a multi-environment CI/CD pipeline on AWS. The project serves as a reference implementation for deploying containerized workloads to ECS Fargate with blue-green deployments, security scanning at every stage, and full infrastructure-as-code.

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Backend](#backend)
- [Frontend](#frontend)
- [Infrastructure](#infrastructure)
- [CI/CD Pipeline](#cicd-pipeline)
- [Security](#security)
- [Local Development](#local-development)
- [Environment Variables & Secrets](#environment-variables--secrets)

---

## Architecture Overview

```
Internet
    │
    ▼
Application Load Balancer (public subnets, port 80 prod / port 8080 test)
    │                  │
    ▼                  ▼
Frontend (Nginx)   Backend (Flask / Gunicorn)
ECS Fargate        ECS Fargate
(private subnet)   (private subnet)
                       │
                       ▼
                  SQLite on EFS
                  (encrypted, multi-AZ)
                       │
                       ▼
               AWS Secrets Manager
               (JWT secret, 30-day rotation)
```

Three environments — `dev`, `staging`, `prod` — each run in isolated VPCs on separate ECS clusters. All environments use the same Terraform module stack. Staging and prod use Terragrunt for per-environment backend configuration. Prod adds a manual approval gate and sequential blue-green deployments (backend first, then frontend) to minimize the window where old frontend code talks to a new API.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Backend | Python 3.12, Flask 3.1, SQLAlchemy, Flask-JWT-Extended, Gunicorn |
| Frontend | React 18, React Scripts, Nginx |
| Database | SQLite (EFS-mounted, shared across tasks) |
| Container Registry | Amazon ECR (with image scanning and lifecycle policies) |
| Orchestration | Amazon ECS Fargate |
| Load Balancing | AWS Application Load Balancer |
| Deployments | AWS CodeDeploy (blue-green, traffic-shifted) |
| Infrastructure | Terraform 1.8 + Terragrunt (staging/prod) |
| CI/CD | GitHub Actions |
| Secrets | AWS Secrets Manager + Lambda auto-rotation |
| Image Signing | Sigstore Cosign (keyless, OIDC-based) |
| Security Scanning | Snyk, ESLint security plugin, tfsec, Checkov, SonarQube |

---

## Project Structure

```
todo-pipeline/
├── .github/
│   └── workflows/
│       ├── pr.yml               # PR validation (parallel: backend, frontend, IaC)
│       ├── dev.yml              # Dev branch: validate → build → deploy
│       ├── staging.yml          # Staging branch: validate → build → blue-green deploy
│       ├── prod.yml             # Main branch: validate → approve → build → blue-green deploy
│       └── drift-detection.yml  # Weekly Terraform drift check (per environment)
├── .tflint.hcl                  # Terraform linter rules + AWS plugin config
├── .checkov.yaml                # Checkov policy suppressions with justifications
├── sonar-project.properties     # SonarQube project config
├── docker-compose.yml           # Local development environment
├── .env.example                 # Environment variable reference
├── backend/
│   ├── app.py                   # Flask application: routes, models, auth
│   ├── Dockerfile               # Multi-stage Python 3.12 slim image
│   ├── requirements.txt         # Production dependencies
│   ├── requirements-dev.txt     # Test + security tool dependencies
│   └── tests/
│       ├── conftest.py          # Pytest fixtures (in-memory SQLite, test client)
│       └── test_app.py          # Unit tests (80%+ coverage enforced)
├── frontend/
│   ├── src/
│   │   ├── App.js               # Root component, auth state management
│   │   ├── api.js               # HTTP client with JWT injection
│   │   ├── setupTests.js        # Jest-dom matcher registration
│   │   ├── components/
│   │   │   ├── Auth.js          # Login / signup form
│   │   │   └── TodoList.js      # Todo CRUD UI
│   │   └── index.js
│   ├── Dockerfile               # Multi-stage Node 20 build + Nginx runtime
│   ├── nginx.conf               # SPA fallback routing + gzip compression
│   ├── .eslintrc.json           # ESLint with security plugin rules
│   └── package.json
└── terraform/
    ├── global/                  # ECR repositories (deployed once, account-wide)
    ├── stack/                   # Main stack: wires together all modules
    ├── modules/
    │   ├── iam/                 # ECS roles, GitHub OIDC, Lambda rotator role
    │   ├── networking/          # VPC, subnets, ALB, security groups, target groups
    │   ├── ecs/                 # Fargate cluster, task definitions, services
    │   ├── efs/                 # Encrypted EFS + mount targets + access point
    │   ├── secrets/             # Secrets Manager + Lambda auto-rotator
    │   ├── monitoring/          # CloudWatch logs, alarms, SNS, dashboards
    │   └── codedeploy/          # Blue-green deployment groups and apps
    └── environments/
        ├── dev/                 # Terragrunt config (workspace-based)
        ├── staging/             # Terragrunt config
        └── prod/                # Terragrunt config
```

---

## Backend

### API Endpoints

| Method | Path | Auth | Description |
|---|---|---|---|
| `GET` | `/api/health` | None | ALB health check |
| `POST` | `/api/auth/signup` | None | Create account, returns JWT |
| `POST` | `/api/auth/login` | None | Authenticate, returns JWT |
| `POST` | `/api/auth/logout` | Bearer | Revoke token |
| `GET` | `/api/todos` | Bearer | List authenticated user's todos |
| `POST` | `/api/todos` | Bearer | Create todo |
| `PUT` | `/api/todos/<id>` | Bearer | Update todo (title or completed) |
| `DELETE` | `/api/todos/<id>` | Bearer | Delete todo |

### Authentication

JWT tokens are issued on signup and login with a 24-hour expiration. Each token carries a unique `jti` (JWT ID). On logout, the `jti` is added to an in-memory blocklist so the token is rejected on subsequent requests even before it expires.

The JWT secret is managed by AWS Secrets Manager and rotated automatically every 30 days by a Lambda function. ECS tasks pick up the new secret on the next deployment; in-flight tokens signed with the old secret remain valid until they expire.

### Data Model

```
User
  id          INTEGER PRIMARY KEY
  username    TEXT UNIQUE NOT NULL
  email       TEXT UNIQUE NOT NULL
  password_hash TEXT NOT NULL

Todo
  id          INTEGER PRIMARY KEY
  title       TEXT NOT NULL
  completed   BOOLEAN DEFAULT false
  created_at  DATETIME DEFAULT CURRENT_TIMESTAMP
  user_id     INTEGER REFERENCES User(id) ON DELETE CASCADE
```

SQLite is stored at `/data/todo.db` on an EFS volume. This makes the database persist across task replacements and deployments, and lets multiple tasks in the same service share a single file. EFS mount targets are deployed in each private subnet for multi-AZ access.

### Container

The backend Dockerfile uses a two-stage build:

1. **Builder** — installs production dependencies into `/install` to keep the layer isolated
2. **Runtime** — copies only the installed packages and application code; runs as a non-root `app` user; starts Gunicorn with 2 workers on port 5000

All logs go to stdout/stderr and are forwarded to CloudWatch by the ECS log driver.

---

## Frontend

### Components

**`App.js`** — Root component. Reads `token` and `username` from `localStorage` on mount to restore auth state across page refreshes. Renders `<Auth>` when logged out or `<TodoList>` when logged in. Handles logout by calling `api.logout()`, clearing localStorage, and resetting state.

**`components/Auth.js`** — Toggleable login/signup form. Signup collects username, email, and password; login collects username and password. Submits to the backend and calls the `onAuth` callback on success, which stores the returned JWT and username in localStorage.

**`components/TodoList.js`** — Loads todos on mount via `api.getTodos()`. Renders an add form and a list of todos with checkboxes and delete buttons. Updates are applied optimistically to local state — the UI responds immediately; the server call happens in the background. Todos are displayed newest-first (matching the server's DESC order by `created_at`).

**`api.js`** — Thin fetch wrapper. Reads `REACT_APP_API_URL` as the base URL (default: `/api`, injected at build time as a Docker build arg). All protected calls read the token from localStorage and attach it as `Authorization: Bearer <token>`.

### Container

The frontend Dockerfile uses a two-stage build:

1. **Builder** — Node 20 Alpine; runs `npm ci` then `react-scripts build`; accepts `REACT_APP_API_URL` as a build arg
2. **Runtime** — Nginx Alpine; serves the compiled static files from `/usr/share/nginx/html`

The Nginx config handles React Router's client-side routing by falling back all paths to `index.html`. Gzip compression is enabled for JS, CSS, and HTML. The `REACT_APP_API_URL=/api` build arg means all API calls are made relative to the same origin, so the ALB can route `/api/*` to the backend service and everything else to the frontend.

---

## Infrastructure

### Networking

Each environment has its own VPC with four subnets across two availability zones:

- **Public subnets** — host the ALB and NAT gateways. Internet-reachable via an Internet Gateway.
- **Private subnets** — host ECS tasks and EFS mount targets. Outbound internet access (for ECR pulls, Secrets Manager, CloudWatch) goes through a dedicated NAT gateway in the same AZ, so a NAT failure in one AZ does not affect the other.

The ALB has two sets of listeners:
- **Port 80** (production) — routes `/api/*` to the backend blue target group, everything else to the frontend blue target group.
- **Port 8080** (test) — same routing but to the green target groups. Used by CodeDeploy during a blue-green deployment to run smoke tests against the new version before shifting production traffic.

### ECS

Both services use the `CODE_DEPLOY` deployment controller. This means Terraform provisions the initial service but CodeDeploy takes over task definition and load balancer management from that point. Both service resources have `lifecycle { ignore_changes = [task_definition, load_balancer] }` to prevent Terraform from fighting CodeDeploy.

Per-environment task sizing:

| Environment | CPU | Memory | Desired Count |
|---|---|---|---|
| dev | 512 | 1024 MB | 1 |
| staging | 1024 | 2048 MB | 2 |
| prod | 2048 | 4096 MB | 3 |

### Secrets

The JWT secret is stored in AWS Secrets Manager under `todo-{env}/jwt-secret-key`. A Lambda function (packaged inline in Terraform) rotates the secret every 30 days using Secrets Manager's rotation schedule. The ECS execution role has permission to read the secret, which is injected into the task as an environment variable.

### Monitoring

CloudWatch log groups are created for each service:
- 14-day retention for dev and staging
- 90-day retention for prod

CloudWatch alarms trigger on:
- Backend CPU > 80%
- Backend memory > 80%
- ALB 5xx error rate > 10 in 1 minute
- Unhealthy backend host count > 0

These alarms are wired to CodeDeploy's rollback configuration. If an alarm fires during a deployment, CodeDeploy automatically stops traffic shifting and reverts to the previous task definition.

### Blue-Green Deployments

CodeDeploy manages traffic shifting between the blue (current) and green (new) target groups:

| Environment | Deployment Strategy |
|---|---|
| dev | `ECSAllAtOnce` — immediate cutover (fast iteration) |
| staging | `ECSCanary10Percent5Minutes` — 10% traffic to green for 5 min, then 100% |
| prod | `ECSLinear10PercentEvery1Minute` — 10% per minute over 10 minutes |

After a successful deployment the blue (old) tasks are terminated 5 minutes later. On failure (either from a failed health check or a triggering CloudWatch alarm), CodeDeploy automatically restores the previous task definition and shifts traffic back.

The CI workflows add an extra rollback layer: if the ECS wait or smoke test step fails after a completed CodeDeploy deployment, the workflow calls `aws deploy create-deployment` with the task definition ARNs that were saved at the start of the deploy job, forcing a revert.

### ECR Lifecycle Policies

To control storage costs, ECR applies the following policies to each repository:
- Keep the 10 most recent images tagged with `dev-*`, `staging-*`, or `prod-*` respectively
- Expire untagged images after 1 day

---

## CI/CD Pipeline

### Pull Request (`pr.yml`)

Runs on every PR targeting `dev`, `staging`, or `main`. Three jobs run in parallel:

1. **Backend** — pytest with 80%+ coverage requirement, Snyk Python scan, SonarQube analysis
2. **Frontend** — npm test, Snyk npm scan, ESLint security lint, SonarQube analysis
3. **IaC** — tflint (error-level, no soft_fail), Terraform validate, tfsec, Checkov with `.checkov.yaml` suppressions

Checkov runs without `soft_fail` on PRs — it is a hard gate. This ensures policy violations are caught before code reaches any environment.

### Development (`dev.yml`)

Triggers on push to `dev`. A new push cancels any in-progress run.

```
validate → build → deploy → notify
```

- **Validate** — same checks as PR (pytest, Snyk, npm test, ESLint, tflint, Terraform validate, tfsec, Checkov)
- **Build** — authenticates to AWS via OIDC, pushes image tagged `dev-<sha>` to ECR, signs with Cosign
- **Deploy** — Terraform plan/apply (workspace: dev), ECS force-new-deployment (no blue-green for speed), waits for stable, health checks `/api/health`; rolls back on failure
- **Notify** — sends deployment result email via SES

### Staging (`staging.yml`)

Triggers on push to `staging`. Same structure as dev with these differences:

- tflint runs at error level (no soft_fail)
- Deployment uses Terragrunt and CodeDeploy blue-green (canary strategy)
- Smoke tests run a full API round-trip: signup a test user, create a todo, verify the response
- Rollback stops in-progress CodeDeploy deployments (triggering built-in rollback) and creates a new deployment pointing to the previously saved task definitions if the deployment already completed

### Production (`prod.yml`)

Triggers on push to `main`. Never cancels an in-progress run.

```
validate → approve → build → deploy → notify
```

- **Validate** — same as staging
- **Approve** — pauses for a required reviewer to approve in the GitHub Actions UI (enforced via the `prod` GitHub Environment). 60-minute timeout.
- **Build** — pushes images tagged `prod-<sha>` AND `latest`; verifies Cosign signature on the staging image (same SHA) before signing the prod tag — confirming the image was not tampered with between staging and prod
- **Deploy**:
  1. Terragrunt init/plan/apply
  2. CodeDeploy backend deployment — linear traffic shifting; wait for success
  3. CodeDeploy frontend deployment — starts only after backend is healthy (reduces the window where old frontend talks to new API)
  4. Production smoke tests — health check, then full signup + create todo round-trip
  5. Rollback on failure — stops CodeDeploy deployments and creates rollback deployments with prior task definitions
- **Notify** — sends production deployment result email via SES

### Drift Detection (`drift-detection.yml`)

Runs every Monday at 06:00 UTC and can be triggered manually via `workflow_dispatch`. Runs a Terraform plan with `-detailed-exitcode` against each workspace in parallel. If exit code 2 (changes detected), sends an email via SES alerting that infrastructure has drifted from the Terraform state. Plan output and the binary plan file are saved as 7-day artifacts.

### Auth Model

All workflows authenticate to AWS using OIDC — no long-lived access keys are stored. Each environment has a dedicated IAM role (`todo-{env}-github-actions`) with a trust policy scoped to the specific branch (`refs/heads/dev`, `refs/heads/staging`, `refs/heads/main`), so a workflow for one environment cannot assume another environment's role.

---

## Security

### Supply Chain

- **Snyk** scans `backend/requirements.txt` and `frontend/package.json` at every PR and deployment, blocking on high-severity CVEs. The Python scan runs on the host runner (not Docker) to avoid package isolation issues.
- **Cosign** signs every image with keyless signing — the signing identity is the GitHub Actions OIDC token, recorded in the Rekor public transparency log. No private signing keys are stored or rotated.
- **ECR scan-on-push** runs an image vulnerability scan on every pushed image.
- **Production build verification** — before signing the `prod-<sha>` image, the workflow verifies the Cosign signature on the `staging-<sha>` image with the same commit SHA, confirming the image content is identical between environments.

### SAST

- **ESLint** with `eslint-plugin-security` — `no-eval` and `no-implied-eval` are hard errors; `detect-object-injection` and `detect-non-literal-regexp` are warnings. All warnings fail the lint step (`--max-warnings 0`).
- **SonarQube** runs on PRs against both Python and JavaScript source, gated by a quality gate.
- **bandit** and **pip-audit** are included in `requirements-dev.txt` for local developer use.

### IaC

- **tflint** with the AWS plugin enforces required version constraints, provider pins, naming conventions, and flags unused declarations. Runs at error level (`--minimum-failure-severity=error`).
- **tfsec** scans for compliance issues. Runs with `soft_fail: true` in deployment workflows (informational) but is a hard gate on PRs.
- **Checkov** enforces policy rules. Suppressions are documented in `.checkov.yaml` with justifications. Runs without `soft_fail` on PRs. Current suppressions:
  - `CKV_AWS_2` — HTTPS redirect (HTTP only, HTTPS planned)
  - `CKV_AWS_91` — ALB access logs (cost accepted for dev/staging)
  - `CKV_AWS_116` — Lambda DLQ (not necessary for secret rotator)
  - `CKV_AWS_50` / `CKV_AWS_272` — Lambda code signing (Cosign covers container images)

### Network

ECS tasks run in private subnets with no public IP addresses. Inbound traffic reaches the tasks only through the ALB. Outbound traffic (ECR, Secrets Manager, CloudWatch) routes through NAT gateways in the same AZ. Security groups are tightly scoped: the ALB accepts HTTP from `0.0.0.0/0`; backend and frontend security groups accept traffic only from the ALB security group.

### Secrets

No secrets are hardcoded. The JWT secret key is generated externally, stored in Secrets Manager, and rotated every 30 days. All GitHub Actions secrets (AWS account ID, Snyk token, SonarQube token, SES email addresses) are stored as GitHub repository secrets and referenced as `${{ secrets.* }}`. The `.env.example` file documents which variables are needed without containing any values.

---

## Local Development

```bash
# Clone the repo
git clone https://github.com/secant78/todo-pipeline.git
cd todo-pipeline

# Copy the env template and fill in values
cp .env.example .env

# Start both services
docker compose up --build
```

The backend starts on port 5000 and the frontend on port 80. The SQLite database is stored in a named Docker volume (`sqlite-data`) so it persists across restarts. Health checks are configured in `docker-compose.yml` so the frontend waits for the backend to be ready before accepting traffic.

### Running Tests Locally

```bash
# Backend
cd backend
pip install -r requirements-dev.txt
pytest tests/ -v --cov=app --cov-report=term-missing

# Frontend
cd frontend
npm install
npm test
npm run lint
```

### Terraform

```bash
# Dev environment (workspace-based)
cd terraform
terraform init
terraform workspace select dev
terraform plan \
  -var="aws_account_id=<your-account-id>" \
  -var="backend_image_tag=dev-local" \
  -var="frontend_image_tag=dev-local"

# Staging / prod (Terragrunt)
cd terraform/environments/staging
terragrunt plan \
  -var="aws_account_id=<your-account-id>" \
  -var="backend_image_tag=staging-local" \
  -var="frontend_image_tag=staging-local"
```

---

## Environment Variables & Secrets

### Application

| Variable | Where | Description |
|---|---|---|
| `APP_ENV` | Backend container | `development` or `production` |
| `DB_PATH` | Backend container | SQLite file path (default: `/data/todo.db`) |
| `JWT_SECRET_KEY` | Backend container | Injected from Secrets Manager by ECS |
| `REACT_APP_API_URL` | Frontend build arg | API base URL (default: `/api`) |

### GitHub Actions Secrets

| Secret | Used By | Description |
|---|---|---|
| `AWS_ACCOUNT_ID` | All workflows | AWS account ID for role ARNs and ECR registry |
| `SNYK_TOKEN` | All workflows | Snyk API token for dependency scanning |
| `SONAR_TOKEN` | PR workflow | SonarQube authentication token |
| `SONAR_HOST_URL` | PR workflow | SonarQube server URL |
| `NOTIFY_FROM_EMAIL` | All workflows | SES-verified sender address |
| `NOTIFY_TO_EMAIL` | All workflows | Notification recipient address |

### AWS Secrets Manager

| Secret Name | Description |
|---|---|
| `todo-dev/jwt-secret-key` | JWT signing secret for dev environment |
| `todo-staging/jwt-secret-key` | JWT signing secret for staging environment |
| `todo-prod/jwt-secret-key` | JWT signing secret for prod environment |

All three are created by Terraform on first apply and rotated automatically every 30 days by a Lambda function.
