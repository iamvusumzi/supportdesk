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
RDS PostgreSQL
```

### Tech stack

| Layer          | Technology                                                       |
| -------------- | ---------------------------------------------------------------- |
| Frontend       | React, TypeScript, TanStack Query, React Router, Tailwind CSS v4 |
| Backend        | Java 21, Spring Boot 3, Spring Data JPA, Flyway                  |
| Infrastructure | AWS (Lambda, API Gateway, RDS, S3, CloudFront), Terraform        |
| Local dev      | Docker (Postgres), Vite dev server                               |

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
db_password     = "YourStrongPasswordHere"
allowed_origins = "https://<your-cloudfront-domain>.cloudfront.net"
```

### 3. Build the backend

```bash
cd backend
./mvnw package -DskipTests
```

### 4. Provision infrastructure

```bash
cd infra
terraform init
terraform apply
```

Note the outputs — you'll need `api_endpoint`, `s3_bucket_name`, and `cloudfront_id`.

### 5. Run database migrations

Update `backend/src/main/resources/application-local.yml` with the RDS endpoint from the Terraform output, then run once:

```bash
./mvnw spring-boot:run -Dspring-boot.run.profiles=local
```

Kill it once you see `Started SupportdeskApplication`. Revert `application-local.yml` to `localhost:5432`.

### 6. Build and deploy the frontend

```bash
cd frontend

# Linux/Mac
VITE_API_URL=<api_endpoint> npm run build

# Windows PowerShell
$env:VITE_API_URL="<api_endpoint>"
npm run build

aws s3 sync dist/ s3://<s3_bucket_name> --delete

aws cloudfront create-invalidation \
  --distribution-id <cloudfront_id> \
  --paths "/*"
```

### 7. Open the app

Visit the `frontend_url` from Terraform outputs.

### 8. Destroy everything

```bash
aws s3 rm s3://<s3_bucket_name> --recursive
aws s3 rm s3://<lambda-deployments-bucket> --recursive

cd infra
terraform destroy
```

---

## Architectural decisions and tradeoffs

### RDS is publicly accessible

Lambda runs outside the VPC in this phase, which means it has no static IP and cannot be placed inside a private subnet without a NAT Gateway. NAT Gateway costs ~$32/month with no free tier — prohibitive for a portfolio project.

**Decision:** RDS is set to `publicly_accessible = true`. The security group permits inbound connections on port 5432 from any IP. All connections require SSL, and access is protected by credentials.

**What this would look like in production:** Lambda inside a VPC with a NAT Gateway or AWS PrivateLink. This will be revisited in the containers phase.

### Serverless over containers for Phase 1

ECS Fargate with an Application Load Balancer is a more production-realistic deployment target, but it introduces container orchestration complexity before the application patterns are solid. Serverless lets the focus stay on the application itself.

**What this would look like in production:** ECS Fargate with an ALB, private subnets, and a NAT Gateway. Planned for a dedicated containers phase.

### Spring Boot on Lambda (cold starts)

The `aws-serverless-java-container` library adapts the existing Spring Boot application to run as a Lambda handler with minimal code changes. The tradeoff is cold start time (~20 seconds on first invocation) due to Spring's application context initialisation.

**Mitigations:** 1024MB memory allocation (more memory = faster CPU = faster startup), SnapStart enabled on published versions.

### API Gateway CORS with specific method routes

HTTP API Gateway's built-in CORS handling is bypassed when an `ANY /{proxy+}` route exists, because `ANY` includes `OPTIONS` and the explicit route takes priority over the CORS configuration. The fix is to define explicit routes per HTTP method (`GET`, `POST`, `PATCH`, `DELETE`), leaving `OPTIONS` unclaimed so the API-level CORS config handles preflight requests natively.

---

## Phases

### ✅ Phase 1 — Core ticketing (complete)

Ticket CRUD, status and priority management, React dashboard, full AWS deployment via Terraform.

### 🔜 Phase 2 — Async routing with SQS

Ticket creation triggers an SQS message. A separate Lambda consumer processes routing logic asynchronously — assigning tickets based on priority and availability. Introduces event-driven patterns and decoupled services.

### 🔜 Phase 3 — File attachments with S3

Support agents can attach files to tickets. Introduces pre-signed S3 URLs, multipart upload, and storage lifecycle policies.

### 🔜 Phase 4 — Auth with Cognito

User authentication and role-based access control. Agents, admins, and customers get different views and permissions. JWT validation at the API Gateway layer.

### 🔜 Phase 5 — AI ticket classification

A Lambda function uses the Claude API to automatically classify incoming tickets by category and suggested priority. Introduces AI integration into a backend workflow.

### 🔜 Phase 6 — Conversational interface

Customers interact with the support system through a chat interface powered by Claude. Natural language queries trigger backend workflows — creating tickets, checking status, escalating issues — without touching the traditional UI.

---

## Local development

```bash
# Start local Postgres
cd backend
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
├── infra/                  Terraform — all AWS infrastructure
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── modules/
│       ├── database/       RDS PostgreSQL
│       ├── lambda/         Lambda function + IAM + S3 deployment bucket
│       ├── api_gateway/    HTTP API Gateway
│       └── frontend/       S3 bucket + CloudFront distribution
├── backend/                Spring Boot application
│   └── src/main/
│       ├── java/com/supportdesk/
│       │   ├── ticket/     Ticket entity, service, controller, DTOs
│       │   └── shared/     Exception handling
│       └── resources/
│           ├── application.yml
│           ├── application-local.yml
│           ├── application-prod.yml
│           └── db/migration/
└── frontend/               React + TypeScript
    └── src/
        ├── api/            Axios client
        ├── types/          TypeScript interfaces
        ├── pages/          TicketListPage, TicketDetailPage
        └── components/     Layout, StatusBadge, PriorityBadge, CreateTicketModal
```
