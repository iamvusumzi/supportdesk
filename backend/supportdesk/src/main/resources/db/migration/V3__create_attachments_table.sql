CREATE TABLE attachments (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_id   UUID        NOT NULL REFERENCES tickets(id) ON DELETE CASCADE,
    file_name   VARCHAR(255) NOT NULL,
    file_key    VARCHAR(512) NOT NULL,   
    file_size   BIGINT      NOT NULL,    
    mime_type   VARCHAR(127) NOT NULL,
    uploaded_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_attachments_ticket_id ON attachments(ticket_id);