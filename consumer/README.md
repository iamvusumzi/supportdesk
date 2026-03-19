# Ticket Router — Python Lambda Consumer

This Lambda function is the async consumer for the `supportdesk-ticket-routing` SQS queue. When a ticket is created, the Spring Boot backend publishes a message to the queue. This function picks it up, applies routing logic, and updates the ticket's `assigned_team` in RDS.

---

## How it works

```
SQS Queue (supportdesk-ticket-routing)
        │
        ▼
lambda_handler(event, context)
        │
        ▼
assign_team(priority)        ← routing logic lives here
        │
        ▼
UPDATE tickets SET assigned_team = ? WHERE id = ?
```

Routing rules:

- `CRITICAL` / `HIGH` → `ESCALATIONS`
- `MEDIUM` / `LOW` → `GENERAL_SUPPORT`

In Phase 5 this function will be replaced with a Claude API call that classifies tickets based on content rather than priority alone. The structure stays identical — only `assign_team()` changes.

---

## Directory structure

```
consumer/
├── handler.py           ← Lambda function code
├── requirements.txt     ← documents dependencies (pip source of truth)
└── layer/               ← gitignored, must be built locally before deploying
    └── python/          ← psycopg2-binary Linux binaries live here
```

---

## Setting up dependencies before deploying

Lambda runs on Amazon Linux. If you build Python packages on Windows or Mac, the compiled C extensions won't work in the Lambda environment. We solve this by using pip's `--platform` flag to download Linux-compatible binaries regardless of your local OS.

**Run this before your first `terraform apply` and any time `requirements.txt` changes:**

```bash
cd consumer

pip install \
  --platform manylinux2014_x86_64 \
  --target ./layer/python \
  --python-version 3.12 \
  --only-binary=:all: \
  psycopg2-binary
```

This downloads the `manylinux` wheel — a Linux binary compatible with Lambda's Amazon Linux 2 environment — and places it in `layer/python/`.

Terraform packages `layer/python/` into a Lambda Layer zip and `handler.py` into a separate function zip. The layer is attached to the function at deploy time, making `psycopg2` available at `/opt/python/` which Python automatically searches.

### Why a Layer instead of bundling into the function zip?

Lambda has a 250MB unzipped deployment limit. Keeping dependencies in a Layer:

- Keeps the function zip small (just `handler.py`)
- Lets the layer be reused across multiple functions in future phases
- Means dependency updates and code updates deploy independently

---

## Why `layer/` is gitignored

The `layer/python/` directory contains compiled C binaries (~8MB). These are platform-specific (Linux x86_64) and reproducibly generated from `requirements.txt`. Anyone cloning the repo runs the pip install command above to regenerate them. `requirements.txt` is the source of truth.

---

## Environment variables

Injected by Terraform from the Lambda consumer module:

| Variable      | Description                          |
| ------------- | ------------------------------------ |
| `DB_HOST`     | RDS endpoint hostname (without port) |
| `DB_PORT`     | Postgres port (5432)                 |
| `DB_NAME`     | Database name                        |
| `DB_USER`     | Database username                    |
| `DB_PASSWORD` | Database password                    |

---

## Local testing

Invoke the handler directly with a mock event:

```python
# test_handler.py
from handler import lambda_handler

mock_event = {
    "Records": [{
        "body": '{"ticketId": "123e4567-e89b-12d3-a456-426614174000", "priority": "CRITICAL"}'
    }]
}

lambda_handler(mock_event, None)
```

Run against local Docker Postgres:

```bash
DB_HOST=localhost DB_PORT=5432 DB_NAME=supportdesk \
DB_USER=supportdesk_admin DB_PASSWORD=localpassword \
python test_handler.py
```

---

## Monitoring

Logs:

```bash
MSYS_NO_PATHCONV=1 aws logs tail /aws/lambda/supportdesk-ticket-router \
  --region eu-west-1 \
  --follow
```

Check the dead letter queue for failed messages (retried 3 times before landing here):

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

aws sqs get-queue-attributes \
  --region eu-west-1 \
  --queue-url https://sqs.eu-west-1.amazonaws.com/$ACCOUNT_ID/supportdesk-ticket-routing-dlq \
  --attribute-names ApproximateNumberOfMessages
```
