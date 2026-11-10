-- =====================================================================
--  G-SMaRT Accounting - migration: FB POS (food and beverage counter)
--
--  What it changes
--    1. Four columns on items, for the FB POS:
--         fb_pos        1 = shown on the FB POS (default 0)
--         fb_group_id   the FB POS group (menu tab) it is shown under
--         fb_sort       its order within the group
--         image_file    the picture of the item (the file is kept in storage/items)
--    2. A new table fb_pos_groups: the menu groups of the FB POS (for example Burgers,
--       Fries & Sides, Drinks, Combo Meals), named and ordered by the user.
--    3. Two new pages under Point of Sale:
--         FB POS                    for the roles that may open the POS Register, with the same rights
--         FB POS Menu & Groups      for the roles that may open POS Terminals, with the same rights
--
--  Nothing is deleted and no amount changes. No item is shown on the FB POS until it
--  is ticked (Item List > the item > FB POS, or Point of Sale > FB POS Menu & Groups).
--
--  For an EXISTING database that already has the earlier migrations.
--  New installs do not need it (tools/install.php and the bundled dumps include it).
--  Safe to run more than once. Works on MySQL 5.5.3+ and MariaDB 5.5+.
--
--  How to run (back up the database first):
--    phpMyAdmin: click the accounting_system database > Import > choose this file > Go
--    Navicat:    right-click the accounting_system database > Execute SQL File
--    or:         mysql -u root -p accounting_system < 2026_12_24_fb_pos.sql
-- =====================================================================

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------
--  1. The menu groups and the item columns
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS fb_pos_groups (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name        VARCHAR(60)  NOT NULL,
  sort_order  INT          NOT NULL DEFAULT 0,
  is_active   TINYINT(1)   NOT NULL DEFAULT 1,
  created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_fb_group_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET @sql = (SELECT IF(COUNT(*) = 0,
  'ALTER TABLE items ADD COLUMN fb_pos TINYINT(1) NOT NULL DEFAULT 0 AFTER is_active, ADD COLUMN fb_group_id INT UNSIGNED NULL AFTER fb_pos, ADD COLUMN fb_sort INT NOT NULL DEFAULT 0 AFTER fb_group_id, ADD COLUMN image_file VARCHAR(120) NULL AFTER fb_sort, ADD KEY ix_items_fb (fb_pos, fb_group_id)',
  'SELECT ''items: FB POS columns already exist''')
  FROM information_schema.columns
 WHERE table_schema = DATABASE() AND table_name = 'items' AND column_name = 'fb_pos');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- ---------------------------------------------------------------------
--  2. The two pages
-- ---------------------------------------------------------------------

SET @fb_pos  = (SELECT id FROM modules WHERE code = 'pos' LIMIT 1);
SET @fb_reg  = (SELECT COALESCE(MAX(sort_order), 1400) FROM pages WHERE page_key = 'pos.register');
SET @fb_term = (SELECT COALESCE(MAX(sort_order), 1440) FROM pages WHERE page_key = 'pos.terminals');

INSERT IGNORE INTO pages (page_key, module_id, name, page_type, menu_group, sort_order, show_in_menu) VALUES
  ('pos.fb',      @fb_pos, 'FB POS',               'transaction', 'Transactions', @fb_reg + 5,  1),
  ('pos.fb_menu', @fb_pos, 'FB POS Menu & Groups', 'setup',       'Setup',        @fb_term + 5, 1);

INSERT IGNORE INTO role_page_access (role_id, page_id, allowed, can_create, can_edit, can_delete, can_print, can_approve)
SELECT src.role_id, dst.id, src.allowed, src.can_create, src.can_edit, src.can_delete, src.can_print, src.can_approve
  FROM role_page_access src
  JOIN pages sp  ON sp.id = src.page_id AND sp.page_key = 'pos.register'
  JOIN pages dst ON dst.page_key = 'pos.fb'
 WHERE src.allowed = 1;

INSERT IGNORE INTO role_page_access (role_id, page_id, allowed, can_create, can_edit, can_delete, can_print, can_approve)
SELECT src.role_id, dst.id, src.allowed, src.can_create, src.can_edit, src.can_delete, src.can_print, src.can_approve
  FROM role_page_access src
  JOIN pages sp  ON sp.id = src.page_id AND sp.page_key = 'pos.terminals'
  JOIN pages dst ON dst.page_key = 'pos.fb_menu'
 WHERE src.allowed = 1;

-- ---------------------------------------------------------------------
--  3. Record the change in the audit trail
-- ---------------------------------------------------------------------

INSERT INTO audit_trail (username, user_roles, ip_address, workstation, module, page_key, action, record_type, record_ref, reason)
VALUES ('system', 'Database migration', '127.0.0.1', 'SQL migration', 'admin', 'admin.page_access', 'access_change', 'page',
        'FB POS; FB POS Menu & Groups',
        'Migration 2026_12_24: FB POS columns on items, table fb_pos_groups, pages FB POS and FB POS Menu & Groups');
