ALTER TABLE users ALTER COLUMN login DROP NOT NULL;
ALTER TABLE users ADD COLUMN phone TEXT;
ALTER TABLE users ADD CONSTRAINT users_phone_format CHECK (phone ~ '^\+861[3-9][0-9]{9}$');
CREATE UNIQUE INDEX users_phone_key ON users (phone);

CREATE TABLE phone_verification_codes (
    phone TEXT PRIMARY KEY CHECK (phone ~ '^\+861[3-9][0-9]{9}$'),
    code_hash TEXT NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    sent_at TIMESTAMPTZ NOT NULL,
    failures INTEGER NOT NULL DEFAULT 0 CHECK (failures BETWEEN 0 AND 5),
    consumed_at TIMESTAMPTZ,
    window_started_at TIMESTAMPTZ NOT NULL,
    send_attempts INTEGER NOT NULL DEFAULT 0 CHECK (send_attempts >= 0)
);

UPDATE service_meta SET value = '7', updated_at = now() WHERE key = 'schema_version';
