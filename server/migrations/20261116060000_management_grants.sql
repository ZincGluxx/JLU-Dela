CREATE TABLE management_grants (
    user_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    scope TEXT NOT NULL CHECK (scope IN ('campus', 'college')),
    college_id TEXT NOT NULL,
    granted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, scope, college_id),
    CHECK (
        (scope = 'campus' AND college_id = '')
        OR (scope = 'college' AND length(btrim(college_id)) > 0 AND college_id = btrim(college_id))
    )
);

UPDATE service_meta SET value = '19', updated_at = now() WHERE key = 'schema_version';
