CREATE TABLE community_post_images (
    post_id UUID NOT NULL REFERENCES community_posts (id) ON DELETE CASCADE,
    file_id UUID NOT NULL UNIQUE REFERENCES files (id),
    position INTEGER NOT NULL CHECK (position BETWEEN 0 AND 3),
    PRIMARY KEY (post_id, position)
);

UPDATE service_meta SET value = '12', updated_at = now() WHERE key = 'schema_version';
