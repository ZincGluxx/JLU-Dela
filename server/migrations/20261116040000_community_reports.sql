CREATE TABLE community_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    post_id UUID NOT NULL,
    reason TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status = 'pending'),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (reporter_id, post_id)
);

CREATE INDEX community_reports_reporter_time
    ON community_reports (reporter_id, created_at DESC, id DESC);

UPDATE service_meta SET value = '17', updated_at = now() WHERE key = 'schema_version';
