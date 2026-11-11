CREATE TABLE service_meta (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO service_meta (key, value) VALUES ('schema_version', '1');
