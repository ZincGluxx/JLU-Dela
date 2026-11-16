ALTER TABLE community_comments ADD COLUMN reply_to_comment_id UUID;

UPDATE service_meta SET value = '14', updated_at = now() WHERE key = 'schema_version';
