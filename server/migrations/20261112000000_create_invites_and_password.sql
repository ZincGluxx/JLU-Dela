ALTER TABLE users ADD COLUMN password_hash TEXT;

CREATE TABLE invites (
    id UUID PRIMARY KEY,
    login TEXT NOT NULL,
    display_name TEXT NOT NULL,
    token_hash TEXT NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    used_at TIMESTAMPTZ,
    used_by UUID REFERENCES users (id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL,
    CONSTRAINT invites_login_not_blank CHECK (length(btrim(login)) > 0),
    CONSTRAINT invites_display_name_not_blank CHECK (length(btrim(display_name)) > 0)
);

CREATE UNIQUE INDEX invites_active_login_key ON invites (login) WHERE used_at IS NULL;

CREATE TABLE login_attempts (
    login_hash TEXT PRIMARY KEY,
    failures INTEGER NOT NULL,
    window_started_at TIMESTAMPTZ NOT NULL,
    locked_until TIMESTAMPTZ
);

CREATE INDEX login_attempts_window_idx ON login_attempts (window_started_at);

UPDATE service_meta
SET value = '5', updated_at = now()
WHERE key = 'schema_version';
