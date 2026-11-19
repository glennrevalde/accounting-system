-- =====================================================================
--  G-SMaRT Accounting - migration: Digital Voucher Signatures (v42)
--
--  What it changes
--    1. voucher_sign_requests: the "Request Signature" links. Each link is
--       for one signature line (Prepared by, Checked by, Approved by or
--       Received by) of one voucher and one named signer. Only a SHA-256
--       fingerprint of the secret part of the link is kept to find it, so a
--       copy of the database does not give working links. A link expires,
--       can be revoked, and is used once.
--    2. voucher_signatures: the signatures drawn on a voucher, by a user
--       in the system or by the person a link was sent to: the strokes of
--       the signature, who signed which line, when, from which address, and
--       the fingerprint of the voucher content that was signed. A signature
--       that was reset is kept (is_active empty) with who reset it and why.
--    3. voucher_documents and voucher_document_chunks: the PDF copies. The
--       original unsigned voucher is kept when it is first signed, and every
--       signature saves a new signed copy (version 1, 2, ...).
--    4. A line in the audit trail.
--
--  The vouchers that are signed: Write Checks (Check Voucher), Cash Voucher
--  and Journal Entry. Nothing else changes; no amount changes.
--
--  For an EXISTING database that already has the earlier migrations.
--  New installs do not need it (tools/install.php and the bundled dumps include it).
--  Safe to run more than once. Works on MySQL 5.5.3+ and MariaDB 5.5+.
--
--  How to run (back up the database first):
--    phpMyAdmin: click the accounting_system database > Import > choose this file > Go
--    Navicat:    right-click the accounting_system database > Execute SQL File
--    or:         mysql -u root -p accounting_system < 2027_02_11_voucher_signatures.sql
-- =====================================================================

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------
--  1. Signature request links
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS voucher_sign_requests (
  id               INT UNSIGNED    NOT NULL AUTO_INCREMENT PRIMARY KEY,
  transaction_id   BIGINT UNSIGNED NOT NULL,
  slot             VARCHAR(12)     NOT NULL,                 -- prepared, checked, approved, received
  signer_name      VARCHAR(120)    NOT NULL,
  signer_email     VARCHAR(160)    NULL,
  message          VARCHAR(255)    NULL,
  token_hash       CHAR(64)        NOT NULL,                 -- SHA-256 of the secret part of the link
  token_enc        VARCHAR(255)    NULL,                     -- the link, encrypted, so it can be copied again
  status           VARCHAR(10)     NOT NULL DEFAULT 'pending', -- pending, signed, revoked, expired
  expires_at       DATETIME        NOT NULL,
  created_by       INT UNSIGNED    NULL,
  created_at       DATETIME        NOT NULL,
  first_opened_at  DATETIME        NULL,
  last_opened_at   DATETIME        NULL,
  open_count       INT UNSIGNED    NOT NULL DEFAULT 0,
  revoked_by       INT UNSIGNED    NULL,
  revoked_at       DATETIME        NULL,
  revoke_reason    VARCHAR(255)    NULL,
  signed_at        DATETIME        NULL,
  signature_id     INT UNSIGNED    NULL,
  UNIQUE KEY uq_vsr_token (token_hash),
  KEY ix_vsr_txn (transaction_id, status),
  CONSTRAINT fk_vsr_txn FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
--  2. The signatures
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS voucher_signatures (
  id               INT UNSIGNED    NOT NULL AUTO_INCREMENT PRIMARY KEY,
  transaction_id   BIGINT UNSIGNED NOT NULL,
  slot             VARCHAR(12)     NOT NULL,
  signer_name      VARCHAR(120)    NOT NULL,
  signer_user_id   INT UNSIGNED    NULL,                     -- signed in the system
  request_id       INT UNSIGNED    NULL,                     -- signed through a link
  method           VARCHAR(8)      NOT NULL DEFAULT 'internal', -- internal, link
  strokes          MEDIUMTEXT      NOT NULL,                 -- the drawing: {"w":..,"h":..,"s":[[x,y,x,y,...],...]}
  doc_hash         CHAR(64)        NOT NULL,                 -- SHA-256 of the voucher content that was signed
  ip_address       VARCHAR(45)     NULL,
  user_agent       VARCHAR(255)    NULL,
  signed_at        DATETIME        NOT NULL,
  is_active        TINYINT(1)      NULL DEFAULT 1,           -- 1 = on the voucher; empty once reset
  cleared_by       INT UNSIGNED    NULL,
  cleared_at       DATETIME        NULL,
  clear_reason     VARCHAR(255)    NULL,
  UNIQUE KEY uq_vs_slot (transaction_id, slot, is_active),  -- one active signature per line
  KEY ix_vs_user (signer_user_id),
  CONSTRAINT fk_vs_txn FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
--  3. The PDF copies: the original unsigned voucher and each signed copy
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS voucher_documents (
  id               INT UNSIGNED    NOT NULL AUTO_INCREMENT PRIMARY KEY,
  transaction_id   BIGINT UNSIGNED NOT NULL,
  kind             VARCHAR(8)      NOT NULL,                 -- original, signed
  version          INT UNSIGNED    NOT NULL DEFAULT 1,
  file_name        VARCHAR(160)    NOT NULL,
  file_size        INT UNSIGNED    NOT NULL DEFAULT 0,
  sha256           CHAR(64)        NOT NULL,
  doc_hash         CHAR(64)        NULL,
  signature_count  TINYINT UNSIGNED NOT NULL DEFAULT 0,
  chunks           INT UNSIGNED    NOT NULL DEFAULT 0,
  created_by       INT UNSIGNED    NULL,
  created_note     VARCHAR(160)    NULL,
  created_at       DATETIME        NOT NULL,
  KEY ix_vd_txn (transaction_id, kind, version),
  CONSTRAINT fk_vd_txn FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS voucher_document_chunks (
  document_id  INT UNSIGNED NOT NULL,
  seq          INT UNSIGNED NOT NULL,
  data         MEDIUMBLOB   NOT NULL,
  PRIMARY KEY (document_id, seq),
  CONSTRAINT fk_vdc_doc FOREIGN KEY (document_id) REFERENCES voucher_documents(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
--  4. Record the change in the audit trail
-- ---------------------------------------------------------------------

INSERT INTO audit_trail (username, user_roles, ip_address, workstation, module, page_key, action, record_type, record_ref, reason)
VALUES ('system', 'Database migration', '127.0.0.1', 'SQL migration', 'admin', 'admin.page_access', 'access_change', 'page',
        'Voucher signatures',
        'Migration 2027_02_11: tables voucher_sign_requests, voucher_signatures, voucher_documents and voucher_document_chunks for signing vouchers');

-- Done. Next steps in the application:
--   Open a check (Write Checks), a cash voucher or a journal entry: the Signatures box has
--   Sign Voucher and Request Signature.
