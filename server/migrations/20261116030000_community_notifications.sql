CREATE TABLE community_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recipient_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    actor_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    post_id UUID NOT NULL REFERENCES community_posts (id) ON DELETE CASCADE,
    comment_id UUID REFERENCES community_comments (id) ON DELETE CASCADE,
    kind TEXT NOT NULL CHECK (kind IN ('comment', 'reply', 'like')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    read_at TIMESTAMPTZ
);

CREATE INDEX community_notifications_recipient_time
    ON community_notifications (recipient_id, created_at DESC, id DESC);
CREATE UNIQUE INDEX community_notifications_comment_recipient
    ON community_notifications (recipient_id, comment_id) WHERE kind IN ('comment', 'reply');
CREATE UNIQUE INDEX community_notifications_like_recipient_actor_post
    ON community_notifications (recipient_id, actor_id, post_id) WHERE kind = 'like';

UPDATE service_meta SET value = '16', updated_at = now() WHERE key = 'schema_version';
