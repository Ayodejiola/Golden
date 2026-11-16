-- 0002: transactional outbox (publisher side) and idempotent inbox (consumer side).
CREATE TABLE IF NOT EXISTS outbox (
    id              bigserial PRIMARY KEY,
    aggregate_type  text NOT NULL,
    aggregate_id    uuid NOT NULL,
    event_type      text NOT NULL,
    payload         jsonb NOT NULL,
    traceparent     text,
    created_at      timestamptz NOT NULL DEFAULT now(),
    published_at    timestamptz,
    attempts        integer NOT NULL DEFAULT 0,
    last_error      text
);
CREATE INDEX IF NOT EXISTS outbox_unpublished_idx ON outbox (id) WHERE published_at IS NULL;

CREATE TABLE IF NOT EXISTS processed_messages (
    message_id      text PRIMARY KEY,
    consumer        text NOT NULL,
    processed_at    timestamptz NOT NULL DEFAULT now()
);

-- Housekeeping with pg_cron (enabled on the server): keep 14 days of published events / inbox records.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
        PERFORM cron.schedule('outbox-cleanup', '17 3 * * *',
            $cron$DELETE FROM outbox WHERE published_at < now() - interval '14 days'$cron$);
        PERFORM cron.schedule('inbox-cleanup', '27 3 * * *',
            $cron$DELETE FROM processed_messages WHERE processed_at < now() - interval '14 days'$cron$);
    END IF;
END $$;
