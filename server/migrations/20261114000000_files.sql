CREATE TABLE files (
    id UUID PRIMARY KEY,
    uploader_id UUID NOT NULL REFERENCES users(id),
    original_name TEXT NOT NULL CHECK (char_length(original_name) BETWEEN 1 AND 255),
    size_bytes BIGINT NOT NULL CHECK (size_bytes > 0),
    media_type TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    use_kind TEXT CHECK (use_kind IN ('material', 'community_image')),
    business_id UUID,
    deleting BOOLEAN NOT NULL DEFAULT false,
    CHECK ((use_kind IS NULL) = (business_id IS NULL))
);

UPDATE service_meta SET value = '9' WHERE key = 'schema_version';
