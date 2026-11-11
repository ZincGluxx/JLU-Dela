CREATE TABLE users (
    id UUID PRIMARY KEY,
    login TEXT NOT NULL,
    display_name TEXT NOT NULL,
    timezone TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    disabled_at TIMESTAMPTZ,
    CONSTRAINT users_login_not_blank CHECK (length(btrim(login)) > 0),
    CONSTRAINT users_display_name_not_blank CHECK (length(btrim(display_name)) > 0)
);

CREATE UNIQUE INDEX users_login_key ON users (login);

CREATE TABLE sessions (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    access_token_hash TEXT NOT NULL,
    refresh_token_hash TEXT NOT NULL,
    access_expires_at TIMESTAMPTZ NOT NULL,
    refresh_expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    last_used_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ,
    revoked_reason TEXT
);

CREATE UNIQUE INDEX sessions_access_token_hash_key ON sessions (access_token_hash);
CREATE UNIQUE INDEX sessions_refresh_token_hash_key ON sessions (refresh_token_hash);
CREATE INDEX sessions_user_id_idx ON sessions (user_id);

UPDATE service_meta
SET value = '2', updated_at = now()
WHERE key = 'schema_version';
