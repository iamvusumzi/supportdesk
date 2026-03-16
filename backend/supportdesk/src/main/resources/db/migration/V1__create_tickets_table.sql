CREATE TYPE ticket_status AS ENUM ('OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED');
CREATE TYPE ticket_priority AS ENUM ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL');

CREATE TABLE tickets (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title           VARCHAR(255)    NOT NULL,
    description     TEXT            NOT NULL,
    status          ticket_status   NOT NULL DEFAULT 'OPEN',
    priority        ticket_priority NOT NULL DEFAULT 'MEDIUM',
    customer_email  VARCHAR(255)    NOT NULL,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- Index for the most common query pattern: list tickets by status
CREATE INDEX idx_tickets_status ON tickets(status);