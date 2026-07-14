-- 0008_session_room.sql
--
-- Backs the in-session meeting room (chat, notes, files) added in this
-- pass. Whiteboard strokes are broadcast-only (socket relay, no
-- persistence) per the build plan, so there's no session_whiteboard
-- table here — flag if you'd rather have last-frame-wins reconnect
-- support, that's a follow-up table + a couple of socket-handler lines,
-- not a schema change to what's below.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ── Chat ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS session_chat_messages (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id  uuid NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
  sender_id   uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  body        text NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_session_chat_messages_session_id
  ON session_chat_messages (session_id, created_at);

-- ── Notes ────────────────────────────────────────────────────────────────
-- ASSUMPTION (flagged earlier, not yet confirmed): one shared notes doc
-- per session, last-write-wins — not separate teacher/student notes. If
-- you want them split, this becomes a (session_id, author_id) composite
-- key instead of session_id alone; easy to change before this ships.
CREATE TABLE IF NOT EXISTS session_notes (
  session_id  uuid PRIMARY KEY REFERENCES sessions(id) ON DELETE CASCADE,
  content     text NOT NULL DEFAULT '',
  updated_by  uuid REFERENCES users(id),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

-- ── Files ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS session_files (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id   uuid NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
  uploader_id  uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  file_name    text NOT NULL,
  file_path    text NOT NULL,
  mime_type    text NOT NULL,
  size_bytes   integer NOT NULL,
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_session_files_session_id
  ON session_files (session_id, created_at);

-- ── End-session support ──────────────────────────────────────────────────
-- Needed by PATCH /sessions/:id/end so we can record when the teacher
-- actually ended it, separate from the originally scheduled end time
-- (scheduled_at + duration_mins). Not in the original 3-table list from
-- the plan, but required for that endpoint — flagging the addition here
-- rather than adding it silently.
ALTER TABLE sessions ADD COLUMN IF NOT EXISTS ended_at timestamptz;