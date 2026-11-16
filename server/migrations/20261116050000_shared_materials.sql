CREATE TABLE shared_materials (
    id UUID PRIMARY KEY,
    author_id UUID NOT NULL REFERENCES users(id),
    title TEXT NOT NULL CHECK (length(title) BETWEEN 1 AND 200),
    kind TEXT NOT NULL CHECK (kind IN ('material', 'question_bank')),
    course_source TEXT NOT NULL CHECK (course_source = 'jlu_iedu'),
    course_scope TEXT NOT NULL CHECK (course_scope ~ '^[0-9]{4}-[0-9]{4}-[123]$'),
    course_source_id TEXT NOT NULL CHECK (length(course_source_id) BETWEEN 1 AND 200),
    course_name TEXT NOT NULL CHECK (length(course_name) BETWEEN 1 AND 200),
    college_id TEXT,
    visibility TEXT NOT NULL CHECK (visibility IN ('students', 'college')),
    published BOOLEAN NOT NULL DEFAULT true,
    file_id UUID NOT NULL UNIQUE REFERENCES files(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (visibility <> 'college' OR college_id IS NOT NULL)
);
CREATE INDEX shared_materials_directory ON shared_materials (created_at DESC, id DESC) WHERE published;
CREATE INDEX shared_materials_course ON shared_materials (course_source, course_scope, course_source_id) WHERE published;
UPDATE service_meta SET value = '18', updated_at = now() WHERE key = 'schema_version';
