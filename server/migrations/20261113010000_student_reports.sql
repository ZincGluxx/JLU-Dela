CREATE TABLE student_reports (
    user_id UUID PRIMARY KEY REFERENCES users (id) ON DELETE CASCADE,
    school TEXT NOT NULL CHECK (school = '吉林大学'),
    source TEXT NOT NULL CHECK (source = 'chsi'),
    verified_at TIMESTAMPTZ NOT NULL,
    college_name TEXT,
    college_source_field TEXT,
    CONSTRAINT student_reports_college_source CHECK (
        (college_name IS NULL AND college_source_field IS NULL)
        OR (
            college_name IS NOT NULL AND college_source_field IS NOT NULL
            AND length(btrim(college_name)) > 0
            AND length(btrim(college_source_field)) > 0
        )
    )
);

UPDATE service_meta
SET value = '8', updated_at = now()
WHERE key = 'schema_version';
