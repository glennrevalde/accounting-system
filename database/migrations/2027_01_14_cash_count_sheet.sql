-- =====================================================================
--  G-SMaRT Accounting - migration: Cash Count Sheet (v38)
--
--  What it changes
--    1. A new table pos_cash_counts: the bills and coins counted in the drawer
--       when a POS shift is closed (one row per denomination: 1,000 to 0.01),
--       with the quantity and the amount. Empty at first.
--    2. A new report under Point of Sale > Reports:
--         Cash Count Sheet   the bills and coins counted for each completed
--                            shift, with the date cover and the cashier
--       for the roles that may open the X- and Z-Reading Summary, and for the
--       cashiers (the roles that may open Shifts, Cash Drops & Readings), who
--       see their own shifts.
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
--    or:         mysql -u root -p accounting_system < 2027_01_14_cash_count_sheet.sql
-- =====================================================================

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------
--  1. The bills and coins counted
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS pos_cash_counts (
  id            INT UNSIGNED  NOT NULL AUTO_INCREMENT PRIMARY KEY,
  shift_id      INT UNSIGNED  NOT NULL,
  kind          VARCHAR(5)    NOT NULL DEFAULT 'bill',   -- bill or coin
  denomination  DECIMAL(10,2) NOT NULL,
  qty           INT           NOT NULL DEFAULT 0,
  amount        DECIMAL(15,2) NOT NULL DEFAULT 0,
  counted_by    INT UNSIGNED  NULL,
  created_at    TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_pcc_shift (shift_id),
  CONSTRAINT fk_pcc_shift FOREIGN KEY (shift_id) REFERENCES pos_shifts(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
--  2. The report
-- ---------------------------------------------------------------------

SET @ccs_pos  = (SELECT id FROM modules WHERE code = 'pos' LIMIT 1);
SET @ccs_sort = (SELECT COALESCE(MAX(sort_order), 700) FROM pages WHERE page_key IN ('rpt.pos_readings', 'rpt.pos_ending_inventory'));

INSERT IGNORE INTO pages (page_key, module_id, name, page_type, menu_group, sort_order, show_in_menu) VALUES
  ('rpt.pos_cash_count', @ccs_pos, 'Cash Count Sheet', 'report', 'Reports', @ccs_sort + 1, 1);

-- the roles of the X- and Z-Reading Summary, with their print right
INSERT IGNORE INTO role_page_access (role_id, page_id, allowed, can_create, can_edit, can_delete, can_print, can_approve)
SELECT src.role_id, dst.id, 1, 0, 0, 0, src.can_print, 0
  FROM role_page_access src
  JOIN pages sp  ON sp.id = src.page_id AND sp.page_key = 'rpt.pos_readings'
  JOIN pages dst ON dst.page_key = 'rpt.pos_cash_count'
 WHERE src.allowed = 1;

-- the cashiers (the roles that may open Shifts, Cash Drops & Readings): open and print their own
INSERT IGNORE INTO role_page_access (role_id, page_id, allowed, can_create, can_edit, can_delete, can_print, can_approve)
SELECT src.role_id, dst.id, 1, 0, 0, 0, 1, 0
  FROM role_page_access src
  JOIN pages sp  ON sp.id = src.page_id AND sp.page_key = 'pos.shifts'
  JOIN pages dst ON dst.page_key = 'rpt.pos_cash_count'
 WHERE src.allowed = 1;

-- ---------------------------------------------------------------------
--  3. Record the change in the audit trail
-- ---------------------------------------------------------------------

INSERT INTO audit_trail (username, user_roles, ip_address, workstation, module, page_key, action, record_type, record_ref, reason)
VALUES ('system', 'Database migration', '127.0.0.1', 'SQL migration', 'admin', 'admin.page_access', 'access_change', 'page',
        'Cash Count Sheet',
        'Migration 2027_01_14: table pos_cash_counts; Cash Count Sheet report for the POS report roles and the cashiers');

-- Done. Next steps in the application:
--   Shifts, Cash Drops & Readings > Close register: click Cash counted in drawer to fill in the Cash Count Sheet.
--   Point of Sale > Reports > Cash Count Sheet.
