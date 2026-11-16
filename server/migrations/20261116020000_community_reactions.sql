CREATE TABLE community_post_likes (
    post_id UUID NOT NULL REFERENCES community_posts (id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (post_id, user_id)
);

CREATE TABLE community_post_favorites (
    post_id UUID NOT NULL REFERENCES community_posts (id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (post_id, user_id)
);

UPDATE service_meta SET value = '15', updated_at = now() WHERE key = 'schema_version';
