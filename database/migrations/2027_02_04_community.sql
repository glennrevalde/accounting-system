-- =====================================================================
--  G-SMaRT Accounting - migration: Community (v41)
--
--  What it changes
--    1. The tables of the Community module: channels (with the roles that
--       may see a restricted one), the members of a channel and how far each
--       has read, chat messages, their reactions and attached files,
--       inquiries (questions) with their categories and responses, private
--       conversations and their messages, blocked users, each user's
--       community settings, notifications, reports, mutes and suspensions,
--       and the moderation log. All empty at first, except:
--    2. Six channels: General Discussion, Questions and Inquiries, Help and
--       Support, Announcements (only moderators post), Suggestions and
--       Feedback, Community Concerns; and six inquiry categories.
--    3. A new menu, Community, with three pages:
--         Community Chat            every role (roles that create anything
--                                   anywhere may post; others may read)
--         Questions & Inquiries     the same roles
--         Community Management      the roles that may open User Accounts
--
--  Nothing is deleted and no amount changes.
--
--  For an EXISTING database that already has the earlier migrations.
--  New installs do not need it (tools/install.php and the bundled dumps include it).
--  Safe to run more than once. Works on MySQL 5.5.3+ and MariaDB 5.5+.
--
--  How to run (back up the database first):
--    phpMyAdmin: click the accounting_system database > Import > choose this file > Go
--    Navicat:    right-click the accounting_system database > Execute SQL File
--    or:         mysql -u root -p accounting_system < 2027_02_04_community.sql
-- =====================================================================

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------
--  1. Channels
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS community_channels (
  id             INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  slug           VARCHAR(40)  NOT NULL,
  name           VARCHAR(80)  NOT NULL,
  description    VARCHAR(255) NULL,
  kind           VARCHAR(12)  NOT NULL DEFAULT 'chat',        -- chat, announcement
  post_policy    VARCHAR(12)  NOT NULL DEFAULT 'everyone',    -- everyone, moderators
  is_restricted  TINYINT(1)   NOT NULL DEFAULT 0,             -- 1: only the roles in community_channel_roles (and moderators)
  is_archived    TINYINT(1)   NOT NULL DEFAULT 0,
  sort_order     INT          NOT NULL DEFAULT 0,
  created_by     INT UNSIGNED NULL,
  created_at     DATETIME     NOT NULL,
  updated_at     DATETIME     NULL,
  UNIQUE KEY uq_cch_slug (slug)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS community_channel_roles (
  channel_id  INT UNSIGNED NOT NULL,
  role_id     INT UNSIGNED NOT NULL,
  PRIMARY KEY (channel_id, role_id),
  CONSTRAINT fk_ccr_channel FOREIGN KEY (channel_id) REFERENCES community_channels(id) ON DELETE CASCADE,
  CONSTRAINT fk_ccr_role FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- who has opened a channel, how far they have read (the read receipt) and what they are notified of
CREATE TABLE IF NOT EXISTS community_members (
  channel_id    INT UNSIGNED NOT NULL,
  user_id       INT UNSIGNED NOT NULL,
  last_read_id  INT UNSIGNED NOT NULL DEFAULT 0,
  notify        VARCHAR(10)  NOT NULL DEFAULT 'mentions',     -- all, mentions, none
  joined_at     DATETIME     NOT NULL,
  PRIMARY KEY (channel_id, user_id),
  KEY ix_cm_user (user_id),
  CONSTRAINT fk_cm_channel FOREIGN KEY (channel_id) REFERENCES community_channels(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
--  2. Chat messages, reactions
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS community_messages (
  id             INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  channel_id     INT UNSIGNED NOT NULL,
  user_id        INT UNSIGNED NOT NULL,
  body           TEXT         NULL,
  reply_to_id    INT UNSIGNED NULL,
  client_key     VARCHAR(40)  NULL,                            -- the sender's own key: a message sent twice is kept once
  is_official    TINYINT(1)   NOT NULL DEFAULT 0,              -- posted by a moderator as an announcement
  is_pinned      TINYINT(1)   NOT NULL DEFAULT 0,
  pinned_by      INT UNSIGNED NULL,
  pinned_at      DATETIME     NULL,
  is_hidden      TINYINT(1)   NOT NULL DEFAULT 0,
  hidden_by      INT UNSIGNED NULL,
  hidden_reason  VARCHAR(255) NULL,
  edited_at      DATETIME     NULL,
  deleted_at     DATETIME     NULL,
  deleted_by     INT UNSIGNED NULL,
  created_at     DATETIME     NOT NULL,
  updated_at     DATETIME     NOT NULL,
  KEY ix_cmsg_channel (channel_id, id),
  KEY ix_cmsg_changed (channel_id, updated_at),
  KEY ix_cmsg_user (user_id, created_at),
  UNIQUE KEY uq_cmsg_client (user_id, client_key),
  CONSTRAINT fk_cmsg_channel FOREIGN KEY (channel_id) REFERENCES community_channels(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS community_reactions (
  message_id  INT UNSIGNED NOT NULL,
  user_id     INT UNSIGNED NOT NULL,
  emoji       VARCHAR(16)  NOT NULL,
  created_at  DATETIME     NOT NULL,
  PRIMARY KEY (message_id, user_id, emoji),
  CONSTRAINT fk_crx_message FOREIGN KEY (message_id) REFERENCES community_messages(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
--  3. Files (attached to messages, private messages, inquiries and responses; pictures of users)
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS community_files (
  id          INT UNSIGNED    NOT NULL AUTO_INCREMENT PRIMARY KEY,
  owner_type  VARCHAR(12)     NOT NULL DEFAULT 'pending',     -- pending, message, dm, inquiry, response, avatar
  owner_id    INT UNSIGNED    NULL,
  user_id     INT UNSIGNED    NOT NULL,
  file_name   VARCHAR(255)    NOT NULL,
  mime_type   VARCHAR(150)    NOT NULL DEFAULT 'application/octet-stream',
  file_size   BIGINT UNSIGNED NOT NULL DEFAULT 0,
  is_image    TINYINT(1)      NOT NULL DEFAULT 0,
  chunks      INT UNSIGNED    NOT NULL DEFAULT 0,
  created_at  DATETIME        NOT NULL,
  KEY ix_cf_owner (owner_type, owner_id),
  KEY ix_cf_user (user_id, owner_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS community_file_chunks (
  file_id  INT UNSIGNED NOT NULL,
  seq      INT UNSIGNED NOT NULL,
  data     MEDIUMBLOB   NOT NULL,
  PRIMARY KEY (file_id, seq),
  CONSTRAINT fk_cfc_file FOREIGN KEY (file_id) REFERENCES community_files(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
--  4. Questions and inquiries
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS community_inquiry_categories (
  id           INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name         VARCHAR(80)  NOT NULL,
  description  VARCHAR(255) NULL,
  sort_order   INT          NOT NULL DEFAULT 0,
  is_active    TINYINT(1)   NOT NULL DEFAULT 1,
  UNIQUE KEY uq_cic_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS community_inquiries (
  id                    INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  category_id           INT UNSIGNED NULL,
  user_id               INT UNSIGNED NOT NULL,
  title                 VARCHAR(200) NOT NULL,
  body                  TEXT         NOT NULL,
  status                VARCHAR(10)  NOT NULL DEFAULT 'open',   -- open, answered, resolved
  accepted_response_id  INT UNSIGNED NULL,
  response_count        INT UNSIGNED NOT NULL DEFAULT 0,
  views                 INT UNSIGNED NOT NULL DEFAULT 0,
  client_key            VARCHAR(40)  NULL,
  is_hidden             TINYINT(1)   NOT NULL DEFAULT 0,
  hidden_by             INT UNSIGNED NULL,
  hidden_reason         VARCHAR(255) NULL,
  resolved_by           INT UNSIGNED NULL,
  resolved_at           DATETIME     NULL,
  edited_at             DATETIME     NULL,
  last_activity_at      DATETIME     NOT NULL,
  created_at            DATETIME     NOT NULL,
  KEY ix_ci_status (status, last_activity_at),
  KEY ix_ci_category (category_id),
  KEY ix_ci_user (user_id, created_at),
  UNIQUE KEY uq_ci_client (user_id, client_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS community_inquiry_responses (
  id             INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  inquiry_id     INT UNSIGNED NOT NULL,
  user_id        INT UNSIGNED NOT NULL,
  parent_id      INT UNSIGNED NULL,                            -- a comment on a response
  body           TEXT         NOT NULL,
  is_official    TINYINT(1)   NOT NULL DEFAULT 0,              -- given by a moderator as the official answer
  client_key     VARCHAR(40)  NULL,
  is_hidden      TINYINT(1)   NOT NULL DEFAULT 0,
  hidden_by      INT UNSIGNED NULL,
  hidden_reason  VARCHAR(255) NULL,
  edited_at      DATETIME     NULL,
  deleted_at     DATETIME     NULL,
  created_at     DATETIME     NOT NULL,
  KEY ix_cir_inquiry (inquiry_id, id),
  KEY ix_cir_user (user_id, created_at),
  UNIQUE KEY uq_cir_client (user_id, client_key),
  CONSTRAINT fk_cir_inquiry FOREIGN KEY (inquiry_id) REFERENCES community_inquiries(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
--  5. Private messages (never shown to anyone but the two people in the conversation)
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS community_conversations (
  id               INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  user_a           INT UNSIGNED NOT NULL,                      -- the smaller user id
  user_b           INT UNSIGNED NOT NULL,
  a_last_read      INT UNSIGNED NOT NULL DEFAULT 0,
  b_last_read      INT UNSIGNED NOT NULL DEFAULT 0,
  last_message_id  INT UNSIGNED NOT NULL DEFAULT 0,
  last_message_at  DATETIME     NULL,
  created_at       DATETIME     NOT NULL,
  UNIQUE KEY uq_cconv_pair (user_a, user_b),
  KEY ix_cconv_b (user_b)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS community_dm_messages (
  id               INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  conversation_id  INT UNSIGNED NOT NULL,
  sender_id        INT UNSIGNED NOT NULL,
  body             TEXT         NULL,
  reply_to_id      INT UNSIGNED NULL,
  client_key       VARCHAR(40)  NULL,
  edited_at        DATETIME     NULL,
  deleted_at       DATETIME     NULL,
  created_at       DATETIME     NOT NULL,
  updated_at       DATETIME     NOT NULL,
  KEY ix_cdm_conv (conversation_id, id),
  KEY ix_cdm_changed (conversation_id, updated_at),
  KEY ix_cdm_sender (sender_id, created_at),
  UNIQUE KEY uq_cdm_client (sender_id, client_key),
  CONSTRAINT fk_cdm_conv FOREIGN KEY (conversation_id) REFERENCES community_conversations(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS community_blocks (
  user_id     INT UNSIGNED NOT NULL,
  blocked_id  INT UNSIGNED NOT NULL,
  created_at  DATETIME     NOT NULL,
  PRIMARY KEY (user_id, blocked_id),
  KEY ix_cb_blocked (blocked_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
--  6. Settings, presence, notifications
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS community_settings (
  user_id               INT UNSIGNED NOT NULL PRIMARY KEY,
  dm_policy             VARCHAR(12)  NOT NULL DEFAULT 'everyone',  -- everyone, moderators, nobody
  avatar_file_id        INT UNSIGNED NULL,
  notify_mentions       TINYINT(1)   NOT NULL DEFAULT 1,
  notify_dm             TINYINT(1)   NOT NULL DEFAULT 1,
  notify_announcements  TINYINT(1)   NOT NULL DEFAULT 1,
  notify_inquiries      TINYINT(1)   NOT NULL DEFAULT 1,
  last_seen_at          DATETIME     NULL,
  updated_at            DATETIME     NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS community_notifications (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  user_id     INT UNSIGNED NOT NULL,
  kind        VARCHAR(20)  NOT NULL,     -- mention, reply, dm, response, official, accepted, announcement, resolved
  actor_id    INT UNSIGNED NULL,
  text        VARCHAR(255) NOT NULL,
  url         VARCHAR(255) NOT NULL,
  dedupe_key  VARCHAR(80)  NOT NULL,     -- one notification per thing: a second one only refreshes it
  is_read     TINYINT(1)   NOT NULL DEFAULT 0,
  created_at  DATETIME     NOT NULL,
  UNIQUE KEY uq_cn_dedupe (user_id, dedupe_key),
  KEY ix_cn_user (user_id, is_read, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
--  7. Reports, mutes and suspensions, the moderation log
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS community_reports (
  id              INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  reporter_id     INT UNSIGNED NOT NULL,
  target_type     VARCHAR(12)  NOT NULL,     -- message, dm, inquiry, response, user
  target_id       INT UNSIGNED NOT NULL,
  target_user_id  INT UNSIGNED NULL,
  reason          VARCHAR(40)  NOT NULL,
  details         VARCHAR(500) NULL,
  snapshot        TEXT         NULL,         -- the words reported, as they were (a private message is seen only through this)
  status          VARCHAR(10)  NOT NULL DEFAULT 'open',   -- open, actioned, dismissed
  handled_by      INT UNSIGNED NULL,
  handled_at      DATETIME     NULL,
  resolution      VARCHAR(255) NULL,
  created_at      DATETIME     NOT NULL,
  KEY ix_crep_status (status, id),
  KEY ix_crep_target (target_type, target_id),
  KEY ix_crep_reporter (reporter_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS community_sanctions (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  user_id     INT UNSIGNED NOT NULL,
  kind        VARCHAR(10)  NOT NULL,         -- mute (may read, may not post), suspend (no community at all)
  reason      VARCHAR(255) NOT NULL,
  ends_at     DATETIME     NULL,             -- empty: until lifted
  created_by  INT UNSIGNED NOT NULL,
  created_at  DATETIME     NOT NULL,
  lifted_by   INT UNSIGNED NULL,
  lifted_at   DATETIME     NULL,
  KEY ix_cs_user (user_id, kind)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS community_mod_log (
  id              INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  moderator_id    INT UNSIGNED NOT NULL,
  action          VARCHAR(30)  NOT NULL,
  target_type     VARCHAR(20)  NULL,
  target_id       INT UNSIGNED NULL,
  target_user_id  INT UNSIGNED NULL,
  reason          VARCHAR(255) NULL,
  detail          TEXT         NULL,
  created_at      DATETIME     NOT NULL,
  KEY ix_cml_created (created_at),
  KEY ix_cml_target_user (target_user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
--  8. The six channels and six inquiry categories
-- ---------------------------------------------------------------------

INSERT IGNORE INTO community_channels (slug, name, description, kind, post_policy, sort_order, created_at) VALUES
  ('general', 'General Discussion', 'Everyday conversations and community interactions.', 'chat', 'everyone', 10, NOW()),
  ('questions', 'Questions and Inquiries', 'General questions that need answers.', 'chat', 'everyone', 20, NOW()),
  ('help', 'Help and Support', 'Help with the system, your account or a technical problem.', 'chat', 'everyone', 30, NOW()),
  ('announcements', 'Announcements', 'Important updates from the administrators.', 'announcement', 'moderators', 40, NOW()),
  ('suggestions', 'Suggestions and Feedback', 'Recommendations and requests for improvement.', 'chat', 'everyone', 50, NOW()),
  ('concerns', 'Community Concerns', 'Questions and concerns that can be discussed openly.', 'chat', 'everyone', 60, NOW());

INSERT IGNORE INTO community_inquiry_categories (name, description, sort_order) VALUES
  ('General', 'Anything that does not fit another category', 10),
  ('Accounts and Access', 'Log-in, passwords, roles and page access', 20),
  ('Transactions', 'Entering, editing and voiding documents', 30),
  ('Reports', 'Running, reading and printing reports', 40),
  ('Technical Issues', 'Errors, slowness and things that do not work', 50),
  ('Suggestions', 'Ideas to make the system better', 60);

-- ---------------------------------------------------------------------
--  9. The Community menu and its pages
-- ---------------------------------------------------------------------

INSERT IGNORE INTO modules (code, name, icon, sort_order) VALUES ('comm', 'Community', 'chat-dots', 12);
SET @comm = (SELECT id FROM modules WHERE code = 'comm' LIMIT 1);
SET @comm_sort = (SELECT COALESCE(MAX(sort_order), 900) FROM pages);

INSERT IGNORE INTO pages (page_key, module_id, name, page_type, menu_group, sort_order, show_in_menu) VALUES
  ('comm.chat', @comm, 'Community Chat', 'center', 'Community', @comm_sort + 10, 1),
  ('comm.inquiries', @comm, 'Questions & Inquiries', 'center', 'Community', @comm_sort + 20, 1),
  ('comm.manage', @comm, 'Community Management', 'admin', 'Moderation', @comm_sort + 30, 1);

-- every role reads the community; the roles that may create anything anywhere may also post (edit and delete their own)
INSERT IGNORE INTO role_page_access (role_id, page_id, allowed, can_create, can_edit, can_delete, can_print, can_approve)
SELECT r.id, p.id, 1,
       IF(EXISTS (SELECT 1 FROM role_page_access x WHERE x.role_id = r.id AND x.can_create = 1), 1, 0),
       IF(EXISTS (SELECT 1 FROM role_page_access x WHERE x.role_id = r.id AND x.can_create = 1), 1, 0),
       IF(EXISTS (SELECT 1 FROM role_page_access x WHERE x.role_id = r.id AND x.can_create = 1), 1, 0),
       0, 0
  FROM roles r
  JOIN pages p ON p.page_key IN ('comm.chat', 'comm.inquiries');

-- moderators: the roles that may open User Accounts, with all the rights of the page
INSERT IGNORE INTO role_page_access (role_id, page_id, allowed, can_create, can_edit, can_delete, can_print, can_approve)
SELECT src.role_id, dst.id, 1, 1, 1, 1, 1, 0
  FROM role_page_access src
  JOIN pages sp  ON sp.id = src.page_id AND sp.page_key = 'admin.users'
  JOIN pages dst ON dst.page_key = 'comm.manage'
 WHERE src.allowed = 1;

-- ---------------------------------------------------------------------
--  10. Record the change in the audit trail
-- ---------------------------------------------------------------------

INSERT INTO audit_trail (username, user_roles, ip_address, workstation, module, page_key, action, record_type, record_ref, reason)
VALUES ('system', 'Database migration', '127.0.0.1', 'SQL migration', 'admin', 'admin.page_access', 'access_change', 'page',
        'Community',
        'Migration 2027_02_04: the Community tables, six channels and six inquiry categories; Community Chat and Questions & Inquiries for every role, Community Management for the roles of User Accounts');

-- Done. Next steps in the application:
--   Community > Community Chat, Questions & Inquiries; Community > Community Management for the moderators.
