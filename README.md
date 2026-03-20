# SupportDesk

A customer support and ticketing platform built as a deliberate learning project — designed to mirror real-world engineering at scale, one phase at a time.

The end goal is a fully operational internal ops tool with an AI-powered conversational interface, where support agents and customers can interact with the ticketing system through natural language. Every phase is independently deployable, provable, and destroyable.

---

## Why this exists

After leaving Amazon Development Centre in Cape Town (March 2024), I wanted to rebuild my engineering foundations with full ownership — not just reviewing concepts, but provisioning infrastructure, making architectural decisions, and living with the tradeoffs.

At Amazon I worked across the full stack: React + TypeScript frontends, Ruby on Rails and Flask backends, microservices, CI/CD, SLA management, and on-call. This project is where I deepen that exposure into genuine mastery — particularly around cloud infrastructure, backend patterns, and AI integrations.

The domain mirrors what I worked on professionally: customer-facing tooling, ticket management, and support workflows. That familiarity means I can focus on the engineering rather than figuring out what the system should do.

---

## Architecture

```
Browser
    │
    ▼
CloudFront ──── S3 (React + TypeScript)
    │
    │ /api/*
    ▼
API Gateway ──── Lambda (Spring Boot)
                        │
                        ▼
                  SQS Queue
                        │
                        ▼
                  Lambda (Python consumer)
                        │
                        ▼
                  RDS PostgreSQL
```

### Tech stack

| Layer          | Technology                                                       |
| -------------- | ---------------------------------------------------------------- |
| Frontend       | React, TypeScript, TanStack Query, React Router, Tailwind CSS v4 |
| Backend        | Java 21, Spring Boot 3, Spring Data JPA, Flyway                  |
| Consumer       | Python 3.12, psycopg2                                            |
| Messaging      | AWS SQS                                                          |
| Infrastructure | AWS (Lambda, API Gateway, RDS, S3, CloudFront, SQS), Terraform   |
| Local dev      | Docker (Postgres), Vite dev server                               |

---

## Following along

Each phase is preserved as a branch:

| Branch    | Description                                                   |
| --------- | ------------------------------------------------------------- |
| `phase/1` | Core ticketing — Lambda, API Gateway, RDS, S3 + CloudFront    |
| `phase/2` | Async ticket routing — SQS, Python consumer Lambda            |
| `phase/3` | File attachments — S3 pre-signed URLs, upload/download/delete |
| `phase/4` | Auth with Cognito _(in progress)_                             |

Check out any branch to see the complete working state of that phase.

---

## Getting started

Anyone who clones this repo can provision the full infrastructure, deploy the application, prove it works, and destroy everything cleanly.

### Prerequisites

- AWS account (free tier)
- AWS CLI configured (`aws configure`)
- Terraform >= 1.6.0
- Java 21, Maven
- Node.js 20+
- Docker Desktop
- Python 3.12 + pip

### 1. Create the Terraform state bucket (once only)

```bash
aws s3api create-bucket \
  --bucket supportdesk-tfstate-<your-initials> \
  --region eu-west-1 \
  --create-bucket-configuration LocationConstraint=eu-west-1

aws s3api put-bucket-versioning \
  --bucket supportdesk-tfstate-<your-initials> \
  --versioning-configuration Status=Enabled
```

Update the `bucket` field in `infra/main.tf` to match.

### 2. Configure variables

Create `infra/terraform.tfvars` (gitignored):

```hcl
db_password = "YourStrongPasswordHere"
```

### 3. Build the consumer Lambda layer

The Python consumer depends on `psycopg2-binary`, which contains compiled Linux binaries. These must be downloaded for the correct platform before Terraform can package them.

```bash
cd consumer

pip install \
  --platform manylinux2014_x86_64 \
  --target ./layer/python \
  --python-version 3.12 \
  --only-binary=:all: \
  psycopg2-binary
```

See `consumer/README.md` for a full explanation of why this step is needed.

### 4. Build the backend

```bash
cd backend/supportdesk
./mvnw clean package -DskipTests
```

### 5. Provision infrastructure

```bash
cd infra
terraform init
terraform apply
```

Note the outputs — you'll need `api_endpoint`, `s3_bucket_name`, `cloudfront_id`, and `frontend_url`.

### 6. Run database migrations

Update `backend/supportdesk/src/main/resources/application-local.yml` temporarily:

```yaml
spring:
  datasource:
    url: jdbc:postgresql://<db_endpoint>/supportdesk?ssl=true&sslmode=require
    username: supportdesk_admin
    password: <your-db-password>
  jpa:
    show-sql: true

sqs:
  queue:
    url: http://localhost:9324/queue/supportdesk-ticket-routing
```

Run once to apply all Flyway migrations:

```bash
./mvnw spring-boot:run -Dspring-boot.run.profiles=local
```

Kill it once you see `Started SupportdeskApplication`. Revert `application-local.yml` back to `localhost:5432`.

### 7. Build and deploy the frontend

The frontend API URL is automatically derived from Terraform outputs — no hardcoding needed.

```bash
cd frontend

# Linux/Mac
VITE_API_URL=$(cd ../infra && terraform output -raw api_endpoint) npm run build

# Windows PowerShell
$env:VITE_API_URL=(cd ../infra; terraform output -raw api_endpoint)
npm run build

aws s3 sync dist/ s3://$(cd ../infra && terraform output -raw s3_bucket_name) --delete

aws cloudfront create-invalidation \
  --distribution-id $(cd ../infra && terraform output -raw cloudfront_id) \
  --paths "/*"
```

### 8. Open the app

Visit the `frontend_url` from Terraform outputs. Create a ticket with `CRITICAL` or `HIGH` priority — within a few seconds the team badge should update to `Escalations`. `MEDIUM` or `LOW` routes to `General Support`.

### 9. Destroy everything

```bash
aws s3 rm s3://$(cd infra && terraform output -raw s3_bucket_name) --recursive
aws s3 rm s3://$(aws s3 ls | grep lambda-deployments | awk '{print $3}') --recursive

cd infra
terraform destroy
```

---

## Architectural decisions and tradeoffs

### RDS is publicly accessible

Lambda runs outside the VPC, which means it has no static IP and cannot be placed inside a private subnet without a NAT Gateway (~$32/month, no free tier).

**Decision:** RDS is `publicly_accessible = true`. The security group permits port 5432 from any IP. All connections require SSL and are protected by credentials.

**Production fix:** Lambda inside a VPC with a NAT Gateway or AWS PrivateLink. Revisited in the containers phase.

### Serverless over containers

ECS Fargate is more production-realistic but introduces container orchestration complexity before the application patterns are solid. Serverless keeps the focus on the application itself.

**Production equivalent:** ECS Fargate with an ALB, private subnets, and a NAT Gateway. Planned for a dedicated containers phase.

### Spring Boot on Lambda (cold starts)

The `aws-serverless-java-container` library adapts Spring Boot to run as a Lambda handler with minimal code changes. Cold start time is ~20 seconds due to Spring's application context initialisation.

**Mitigations:** 1024MB memory allocation, SnapStart enabled on published versions.

### API Gateway CORS with specific method routes

HTTP API Gateway's built-in CORS handling is bypassed when an `ANY /{proxy+}` route exists because `ANY` includes `OPTIONS`. The fix is explicit per-method routes (`GET`, `POST`, `PATCH`, `DELETE`), leaving `OPTIONS` unclaimed so the API-level CORS config handles preflight requests natively.

### CORS origin auto-wired from Terraform

The allowed CORS origin is derived directly from the CloudFront distribution output in Terraform — no hardcoded URLs in `terraform.tfvars`. Every `terraform apply` automatically wires the correct CloudFront domain into API Gateway and Lambda.

### Polyglot Lambdas

The backend uses Java (Spring Boot) — type-safe, suited to complex business logic. The consumer uses Python — lightweight, fast cold starts, appropriate for a simple routing function. In Phase 5 the Python consumer's routing logic gets replaced with a Claude API call, keeping the same structure.

### Lambda deployment reliability on Windows

Terraform's `filemd5()` has path translation issues on Windows with Git Bash. The fix is `filesha256()` which is reliable cross-platform. `source_code_hash = filesha256(var.jar_path)` ties the Lambda's lifecycle directly to the jar content — `terraform apply` is the only deployment command needed.

### Postgres custom enums with Hibernate

Postgres custom enum types require `@JdbcTypeCode(SqlTypes.NAMED_ENUM)` on every Hibernate entity field. Without it, Hibernate sends `VARCHAR` and Postgres rejects it. This applies to every custom enum column going forward.

### Python Lambda dependencies as a Layer

`psycopg2-binary` contains compiled C extensions that must match Lambda's Linux environment. Dependencies are built locally using pip's `--platform manylinux2014_x86_64` flag and packaged as a Lambda Layer — keeping the function zip small and making dependency updates independent of code changes.

---

## Phases

### ✅ Phase 1 — Core ticketing (complete)

Ticket CRUD, status and priority management, React dashboard, full AWS deployment via Terraform.

### ✅ Phase 2 — Async routing with SQS (complete)

Ticket creation publishes to SQS. A Python Lambda consumer routes tickets to teams based on priority. Introduces event-driven patterns, dead letter queues, and polyglot Lambdas.

### ✅ Phase 3 — File attachments with S3

Support agents can attach files to tickets. Introduces pre-signed S3 URLs, multipart upload, and storage lifecycle policies.

### 🔜 Phase 4 — Auth with Cognito

User authentication and role-based access control. Agents, admins, and customers get different views and permissions. JWT validation at the API Gateway layer.

### 🔜 Phase 5 — AI ticket classification

A Lambda function uses the Claude API to automatically classify incoming tickets by category and suggested priority. The Python consumer's `assign_team()` function gets replaced with an AI call — same structure, smarter logic.

### 🔜 Phase 6 — Conversational interface

Customers interact with the support system through a chat interface powered by Claude. Natural language queries trigger backend workflows — creating tickets, checking status, escalating issues — without touching the traditional UI.

---

## Local development

```bash
# Start local Postgres
cd backend/supportdesk
docker compose up -d

# Run Spring Boot against local DB
./mvnw spring-boot:run -Dspring-boot.run.profiles=local

# Run React frontend (proxies /api to localhost:8080)
cd frontend
npm run dev
```

---

## Repository structure

```
supportdesk/
├── infra/                        Terraform — all AWS infrastructure
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── modules/
│       ├── database/             RDS PostgreSQL
│       ├── lambda/               Spring Boot Lambda + IAM + S3 deployment bucket
│       ├── lambda_consumer/      Python routing Lambda + SQS event source + Layer
│       ├── sqs/                  Ticket routing queue + dead letter queue
│       ├── api_gateway/          HTTP API Gateway
│       └── frontend/             S3 bucket + CloudFront distribution
├── backend/supportdesk/          Spring Boot application
│   └── src/main/
│       ├── java/com/supportdesk/
│       │   ├── ticket/           Ticket entity, service, controller, DTOs
│       │   └── shared/           SQS publisher, exception handling
│       └── resources/
│           ├── application.yml
│           ├── application-local.yml
│           ├── application-prod.yml
│           └── db/migration/     Flyway versioned migrations
├── consumer/                     Python Lambda consumer
│   ├── handler.py
│   ├── requirements.txt
│   └── README.md
└── frontend/                     React + TypeScript
    └── src/
        ├── api/                  Axios client
        ├── types/                TypeScript interfaces
        ├── pages/                TicketListPage, TicketDetailPage
        └── components/           Layout, badges, CreateTicketModal
```
