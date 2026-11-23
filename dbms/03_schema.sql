-- Somewhere | PostgreSQL relational port. Apply once to an empty database.
BEGIN;

CREATE TABLE app_user (
    user_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    google_id text NOT NULL UNIQUE,
    display_name text NOT NULL,
    pos_x double precision NOT NULL DEFAULT 0,
    pos_y double precision NOT NULL DEFAULT 2.5,
    pos_z double precision NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE web_session (
    session_id text PRIMARY KEY,
    user_id bigint REFERENCES app_user (user_id) ON DELETE CASCADE,
    expires_at timestamptz NOT NULL,
    -- Cookie and other middleware state. Passport's user ID lives only in user_id.
    session_data jsonb NOT NULL DEFAULT '{}'::jsonb,
    CHECK (jsonb_typeof(session_data) = 'object' AND NOT (session_data ? 'passport'))
);
CREATE INDEX web_session_expiry_idx ON web_session (expires_at);
CREATE INDEX web_session_user_idx ON web_session (user_id);

CREATE TABLE world_block (
    x integer NOT NULL CHECK (x BETWEEN -30 AND 30),
    y integer NOT NULL CHECK (y BETWEEN 0 AND 20),
    z integer NOT NULL CHECK (z BETWEEN -30 AND 30),
    material text NOT NULL DEFAULT 'dirt'
        CHECK (material IN ('dirt', 'grass', 'stone', 'wood', 'sand')),
    PRIMARY KEY (x, y, z)
);

COMMIT;
