CREATE TABLE teaching_backups (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    revision INTEGER NOT NULL DEFAULT 0 CHECK (revision >= 0),
    deleted BOOLEAN NOT NULL DEFAULT true,
    payload JSONB,
    updated_at TIMESTAMPTZ,
    CHECK ((deleted AND payload IS NULL) OR
           (NOT deleted AND payload IS NOT NULL AND jsonb_typeof(payload) = 'object'))
);

UPDATE service_meta SET value = '20', updated_at = now() WHERE key = 'schema_version';
