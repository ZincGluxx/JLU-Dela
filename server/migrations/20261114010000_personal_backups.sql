CREATE TABLE personal_backups (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    revision INTEGER NOT NULL DEFAULT 0 CHECK (revision >= 0),
    deleted BOOLEAN NOT NULL DEFAULT true,
    notes JSONB NOT NULL DEFAULT '[]'::jsonb,
    updated_at TIMESTAMPTZ,
    CHECK (jsonb_typeof(notes) = 'array' AND jsonb_array_length(notes) <= 100),
    CHECK (NOT deleted OR notes = '[]'::jsonb)
);

UPDATE service_meta SET value = '10', updated_at = now() WHERE key = 'schema_version';
