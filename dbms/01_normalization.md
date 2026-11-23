# Somewhere · Data normalization

The application has one shared world. Google accounts, last known positions, blocks, and HTTP sessions survive restarts. Online players, movement inputs, snapshots, chat, and typing indicators live in memory. There is no persistent chat history, block owner, or player-to-block relationship.

This PostgreSQL design translates the [Prisma models](https://github.com/PriyadarshiSidhartha/Somewhere/blob/e8917ae/server/prisma/schema.prisma), [authentication and sessions](https://github.com/PriyadarshiSidhartha/Somewhere/blob/e8917ae/server/src/auth.js), [world persistence](https://github.com/PriyadarshiSidhartha/Somewhere/blob/e8917ae/server/src/worldState.js), and [socket lifecycle](https://github.com/PriyadarshiSidhartha/Somewhere/blob/e8917ae/server/src/server.js) at revision `e8917ae`. The repository runs MongoDB. The files here describe and benchmark its PostgreSQL equivalent.

## Starting point

Imagine an export with one list of accounts, a list of sessions for each account, and a separate list of occupied cells for the shared world. Repeating the world for each account would multiply rows and make unrelated players appear to own the same blocks. Keep world cells independent from the start.

## 1NF · One fact per row

Represent positions with three scalar coordinates. Give each session its own row and each occupied cell its own row. As an intermediate example, a flattened authenticated session could contain `(session_id, expires_at, user_id, google_id, display_name, pos_x, pos_y, pos_z, created_at, updated_at)`. An account with three sessions would repeat its profile three times. Accounts with no sessions still need their own representation.

The final schema also keeps middleware-specific session metadata as one opaque JSONB value. This is a pragmatic boundary: the normal-form analysis treats the payload as one domain value. The application does not query its internal fields, and the database rejects a top-level Passport object to avoid storing the account reference twice.

## 2NF · Depend on the whole key

The flattened session example has the single-column key `session_id`, so its duplicated profile fields are a transitive-dependency problem for 3NF. A block has the composite candidate key `(x, y, z)`. None of its coordinate subsets determines material: two cells sharing a column, row, or plane can use different materials. The full key determines the material at a cell. This holds for edited worlds as well as the initial seed.

## 3NF · Separate profiles from sessions

For an authenticated session, `session_id → user_id → account attributes`. Store the profile once in `app_user` and reference it from `web_session`. This allows one profile update to cover all sessions and retains accounts after logout. A session can have no user before authentication. A left join reconstructs session details in either case. Last position stays with the account because the app retains just one latest position per account.

## BCNF · Check each determinant

| Relation | Candidate keys | Nontrivial dependencies |
|---|---|---|
| app_user | user_id or google_id | Either key determines the other and every account attribute. Display names may repeat. |
| web_session | session_id | Session ID determines user reference, expiry, and opaque middleware data. A user may have multiple sessions. |
| world_block | (x, y, z) | The entire coordinate tuple determines material. Material may repeat across cells. |

Under these application rules, every determinant of a nontrivial functional dependency is a superkey. Today’s seeded terrain does not establish additional dependencies. The five material names have no other persisted attributes, so a check constraint captures their domain without a separate material table. Coordinate uniqueness replaces MongoDB’s surrogate block ID and matches the application’s in-memory lookup. With one world there is no world ID in the key.
