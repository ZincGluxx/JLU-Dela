CREATE TABLE sync_jobs (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    source TEXT NOT NULL,
    resource TEXT NOT NULL,
    scope JSONB NOT NULL,
    scope_key TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('queued', 'running', 'succeeded', 'failed')),
    attempts INTEGER NOT NULL DEFAULT 0,
    error_code TEXT,
    error_retryable BOOLEAN,
    complete BOOLEAN,
    snapshot_version BIGINT,
    lease_expires_at TIMESTAMPTZ,
    started_at TIMESTAMPTZ,
    finished_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);

CREATE UNIQUE INDEX sync_jobs_active_key
    ON sync_jobs (user_id, source, resource, scope_key)
    WHERE status IN ('queued', 'running');

CREATE INDEX sync_jobs_claim_idx ON sync_jobs (status, created_at);
CREATE INDEX sync_jobs_user_idx ON sync_jobs (user_id, created_at DESC);

UPDATE service_meta
SET value = '4', updated_at = now()
WHERE key = 'schema_version';
