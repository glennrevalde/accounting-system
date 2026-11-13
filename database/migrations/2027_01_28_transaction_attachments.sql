-- =====================================================================
--  G-SMaRT Accounting - migration: attachments on transactions (v40)
--
--  What it changes
--    1. A new table txn_attachments: the files attached to a transaction
--       (the signed copy of a voucher, bill, purchase order, sales order or
--       invoice and the documents that go with it): the file name, its type
--       and size, who attached it and when. Empty at first.
--    2. A new table txn_attachment_chunks: the content of each file, kept in
--       the database in pieces of 256 KB, so a file of any size is saved and
--       read back under MySQL's usual packet limit (max_allowed_packet).
--  Deleting a transaction deletes its attachments with it.
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
--    or:         mysql -u root -p accounting_system < 2027_01_28_transaction_attachments.sql
-- =====================================================================

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------
--  1. The files attached to a transaction
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS txn_attachments (
  id              INT UNSIGNED    NOT NULL AUTO_INCREMENT PRIMARY KEY,
  transaction_id  BIGINT UNSIGNED NULL,                 -- empty while the form is not saved yet
  stage_key       VARCHAR(40)     NULL,                 -- the form session of a file not saved yet
  file_name       VARCHAR(255)    NOT NULL,
  mime_type       VARCHAR(150)    NOT NULL DEFAULT 'application/octet-stream',
  file_size       BIGINT UNSIGNED NOT NULL DEFAULT 0,
  sha1            CHAR(40)        NULL,
  chunks          INT UNSIGNED    NOT NULL DEFAULT 0,
  uploaded_by     INT UNSIGNED    NULL,
  uploaded_at     TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_ta_txn (transaction_id),
  KEY ix_ta_stage (stage_key),
  CONSTRAINT fk_ta_txn FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
--  2. The content of the files, in pieces
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS txn_attachment_chunks (
  attachment_id  INT UNSIGNED NOT NULL,
  seq            INT UNSIGNED NOT NULL,
  data           MEDIUMBLOB   NOT NULL,
  PRIMARY KEY (attachment_id, seq),
  CONSTRAINT fk_tac_att FOREIGN KEY (attachment_id) REFERENCES txn_attachments(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
--  3. Record the change in the audit trail
-- ---------------------------------------------------------------------

INSERT INTO audit_trail (username, user_roles, ip_address, workstation, module, page_key, action, record_type, record_ref, reason)
VALUES ('system', 'Database migration', '127.0.0.1', 'SQL migration', 'admin', 'admin.page_access', 'access_change', 'page',
        'Attachments',
        'Migration 2027_01_28: tables txn_attachments and txn_attachment_chunks for the files attached to transactions');

-- Done. Next steps in the application:
--   Make Journal Entries, Write Checks, Cash Voucher, Enter Bills, Create Purchase Orders, Create Sales Orders and
--   Create Invoices have an Attachments box; a saved one shows its files, with Add files, on its page.
