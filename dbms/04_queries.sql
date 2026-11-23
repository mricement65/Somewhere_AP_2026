-- PostgreSQL equivalents of Somewhere's persistence operations.
-- Load after 03_schema.sql. PREPARE registers each statement in this connection.
-- EXECUTE examples and benchmark parameter values are in 05_query_timings.md.
-- Run world_seed only when world_load returns zero rows, then repeat world_load.

-- WRITE
-- Q01 | Google callback: create a user or refresh the display name.
PREPARE user_login(text, text) AS
INSERT INTO app_user (google_id, display_name) VALUES ($1, $2)
ON CONFLICT (google_id) DO UPDATE
SET display_name = EXCLUDED.display_name, updated_at = CURRENT_TIMESTAMP
RETURNING *;

-- READ
-- Q02 | Passport deserialization by database user ID for HTTP and socket auth.
PREPARE user_by_id(bigint) AS
SELECT * FROM app_user WHERE user_id = $1;

-- WRITE
-- Q03 | Save last position on socket disconnect.
PREPARE position_save(bigint, double precision, double precision, double precision) AS
UPDATE app_user SET pos_x = $2, pos_y = $3, pos_z = $4, updated_at = CURRENT_TIMESTAMP
WHERE user_id = $1 RETURNING user_id;

-- READ
-- Q04 | Load all blocks into the server map at startup, including after seeding.
PREPARE world_load AS
SELECT x, y, z, material AS type FROM world_block;

-- WRITE
-- Q05 | Initial terrain: 400 grass, 25 stone, 2 wood.
PREPARE world_seed AS
INSERT INTO world_block (x, y, z, material)
SELECT gx, 0, gz, 'grass' FROM generate_series(-10, 9) gx CROSS JOIN generate_series(-10, 9) gz
UNION ALL
SELECT sx, 1, sz, 'stone' FROM generate_series(-2, 2) sx CROSS JOIN generate_series(-2, 2) sz
UNION ALL
SELECT 0, wy, 0, 'wood' FROM generate_series(2, 3) wy
ON CONFLICT (x, y, z) DO NOTHING;

-- WRITE
-- Q06 | Place a block. Zero returned rows means the cell is already occupied.
PREPARE block_place(integer, integer, integer, text) AS
INSERT INTO world_block (x, y, z, material) VALUES ($1, $2, $3, $4)
ON CONFLICT (x, y, z) DO NOTHING RETURNING x, y, z, material AS type;

-- WRITE
-- Q07 | Remove a block by its coordinate key. Zero rows means it was absent.
PREPARE block_remove(integer, integer, integer) AS
DELETE FROM world_block WHERE x = $1 AND y = $2 AND z = $3 RETURNING x, y, z;

-- READ
-- Q08 | Session store get. The optional join also hydrates the authenticated user.
PREPARE session_get(text) AS
SELECT s.session_id, s.session_data, s.expires_at, u.user_id, u.google_id,
       u.display_name, u.pos_x, u.pos_y, u.pos_z, u.created_at, u.updated_at
FROM web_session AS s LEFT JOIN app_user AS u ON u.user_id = s.user_id
WHERE s.session_id = $1 AND s.expires_at > CURRENT_TIMESTAMP;

-- WRITE
-- Q09 | Session store set. Pass NULL user_id for a pre-authentication session.
PREPARE session_set(text, bigint, timestamptz, jsonb) AS
INSERT INTO web_session (session_id, user_id, expires_at, session_data)
VALUES ($1, $2, $3, $4)
ON CONFLICT (session_id) DO UPDATE
SET user_id = EXCLUDED.user_id, expires_at = EXCLUDED.expires_at,
    session_data = EXCLUDED.session_data;

-- WRITE
-- Q10 | Session store touch: extend the expiry of a live session.
PREPARE session_touch(text, timestamptz) AS
UPDATE web_session SET expires_at = $2
WHERE session_id = $1 AND expires_at > CURRENT_TIMESTAMP;

-- WRITE
-- Q11 | Destroy the old session during logout or session regeneration.
PREPARE session_destroy(text) AS
DELETE FROM web_session WHERE session_id = $1;

-- WRITE
-- Q12 | SQL equivalent of MongoDB TTL cleanup. Schedule in a PostgreSQL port.
PREPARE sessions_expire AS
DELETE FROM web_session WHERE expires_at <= CURRENT_TIMESTAMP;
