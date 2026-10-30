-- =====================================================================
--  G-SMaRT Accounting - clean database (setup lists and users, no transactions)
--  Generated 2026-10-17 00:06:43 +08:00 from database `accounting_system`
--  74 tables, 1080 rows (0 transactions)
--
--  Import:  phpMyAdmin > Import > choose this file > Go
--      or:  mysql -u root -p < accounting_system.sql
--  Works on MySQL 5.5.3 or newer (5.5, 5.6, 5.7, 8.x) and MariaDB 5.5 or newer.
--  Import as root (or a user with CREATE, INSERT, REFERENCES and TRIGGER privileges).
--  WARNING: importing drops and recreates every table in the database below.
--
--  Default login: admin / Admin@12345 (a new password is required at first login)
-- =====================================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;
SET SQL_MODE = 'NO_AUTO_VALUE_ON_ZERO';
SET time_zone = '+08:00';

CREATE DATABASE IF NOT EXISTS `accounting_system` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `accounting_system`;

-- ---------------------------------------------------------------------
--  1. TABLES
-- ---------------------------------------------------------------------
-- =====================================================================
--  G-SMaRT Accounting - database schema
--  MySQL 5.5.3+ / 5.6 / 5.7 / 8.x and MariaDB 5.5+ (XAMPP / WAMP / Laragon)
--  MySQL 5.5 rules followed here: only TIMESTAMP columns default to
--  CURRENT_TIMESTAMP (one per table), indexed text columns stay within
--  767 bytes (utf8mb4), and foreign key columns match exactly.
-- =====================================================================


-- ---------------------------------------------------------------------
--  SYSTEM ADMINISTRATION AND SECURITY
-- ---------------------------------------------------------------------

DROP TABLE IF EXISTS settings;
CREATE TABLE settings (
  setting_key   VARCHAR(60)  NOT NULL PRIMARY KEY,
  setting_value TEXT         NULL,
  updated_at    TIMESTAMP    NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS users;
CREATE TABLE users (
  id                   INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  username             VARCHAR(50)  NOT NULL,
  password_hash        VARCHAR(255) NOT NULL,
  full_name            VARCHAR(120) NOT NULL,
  email                VARCHAR(120) NULL,
  employee_no          VARCHAR(30)  NULL,
  pos_default_site_id  INT UNSIGNED NULL,                 -- the site this user's POS Register opens on
  pos_default_class_id INT UNSIGNED NULL,                 -- the class every new sale of theirs starts with
  status               ENUM('active','inactive','locked') NOT NULL DEFAULT 'active',
  approval_status      VARCHAR(10)  NOT NULL DEFAULT 'approved',  -- approved / pending / rejected (joined with the Company Code)
  created_via          VARCHAR(12)  NOT NULL DEFAULT 'admin',     -- admin / registration / provisioning / setup / platform
  approved_by          INT UNSIGNED NULL,                         -- who approved or rejected the registration
  approved_at          DATETIME     NULL,
  rejected_reason      VARCHAR(255) NULL,
  is_platform          TINYINT(1)   NOT NULL DEFAULT 0,           -- the account a Super Admin works through inside the company
  must_change_password TINYINT(1)   NOT NULL DEFAULT 1,
  password_changed_at  DATETIME     NULL,
  failed_attempts      INT          NOT NULL DEFAULT 0,
  last_login_at        DATETIME     NULL,
  last_login_ip        VARCHAR(45)  NULL,
  created_by           INT UNSIGNED NULL,
  created_at           TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at           DATETIME     NULL,                  -- set by the application (DB::update)
  UNIQUE KEY uq_users_username (username),
  KEY ix_users_approval (approval_status),
  KEY ix_users_pos_site (pos_default_site_id),
  KEY ix_users_pos_class (pos_default_class_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS roles;
CREATE TABLE roles (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name        VARCHAR(60)  NOT NULL,
  description VARCHAR(255) NULL,
  is_admin    TINYINT(1)   NOT NULL DEFAULT 0,   -- full access to everything
  is_system   TINYINT(1)   NOT NULL DEFAULT 0,   -- standard role shipped with the system
  all_sites   TINYINT(1)   NOT NULL DEFAULT 1,   -- 0 = limited to role_sites
  created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  DATETIME     NULL,                  -- set by the application (DB::update)
  UNIQUE KEY uq_roles_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS user_roles;
CREATE TABLE user_roles (
  user_id INT UNSIGNED NOT NULL,
  role_id INT UNSIGNED NOT NULL,
  PRIMARY KEY (user_id, role_id),
  CONSTRAINT fk_ur_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_ur_role FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS modules;
CREATE TABLE modules (
  id         INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  code       VARCHAR(20)  NOT NULL,
  name       VARCHAR(80)  NOT NULL,
  icon       VARCHAR(40)  NULL,
  sort_order INT          NOT NULL DEFAULT 0,
  UNIQUE KEY uq_modules_code (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS pages;
CREATE TABLE pages (
  id           INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  page_key     VARCHAR(60)  NOT NULL,
  module_id    INT UNSIGNED NOT NULL,
  name         VARCHAR(120) NOT NULL,
  page_type    ENUM('center','transaction','list','report','setup','admin') NOT NULL DEFAULT 'transaction',
  menu_group   VARCHAR(40)  NULL,
  sort_order   INT          NOT NULL DEFAULT 0,
  show_in_menu TINYINT(1)   NOT NULL DEFAULT 1,
  description  VARCHAR(255) NULL,
  UNIQUE KEY uq_pages_key (page_key),
  CONSTRAINT fk_pages_module FOREIGN KEY (module_id) REFERENCES modules(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Page access + action permissions per role (View = allowed)
DROP TABLE IF EXISTS role_page_access;
CREATE TABLE role_page_access (
  role_id     INT UNSIGNED NOT NULL,
  page_id     INT UNSIGNED NOT NULL,
  allowed     TINYINT(1)   NOT NULL DEFAULT 0,
  can_create  TINYINT(1)   NOT NULL DEFAULT 0,
  can_edit    TINYINT(1)   NOT NULL DEFAULT 0,
  can_delete  TINYINT(1)   NOT NULL DEFAULT 0,
  can_print   TINYINT(1)   NOT NULL DEFAULT 0,
  can_approve TINYINT(1)   NOT NULL DEFAULT 0,
  PRIMARY KEY (role_id, page_id),
  CONSTRAINT fk_rpa_role FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE,
  CONSTRAINT fk_rpa_page FOREIGN KEY (page_id) REFERENCES pages(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- User-level overrides always take precedence over roles
DROP TABLE IF EXISTS user_page_overrides;
CREATE TABLE user_page_overrides (
  user_id     INT UNSIGNED NOT NULL,
  page_id     INT UNSIGNED NOT NULL,
  allowed     TINYINT(1)   NOT NULL DEFAULT 0,
  can_create  TINYINT(1)   NOT NULL DEFAULT 0,
  can_edit    TINYINT(1)   NOT NULL DEFAULT 0,
  can_delete  TINYINT(1)   NOT NULL DEFAULT 0,
  can_print   TINYINT(1)   NOT NULL DEFAULT 0,
  can_approve TINYINT(1)   NOT NULL DEFAULT 0,
  reason      VARCHAR(255) NULL,
  created_by  INT UNSIGNED NULL,
  created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, page_id),
  CONSTRAINT fk_upo_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_upo_page FOREIGN KEY (page_id) REFERENCES pages(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Sensitive permissions set separately from the grid
--  view_costs, view_bank_balances, credit_limit_override, coa_changes,
--  closed_period_changes (0/1); max_discount_pct, max_price_override_pct,
--  max_amount (number, blank = unlimited)
DROP TABLE IF EXISTS role_special_permissions;
CREATE TABLE role_special_permissions (
  role_id    INT UNSIGNED NOT NULL,
  perm_key   VARCHAR(40)  NOT NULL,
  perm_value VARCHAR(40)  NULL,
  PRIMARY KEY (role_id, perm_key),
  CONSTRAINT fk_rsp_role FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Permanent, read-only audit trail (see triggers at the end of the file)
DROP TABLE IF EXISTS audit_trail;
CREATE TABLE audit_trail (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  user_id     INT UNSIGNED NULL,
  username    VARCHAR(50)  NULL,
  user_roles  VARCHAR(255) NULL,
  ip_address  VARCHAR(45)  NULL,
  workstation VARCHAR(255) NULL,
  site_id     INT UNSIGNED NULL,
  terminal_id INT UNSIGNED NULL,
  module      VARCHAR(20)  NOT NULL,
  page_key    VARCHAR(60)  NULL,
  action      VARCHAR(30)  NOT NULL,
  record_type VARCHAR(40)  NULL,
  record_id   BIGINT       NULL,
  record_ref  VARCHAR(160) NULL,
  amount      DECIMAL(15,2) NULL,
  changes     LONGTEXT     NULL,   -- JSON [{field, old, new}]
  snapshot    LONGTEXT     NULL,   -- JSON copy of the record
  reason      VARCHAR(255) NULL,
  approved_by VARCHAR(50)  NULL,
  KEY ix_audit_date (created_at),
  KEY ix_audit_user (user_id, created_at),
  KEY ix_audit_record (record_type, record_id),
  KEY ix_audit_action (action),
  KEY ix_audit_module (module)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS memorized_reports;
CREATE TABLE memorized_reports (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name        VARCHAR(120) NOT NULL,
  group_name  VARCHAR(60)  NULL,
  report_key  VARCHAR(60)  NOT NULL,
  query_string TEXT        NULL,
  is_shared   TINYINT(1)   NOT NULL DEFAULT 0,
  schedule    VARCHAR(10)  NULL,          -- daily, weekly, monthly (tools/send_scheduled_reports.php)
  email_to    VARCHAR(255) NULL,
  last_sent_at DATETIME    NULL,
  created_by  INT UNSIGNED NOT NULL,
  created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_mr_user FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS sequences;
CREATE TABLE sequences (
  seq_key VARCHAR(30) NOT NULL PRIMARY KEY,
  prefix  VARCHAR(10) NOT NULL DEFAULT '',
  next_no INT UNSIGNED NOT NULL DEFAULT 1,
  pad     TINYINT      NOT NULL DEFAULT 5
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
--  CHART OF ACCOUNTS AND LISTS
-- ---------------------------------------------------------------------

DROP TABLE IF EXISTS accounts;
CREATE TABLE accounts (
  id              INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  code            VARCHAR(20)  NOT NULL,
  name            VARCHAR(120) NOT NULL,
  account_type    ENUM('Bank','Accounts Receivable','Other Current Asset','Fixed Asset','Other Asset',
                       'Accounts Payable','Credit Card','Other Current Liability','Long Term Liability',
                       'Equity','Income','Other Income','Cost of Goods Sold','Expense','Other Expense') NOT NULL,
  category        ENUM('Asset','Liability','Equity','Income','Expense') NOT NULL,
  normal_balance  ENUM('Debit','Credit') NOT NULL,
  parent_id       INT UNSIGNED NULL,
  description     VARCHAR(255) NULL,
  bank_account_no VARCHAR(40)  NULL,
  with_sl         TINYINT(1)   NOT NULL DEFAULT 0,    -- keeps a subsidiary ledger: every entry needs a name
  is_active       TINYINT(1)   NOT NULL DEFAULT 1,
  is_system       TINYINT(1)   NOT NULL DEFAULT 0,
  created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at      DATETIME     NULL,                  -- set by the application (DB::update)
  UNIQUE KEY uq_accounts_code (code),
  KEY ix_acc_with_sl (with_sl),
  CONSTRAINT fk_accounts_parent FOREIGN KEY (parent_id) REFERENCES accounts(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Module default accounts (ar, ap, undeposited_funds, output_tax, ...)
DROP TABLE IF EXISTS default_accounts;
CREATE TABLE default_accounts (
  setting_key VARCHAR(40)  NOT NULL PRIMARY KEY,
  label       VARCHAR(120) NOT NULL,
  module      VARCHAR(20)  NOT NULL,
  account_id  INT UNSIGNED NULL,
  CONSTRAINT fk_da_account FOREIGN KEY (account_id) REFERENCES accounts(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS terms;
CREATE TABLE terms (
  id            INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name          VARCHAR(40)  NOT NULL,
  net_days      INT          NOT NULL DEFAULT 0,
  discount_pct  DECIMAL(5,2) NOT NULL DEFAULT 0,
  discount_days INT          NOT NULL DEFAULT 0,
  is_active     TINYINT(1)   NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS tax_codes;
CREATE TABLE tax_codes (
  id                  INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  code                VARCHAR(20)  NOT NULL,
  name                VARCHAR(80)  NOT NULL,
  rate                DECIMAL(6,3) NOT NULL DEFAULT 0,
  sales_account_id    INT UNSIGNED NULL,   -- Output Tax
  purchase_account_id INT UNSIGNED NULL,   -- Input Tax
  is_active           TINYINT(1)   NOT NULL DEFAULT 1,
  UNIQUE KEY uq_tax_code (code),
  CONSTRAINT fk_tax_sales FOREIGN KEY (sales_account_id) REFERENCES accounts(id),
  CONSTRAINT fk_tax_purch FOREIGN KEY (purchase_account_id) REFERENCES accounts(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS payment_methods;
CREATE TABLE payment_methods (
  id                  INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name                VARCHAR(40)  NOT NULL,
  method_type         ENUM('cash','check','card','ewallet','bank_transfer','voucher','other') NOT NULL DEFAULT 'other',
  clearing_account_id INT UNSIGNED NULL,   -- POS clearing account for card / e-wallet / voucher / bank
  is_active           TINYINT(1)   NOT NULL DEFAULT 1,
  show_in_pos         TINYINT(1)   NOT NULL DEFAULT 1,   -- offered as a payment option at the POS register
  CONSTRAINT fk_pm_account FOREIGN KEY (clearing_account_id) REFERENCES accounts(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS price_levels;
CREATE TABLE price_levels (
  id         INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name       VARCHAR(40)  NOT NULL,
  adjust_pct DECIMAL(6,2) NOT NULL DEFAULT 0,  -- e.g. -10 = 10% below standard price
  is_active  TINYINT(1)   NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS sales_reps;
CREATE TABLE sales_reps (
  id        INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name      VARCHAR(80)  NOT NULL,
  initials  VARCHAR(10)  NULL,
  user_id   INT UNSIGNED NULL,
  commission_pct DECIMAL(5,2) NOT NULL DEFAULT 0,
  is_active TINYINT(1)   NOT NULL DEFAULT 1,
  CONSTRAINT fk_rep_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS customer_types;
CREATE TABLE customer_types (
  id   INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(60)  NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS billing_groups;
CREATE TABLE billing_groups (
  id   INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(60)  NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Class List: your own way of splitting the books (branches, departments, projects ...).
-- Every transaction can carry a class; the ledger keeps it, so financial reports can filter by it.
DROP TABLE IF EXISTS classes;
CREATE TABLE classes (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name        VARCHAR(80)  NOT NULL,
  description VARCHAR(255) NULL,
  is_active   TINYINT(1)   NOT NULL DEFAULT 1,
  sort_order  INT          NOT NULL DEFAULT 0,
  created_by  INT UNSIGNED NULL,
  created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  DATETIME     NULL,                  -- set by the application (DB::update)
  UNIQUE KEY uq_classes_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Employees and other names (payees and subsidiary ledgers that are neither customers nor vendors)
DROP TABLE IF EXISTS other_names;
CREATE TABLE other_names (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name_type   VARCHAR(10)  NOT NULL DEFAULT 'other',  -- employee, other
  name        VARCHAR(120) NOT NULL,
  employee_no VARCHAR(30)  NULL,
  position    VARCHAR(80)  NULL,
  phone       VARCHAR(40)  NULL,
  address     VARCHAR(255) NULL,
  tin         VARCHAR(30)  NULL,
  notes       VARCHAR(255) NULL,
  is_active   TINYINT(1)   NOT NULL DEFAULT 1,
  created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  DATETIME     NULL,                  -- set by the application (DB::update)
  KEY ix_other_names_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
--  CUSTOMERS AND VENDORS
-- ---------------------------------------------------------------------

DROP TABLE IF EXISTS customers;
CREATE TABLE customers (
  id                  INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  parent_id           INT UNSIGNED NULL,          -- job / project under a customer
  name                VARCHAR(120) NOT NULL,
  company_name        VARCHAR(120) NULL,
  contact_person      VARCHAR(120) NULL,
  phone               VARCHAR(40)  NULL,
  mobile              VARCHAR(40)  NULL,
  email               VARCHAR(120) NULL,
  billing_address     VARCHAR(255) NULL,
  shipping_address    VARCHAR(255) NULL,
  tin                 VARCHAR(30)  NULL,
  wht_ids             VARCHAR(100) NULL,          -- withholding taxes it usually withholds from its payments
  terms_id            INT UNSIGNED NULL,
  credit_limit        DECIMAL(15,2) NOT NULL DEFAULT 0,  -- 0 = no limit
  price_level_id      INT UNSIGNED NULL,
  tax_code_id         INT UNSIGNED NULL,
  payment_method_id   INT UNSIGNED NULL,
  customer_type_id    INT UNSIGNED NULL,
  sales_rep_id        INT UNSIGNED NULL,
  billing_group_id    INT UNSIGNED NULL,
  allow_pos_charge    TINYINT(1)   NOT NULL DEFAULT 0,  -- approved account customer at the POS
  notes               TEXT         NULL,
  is_active           TINYINT(1)   NOT NULL DEFAULT 1,
  created_at          TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at          DATETIME     NULL,                  -- set by the application (DB::update)
  KEY ix_customers_name (name),
  CONSTRAINT fk_cust_parent FOREIGN KEY (parent_id) REFERENCES customers(id),
  CONSTRAINT fk_cust_terms  FOREIGN KEY (terms_id) REFERENCES terms(id),
  CONSTRAINT fk_cust_pl     FOREIGN KEY (price_level_id) REFERENCES price_levels(id),
  CONSTRAINT fk_cust_tax    FOREIGN KEY (tax_code_id) REFERENCES tax_codes(id),
  CONSTRAINT fk_cust_pm     FOREIGN KEY (payment_method_id) REFERENCES payment_methods(id),
  CONSTRAINT fk_cust_type   FOREIGN KEY (customer_type_id) REFERENCES customer_types(id),
  CONSTRAINT fk_cust_rep    FOREIGN KEY (sales_rep_id) REFERENCES sales_reps(id),
  CONSTRAINT fk_cust_bg     FOREIGN KEY (billing_group_id) REFERENCES billing_groups(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS vendors;
CREATE TABLE vendors (
  id                         INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name                       VARCHAR(120) NOT NULL,
  company_name               VARCHAR(120) NULL,
  contact_person             VARCHAR(120) NULL,
  phone                      VARCHAR(40)  NULL,
  fax                        VARCHAR(40)  NULL,
  email                      VARCHAR(120) NULL,
  address                    VARCHAR(255) NULL,
  tin                        VARCHAR(30)  NULL,
  terms_id                   INT UNSIGNED NULL,
  credit_limit               DECIMAL(15,2) NOT NULL DEFAULT 0,
  default_expense_account_id INT UNSIGNED NULL,
  tax_code_id                INT UNSIGNED NULL,
  account_no                 VARCHAR(40)  NULL,   -- our account number with the vendor
  wht_ids                    VARCHAR(100) NULL,   -- withholding taxes usually withheld from it (withholding_taxes ids, "1,3")
  notes                      TEXT         NULL,
  is_active                  TINYINT(1)   NOT NULL DEFAULT 1,
  created_at                 TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at                 DATETIME     NULL,                  -- set by the application (DB::update)
  KEY ix_vendors_name (name),
  CONSTRAINT fk_vend_terms FOREIGN KEY (terms_id) REFERENCES terms(id),
  CONSTRAINT fk_vend_exp   FOREIGN KEY (default_expense_account_id) REFERENCES accounts(id),
  CONSTRAINT fk_vend_tax   FOREIGN KEY (tax_code_id) REFERENCES tax_codes(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS entity_notes;
CREATE TABLE entity_notes (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  entity_type ENUM('customer','vendor','item') NOT NULL,
  entity_id   INT UNSIGNED NOT NULL,
  note        TEXT         NOT NULL,
  is_todo     TINYINT(1)   NOT NULL DEFAULT 0,
  due_date    DATE         NULL,
  is_done     TINYINT(1)   NOT NULL DEFAULT 0,
  created_by  INT UNSIGNED NULL,
  created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_notes_entity (entity_type, entity_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
--  INVENTORY
-- ---------------------------------------------------------------------

DROP TABLE IF EXISTS sites;
CREATE TABLE sites (
  id        INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  code      VARCHAR(20)  NOT NULL,
  name      VARCHAR(80)  NOT NULL,
  site_type ENUM('warehouse','store','stockroom','van','damaged','other') NOT NULL DEFAULT 'warehouse',
  address   VARCHAR(255) NULL,
  is_active TINYINT(1)   NOT NULL DEFAULT 1,
  UNIQUE KEY uq_sites_code (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS item_categories;
CREATE TABLE item_categories (
  id   INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(60)  NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Units of measure: a set holds the base unit (stock and costs are kept in it)
-- plus the larger or smaller units a document may be entered in
DROP TABLE IF EXISTS uom_sets;
CREATE TABLE uom_sets (
  id         INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name       VARCHAR(60)  NOT NULL,
  uom_kind   VARCHAR(10)  NOT NULL DEFAULT 'count',  -- count, weight, volume, length, time, other
  base_unit  VARCHAR(20)  NOT NULL,
  is_active  TINYINT(1)   NOT NULL DEFAULT 1,
  created_at TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME     NULL,                  -- set by the application (DB::update)
  UNIQUE KEY uq_uom_sets_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS uom_units;
CREATE TABLE uom_units (
  id                  INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  set_id              INT UNSIGNED NOT NULL,
  code                VARCHAR(20)  NOT NULL,
  name                VARCHAR(60)  NOT NULL,
  factor              DECIMAL(15,6) NOT NULL DEFAULT 1,  -- base units in one of this unit
  is_base             TINYINT(1)   NOT NULL DEFAULT 0,
  is_sales_default    TINYINT(1)   NOT NULL DEFAULT 0,
  is_purchase_default TINYINT(1)   NOT NULL DEFAULT 0,
  sort_order          INT          NOT NULL DEFAULT 0,
  UNIQUE KEY uq_uom_units (set_id, code),
  CONSTRAINT fk_uom_units_set FOREIGN KEY (set_id) REFERENCES uom_sets(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS items;
CREATE TABLE items (
  id                   INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  item_type            ENUM('service','inventory','non_inventory','assembly','other_charge','subtotal','group','discount','payment') NOT NULL,
  code                 VARCHAR(40)  NOT NULL,
  barcode              VARCHAR(60)  NULL,
  name                 VARCHAR(120) NOT NULL,
  description          VARCHAR(255) NULL,
  purchase_description VARCHAR(255) NULL,
  category_id          INT UNSIGNED NULL,
  unit                 VARCHAR(20)  NULL,
  uom_set_id           INT UNSIGNED NULL,                  -- U/M set (blank = single unit)
  sales_uom_id         INT UNSIGNED NULL,                  -- unit offered first on sales forms
  purchase_uom_id      INT UNSIGNED NULL,                  -- unit offered first on purchase forms
  cost                 DECIMAL(15,4) NOT NULL DEFAULT 0,  -- standard purchase cost
  avg_cost             DECIMAL(15,4) NOT NULL DEFAULT 0,  -- weighted average cost
  sales_price          DECIMAL(15,4) NOT NULL DEFAULT 0,
  discount_pct         DECIMAL(6,2)  NOT NULL DEFAULT 0,  -- discount items: percent (0 = use sales_price as amount)
  income_account_id    INT UNSIGNED NULL,
  cogs_account_id      INT UNSIGNED NULL,
  asset_account_id     INT UNSIGNED NULL,
  expense_account_id   INT UNSIGNED NULL,
  tax_code_id          INT UNSIGNED NULL,
  group_variance_account_id INT UNSIGNED NULL,             -- group items: account of the group price less the consolidated price
  preferred_vendor_id  INT UNSIGNED NULL,
  reorder_point        DECIMAL(15,4) NOT NULL DEFAULT 0,
  max_stock            DECIMAL(15,4) NOT NULL DEFAULT 0,
  build_point          DECIMAL(15,4) NOT NULL DEFAULT 0,
  is_active            TINYINT(1)   NOT NULL DEFAULT 1,
  created_at           TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at           DATETIME     NULL,                  -- set by the application (DB::update)
  UNIQUE KEY uq_items_code (code),
  KEY ix_items_barcode (barcode),
  CONSTRAINT fk_items_cat    FOREIGN KEY (category_id) REFERENCES item_categories(id),
  CONSTRAINT fk_items_inc    FOREIGN KEY (income_account_id) REFERENCES accounts(id),
  CONSTRAINT fk_items_cogs   FOREIGN KEY (cogs_account_id) REFERENCES accounts(id),
  CONSTRAINT fk_items_asset  FOREIGN KEY (asset_account_id) REFERENCES accounts(id),
  CONSTRAINT fk_items_exp    FOREIGN KEY (expense_account_id) REFERENCES accounts(id),
  CONSTRAINT fk_items_tax    FOREIGN KEY (tax_code_id) REFERENCES tax_codes(id),
  CONSTRAINT fk_items_gvar   FOREIGN KEY (group_variance_account_id) REFERENCES accounts(id),
  CONSTRAINT fk_items_vendor FOREIGN KEY (preferred_vendor_id) REFERENCES vendors(id),
  CONSTRAINT fk_items_uom    FOREIGN KEY (uom_set_id) REFERENCES uom_sets(id),
  CONSTRAINT fk_items_suom   FOREIGN KEY (sales_uom_id) REFERENCES uom_units(id),
  CONSTRAINT fk_items_puom   FOREIGN KEY (purchase_uom_id) REFERENCES uom_units(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Bill of materials for assemblies, and members of group items
DROP TABLE IF EXISTS item_components;
CREATE TABLE item_components (
  parent_item_id    INT UNSIGNED NOT NULL,
  component_item_id INT UNSIGNED NOT NULL,
  qty               DECIMAL(15,4) NOT NULL DEFAULT 1,
  PRIMARY KEY (parent_item_id, component_item_id),
  CONSTRAINT fk_ic_parent FOREIGN KEY (parent_item_id) REFERENCES items(id) ON DELETE CASCADE,
  CONSTRAINT fk_ic_comp   FOREIGN KEY (component_item_id) REFERENCES items(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Processing formulas (multi-output bills of materials) for disassembly,
-- de-kitting / break-bulk and co-product / by-product processing
DROP TABLE IF EXISTS process_formulas;
CREATE TABLE process_formulas (
  id           INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  code         VARCHAR(30)  NOT NULL,
  name         VARCHAR(120) NOT NULL,
  process_type VARCHAR(20)  NOT NULL DEFAULT 'co_product',  -- disassembly, dekit, co_product
  alloc_method VARCHAR(20)  NOT NULL DEFAULT 'sales_value', -- sales_value, standard_cost, quantity, weight, percent, average_cost, manual
  site_id      INT UNSIGNED NULL,                           -- usual processing site
  description  VARCHAR(255) NULL,
  is_active    TINYINT(1)   NOT NULL DEFAULT 1,
  created_by   INT UNSIGNED NULL,
  created_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at   DATETIME     NULL,                           -- set by the application (DB::update)
  UNIQUE KEY uq_pf_code (code),
  CONSTRAINT fk_pf_site FOREIGN KEY (site_id) REFERENCES sites(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Formula lines, quantities per batch. input = consumed, output = produced, cost = labor / overhead absorbed
DROP TABLE IF EXISTS process_formula_lines;
CREATE TABLE process_formula_lines (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  formula_id  INT UNSIGNED NOT NULL,
  line_no     INT          NOT NULL DEFAULT 0,
  line_type   VARCHAR(10)  NOT NULL,                  -- input, output, cost
  item_id     INT UNSIGNED NULL,
  account_id  INT UNSIGNED NULL,                      -- cost lines: account credited
  description VARCHAR(255) NULL,
  qty         DECIMAL(15,4) NOT NULL DEFAULT 0,
  output_role VARCHAR(12)  NULL,                      -- co_product, by_product, scrap
  alloc_basis DECIMAL(15,4) NOT NULL DEFAULT 0,       -- price / weight / percent per unit, by-product value per unit, manual amount per batch
  amount      DECIMAL(15,2) NOT NULL DEFAULT 0,       -- cost lines: amount per batch
  KEY ix_pfl_formula (formula_id),
  KEY ix_pfl_item (item_id),
  CONSTRAINT fk_pfl_formula FOREIGN KEY (formula_id) REFERENCES process_formulas(id) ON DELETE CASCADE,
  CONSTRAINT fk_pfl_item    FOREIGN KEY (item_id) REFERENCES items(id),
  CONSTRAINT fk_pfl_account FOREIGN KEY (account_id) REFERENCES accounts(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS price_level_items;
CREATE TABLE price_level_items (
  price_level_id INT UNSIGNED NOT NULL,
  item_id        INT UNSIGNED NOT NULL,
  custom_price   DECIMAL(15,4) NOT NULL,
  PRIMARY KEY (price_level_id, item_id),
  CONSTRAINT fk_pli_level FOREIGN KEY (price_level_id) REFERENCES price_levels(id) ON DELETE CASCADE,
  CONSTRAINT fk_pli_item  FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS item_site_stock;
CREATE TABLE item_site_stock (
  item_id     INT UNSIGNED NOT NULL,
  site_id     INT UNSIGNED NOT NULL,
  qty_on_hand DECIMAL(15,4) NOT NULL DEFAULT 0,
  PRIMARY KEY (item_id, site_id),
  CONSTRAINT fk_iss_item FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE,
  CONSTRAINT fk_iss_site FOREIGN KEY (site_id) REFERENCES sites(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
--  TRANSACTIONS (all modules)
-- ---------------------------------------------------------------------

DROP TABLE IF EXISTS transactions;
CREATE TABLE transactions (
  id                 BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  txn_type           VARCHAR(30)  NOT NULL,
  -- estimate, sales_order, invoice, sales_receipt, statement_charge, finance_charge,
  -- payment, credit_memo, refund, purchase_order, bill, vendor_credit, item_receipt,
  -- bill_payment, check, deposit, transfer, journal, inventory_adjustment,
  -- inventory_transfer, build_assembly, pos_sale, pos_return, depreciation,
  -- asset_disposal, bank_charge, bank_interest, item_processing, cash_voucher, vendor_advance
  txn_no             VARCHAR(30)  NULL,
  txn_date           DATE         NOT NULL,
  due_date           DATE         NULL,
  ship_date          DATE         NULL,
  ref_no             VARCHAR(60)  NULL,
  customer_id        INT UNSIGNED NULL,
  vendor_id          INT UNSIGNED NULL,
  payee_name         VARCHAR(120) NULL,
  account_id         INT UNSIGNED NULL,     -- AR / AP / bank / deposit-to / from account
  account2_id        INT UNSIGNED NULL,     -- transfer-to / cash-back / adjustment account
  site_id            INT UNSIGNED NULL,
  site2_id           INT UNSIGNED NULL,     -- transfer-to site
  terms_id           INT UNSIGNED NULL,
  sales_rep_id       INT UNSIGNED NULL,
  payment_method_id  INT UNSIGNED NULL,
  billing_address    VARCHAR(255) NULL,
  shipping_address   VARCHAR(255) NULL,
  memo               VARCHAR(255) NULL,
  customer_message   VARCHAR(255) NULL,
  subtotal           DECIMAL(15,2) NOT NULL DEFAULT 0,
  tax_total          DECIMAL(15,2) NOT NULL DEFAULT 0,
  discount_amount    DECIMAL(15,2) NOT NULL DEFAULT 0,
  withholding_amount DECIMAL(15,2) NOT NULL DEFAULT 0,
  cash_back_amount   DECIMAL(15,2) NOT NULL DEFAULT 0,
  total              DECIMAL(15,2) NOT NULL DEFAULT 0,
  status             VARCHAR(20)  NOT NULL DEFAULT 'open',
  -- open, closed, paid, partial, pending, accepted, suspended, completed, void
  is_pending         TINYINT(1)   NOT NULL DEFAULT 0,
  is_voided          TINYINT(1)   NOT NULL DEFAULT 0,
  void_reason        VARCHAR(255) NULL,
  voided_by          INT UNSIGNED NULL,
  voided_at          DATETIME     NULL,
  to_be_printed      TINYINT(1)   NOT NULL DEFAULT 0,
  is_printed         TINYINT(1)   NOT NULL DEFAULT 0,
  restock            TINYINT(1)   NOT NULL DEFAULT 1,     -- credit memos / POS returns
  credit_disposition VARCHAR(10)  NULL,                   -- keep, apply, refund
  progress_pct       DECIMAL(6,2) NULL,                   -- progress invoicing
  source_txn_id      BIGINT UNSIGNED NULL,                -- converted from / refund of
  terminal_id        INT UNSIGNED NULL,
  pos_shift_id       INT UNSIGNED NULL,
  receipt_no         VARCHAR(30)  NULL,
  amount_tendered    DECIMAL(15,2) NOT NULL DEFAULT 0,
  change_given       DECIMAL(15,2) NOT NULL DEFAULT 0,
  approved_by        INT UNSIGNED NULL,
  batch_ref          VARCHAR(40)  NULL,
  process_type       VARCHAR(20)  NULL,                   -- item processing: disassembly, dekit, co_product
  alloc_method       VARCHAR(20)  NULL,                   -- item processing: cost allocation method
  process_formula_id INT UNSIGNED NULL,                   -- item processing: formula used
  process_batches    DECIMAL(15,4) NULL,                  -- item processing: formula batches run
  class_id           INT UNSIGNED NULL,                   -- class of the whole transaction (lines may override it)
  other_name_id      INT UNSIGNED NULL,                   -- payee from Employees & Other Names
  received_via       VARCHAR(12)  NULL,                   -- receipt = Receive Items, bill = Receive Items and Enter Bills
  created_by         INT UNSIGNED NULL,
  created_at         TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_by         INT UNSIGNED NULL,
  updated_at         DATETIME     NULL,                  -- set by the application (DB::update)
  KEY ix_txn_type_date (txn_type, txn_date),
  KEY ix_txn_customer (customer_id, txn_date),
  KEY ix_txn_vendor (vendor_id, txn_date),
  KEY ix_txn_status (status),
  KEY ix_txn_source (source_txn_id),
  KEY ix_txn_shift (pos_shift_id),
  KEY ix_txn_formula (process_formula_id),
  KEY ix_txn_class (class_id),
  KEY ix_txn_other_name (other_name_id),
  CONSTRAINT fk_txn_class    FOREIGN KEY (class_id) REFERENCES classes(id),
  CONSTRAINT fk_txn_other_name FOREIGN KEY (other_name_id) REFERENCES other_names(id),
  CONSTRAINT fk_txn_customer FOREIGN KEY (customer_id) REFERENCES customers(id),
  CONSTRAINT fk_txn_vendor   FOREIGN KEY (vendor_id) REFERENCES vendors(id),
  CONSTRAINT fk_txn_account  FOREIGN KEY (account_id) REFERENCES accounts(id),
  CONSTRAINT fk_txn_formula  FOREIGN KEY (process_formula_id) REFERENCES process_formulas(id) ON DELETE SET NULL,
  CONSTRAINT fk_txn_account2 FOREIGN KEY (account2_id) REFERENCES accounts(id),
  CONSTRAINT fk_txn_site     FOREIGN KEY (site_id) REFERENCES sites(id),
  CONSTRAINT fk_txn_site2    FOREIGN KEY (site2_id) REFERENCES sites(id),
  CONSTRAINT fk_txn_terms    FOREIGN KEY (terms_id) REFERENCES terms(id),
  CONSTRAINT fk_txn_rep      FOREIGN KEY (sales_rep_id) REFERENCES sales_reps(id),
  CONSTRAINT fk_txn_pm       FOREIGN KEY (payment_method_id) REFERENCES payment_methods(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS transaction_lines;
CREATE TABLE transaction_lines (
  id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  txn_id          BIGINT UNSIGNED NOT NULL,
  line_no         INT          NOT NULL DEFAULT 0,
  line_kind       VARCHAR(10)  NOT NULL DEFAULT 'item',   -- item, expense, journal, deposit, component, input, output, cost
  item_id         INT UNSIGNED NULL,
  account_id      INT UNSIGNED NULL,
  description     VARCHAR(255) NULL,
  qty             DECIMAL(15,4) NOT NULL DEFAULT 0,
  unit            VARCHAR(20)  NULL,
  uom_id          INT UNSIGNED NULL,                      -- unit the line was entered in
  uom_factor      DECIMAL(15,6) NOT NULL DEFAULT 1,       -- base units in one entered unit
  uom_qty         DECIMAL(15,4) NOT NULL DEFAULT 0,       -- quantity as entered
  uom_rate        DECIMAL(15,4) NOT NULL DEFAULT 0,       -- price as entered
  rate            DECIMAL(15,4) NOT NULL DEFAULT 0,
  discount_kind   VARCHAR(3)    NOT NULL DEFAULT 'pct',   -- pct = percent of the line, amt = amount off
  discount_pct    DECIMAL(6,2)  NOT NULL DEFAULT 0,
  discount_amount DECIMAL(15,2) NOT NULL DEFAULT 0,
  amount          DECIMAL(15,2) NOT NULL DEFAULT 0,       -- journal: + debit / - credit
  tax_code_id     INT UNSIGNED NULL,
  tax_amount      DECIMAL(15,2) NOT NULL DEFAULT 0,
  site_id         INT UNSIGNED NULL,
  customer_id     INT UNSIGNED NULL,                      -- customer:job for billable costs / journal
  vendor_id       INT UNSIGNED NULL,
  is_billable     TINYINT(1)   NOT NULL DEFAULT 0,
  billed_txn_id   BIGINT UNSIGNED NULL,                   -- invoice that billed this cost
  ref_txn_id      BIGINT UNSIGNED NULL,                   -- deposit: payment / receipt being deposited
  pos_shift_id    INT UNSIGNED NULL,                      -- deposit: the POS shift whose cash the line deposits
  source_line_id  BIGINT UNSIGNED NULL,                   -- estimate / SO / PO line
  qty_fulfilled   DECIMAL(15,4) NOT NULL DEFAULT 0,       -- SO invoiced / PO received
  amount_fulfilled DECIMAL(15,2) NOT NULL DEFAULT 0,      -- estimate progress-invoiced
  is_closed       TINYINT(1)   NOT NULL DEFAULT 0,
  cost_amount     DECIMAL(15,2) NOT NULL DEFAULT 0,       -- COGS captured at posting
  value_change    DECIMAL(15,2) NOT NULL DEFAULT 0,       -- inventory value adjustment
  output_role     VARCHAR(12)  NULL,                      -- item processing output: co_product, by_product, scrap
  alloc_basis     DECIMAL(15,4) NOT NULL DEFAULT 0,       -- item processing: price / weight / percent / value entered
  alloc_pct       DECIMAL(9,4)  NOT NULL DEFAULT 0,       -- item processing: share of the total cost
  planned_qty     DECIMAL(15,4) NULL,                     -- item processing: quantity expected by the formula
  class_id        INT UNSIGNED NULL,                      -- class of this line (blank = the transaction's class)
  other_name_id   INT UNSIGNED NULL,                      -- subsidiary ledger: employee / other name
  group_item_id   INT UNSIGNED NULL,                      -- item group sold: the group this line belongs to
  group_ref       INT UNSIGNED NULL,                      -- which group of the document (several of the same group can be on it)
  group_qty       DECIMAL(15,4) NULL,                     -- groups sold on the line's group
  group_rate      DECIMAL(15,4) NULL,                     -- price of one group
  group_role      VARCHAR(10)  NULL,                      -- member = an item of the group, variance = group price less consolidated price
  KEY ix_tl_txn (txn_id),
  KEY ix_tl_group (group_item_id),
  KEY ix_tl_item (item_id),
  KEY ix_tl_ref (ref_txn_id),
  KEY ix_tl_shift (pos_shift_id),
  KEY ix_tl_source (source_line_id),
  KEY ix_tl_class (class_id),
  KEY ix_tl_other_name (other_name_id),
  CONSTRAINT fk_tl_class   FOREIGN KEY (class_id) REFERENCES classes(id),
  CONSTRAINT fk_tl_other_name FOREIGN KEY (other_name_id) REFERENCES other_names(id),
  CONSTRAINT fk_tl_txn     FOREIGN KEY (txn_id) REFERENCES transactions(id) ON DELETE CASCADE,
  CONSTRAINT fk_tl_item    FOREIGN KEY (item_id) REFERENCES items(id),
  CONSTRAINT fk_tl_account FOREIGN KEY (account_id) REFERENCES accounts(id),
  CONSTRAINT fk_tl_tax     FOREIGN KEY (tax_code_id) REFERENCES tax_codes(id),
  CONSTRAINT fk_tl_site    FOREIGN KEY (site_id) REFERENCES sites(id),
  CONSTRAINT fk_tl_cust    FOREIGN KEY (customer_id) REFERENCES customers(id),
  CONSTRAINT fk_tl_uom     FOREIGN KEY (uom_id) REFERENCES uom_units(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Payments / credits applied to invoices and bills
DROP TABLE IF EXISTS payment_applications;
CREATE TABLE payment_applications (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  payment_txn_id BIGINT UNSIGNED NOT NULL,   -- payment, credit memo, bill payment, vendor credit
  target_txn_id  BIGINT UNSIGNED NOT NULL,   -- invoice, statement/finance charge, bill
  amount         DECIMAL(15,2) NOT NULL DEFAULT 0,
  discount       DECIMAL(15,2) NOT NULL DEFAULT 0,
  withholding    DECIMAL(15,2) NOT NULL DEFAULT 0,
  created_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_pa_payment (payment_txn_id),
  KEY ix_pa_target (target_txn_id),
  CONSTRAINT fk_pa_payment FOREIGN KEY (payment_txn_id) REFERENCES transactions(id) ON DELETE CASCADE,
  CONSTRAINT fk_pa_target  FOREIGN KEY (target_txn_id) REFERENCES transactions(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Withholding Tax Table (BIR Reports): the taxes a payment can have withheld
DROP TABLE IF EXISTS withholding_taxes;
CREATE TABLE withholding_taxes (
  id                    INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  code                  VARCHAR(20)  NOT NULL,
  atc                   VARCHAR(10)  NULL,                   -- BIR alphanumeric tax code (WC158, WC160, WV010 ...)
  name                  VARCHAR(100) NOT NULL,
  tax_kind              ENUM('income','vat') NOT NULL DEFAULT 'income',   -- expanded withholding of income tax, or VAT / business tax withheld
  rate                  DECIMAL(9,4) NOT NULL DEFAULT 0,     -- percent
  base_type             ENUM('net_of_vat','gross') NOT NULL DEFAULT 'net_of_vat',
  applies_to            ENUM('purchases','sales','both') NOT NULL DEFAULT 'both',
  payable_account_id    INT UNSIGNED NULL,                   -- withheld from suppliers (blank = module default)
  receivable_account_id INT UNSIGNED NULL,                   -- withheld by customers (blank = module default)
  description           VARCHAR(255) NULL,
  sort_order            INT          NOT NULL DEFAULT 0,
  is_active             TINYINT(1)   NOT NULL DEFAULT 1,
  created_at            TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at            DATETIME     NULL,
  UNIQUE KEY uq_wht_code (code),
  CONSTRAINT fk_wht_payable FOREIGN KEY (payable_account_id) REFERENCES accounts(id),
  CONSTRAINT fk_wht_receivable FOREIGN KEY (receivable_account_id) REFERENCES accounts(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Taxes withheld by a payment (bill payment or customer payment), by document paid and type: BIR Form 2307 and the BIR Reports
DROP TABLE IF EXISTS payment_withholdings;
CREATE TABLE payment_withholdings (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  payment_txn_id BIGINT UNSIGNED NOT NULL,
  target_txn_id  BIGINT UNSIGNED NULL,        -- the bill / invoice it was withheld on
  wht_id         INT UNSIGNED NOT NULL,
  tax_kind       ENUM('income','vat') NOT NULL DEFAULT 'income',
  atc            VARCHAR(10)  NULL,
  rate           DECIMAL(9,4) NOT NULL DEFAULT 0,
  base           DECIMAL(15,2) NOT NULL DEFAULT 0,
  amount         DECIMAL(15,2) NOT NULL DEFAULT 0,
  account_id     INT UNSIGNED NULL,
  created_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_pw_payment (payment_txn_id),
  KEY ix_pw_target (target_txn_id),
  KEY ix_pw_wht (wht_id),
  CONSTRAINT fk_pw_payment FOREIGN KEY (payment_txn_id) REFERENCES transactions(id) ON DELETE CASCADE,
  CONSTRAINT fk_pw_target  FOREIGN KEY (target_txn_id) REFERENCES transactions(id) ON DELETE SET NULL,
  CONSTRAINT fk_pw_wht     FOREIGN KEY (wht_id) REFERENCES withholding_taxes(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Item group sales (System Administration > Track Item Group Sales transactions): one row per group sold on a document
DROP TABLE IF EXISTS item_group_sales;
CREATE TABLE item_group_sales (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  txn_id         BIGINT UNSIGNED NOT NULL,
  group_ref      INT UNSIGNED NOT NULL DEFAULT 0,
  group_item_id  INT UNSIGNED NOT NULL,
  txn_type       VARCHAR(30)  NOT NULL,
  txn_date       DATE         NOT NULL,
  customer_id    INT UNSIGNED NULL,
  site_id        INT UNSIGNED NULL,
  terminal_id    INT UNSIGNED NULL,
  class_id       INT UNSIGNED NULL,
  sales_rep_id   INT UNSIGNED NULL,
  created_by     INT UNSIGNED NULL,
  qty            DECIMAL(15,4) NOT NULL DEFAULT 0,   -- groups sold
  group_price    DECIMAL(15,4) NOT NULL DEFAULT 0,   -- price of one group
  amount         DECIMAL(15,2) NOT NULL DEFAULT 0,   -- what the groups sold for (before tax)
  consolidated   DECIMAL(15,2) NOT NULL DEFAULT 0,   -- the items of the groups at their own prices
  variance       DECIMAL(15,2) NOT NULL DEFAULT 0,   -- amount less consolidated (to the price variance account)
  tax_amount     DECIMAL(15,2) NOT NULL DEFAULT 0,
  created_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_igs_txn (txn_id),
  KEY ix_igs_group (group_item_id, txn_date),
  KEY ix_igs_date (txn_type, txn_date),
  CONSTRAINT fk_igs_txn   FOREIGN KEY (txn_id) REFERENCES transactions(id) ON DELETE CASCADE,
  CONSTRAINT fk_igs_group FOREIGN KEY (group_item_id) REFERENCES items(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Card and e-wallet receipts ticked to settle on Make Deposits (v32, Details > Settle)
DROP TABLE IF EXISTS clearing_settlements;
CREATE TABLE clearing_settlements (
  id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  deposit_txn_id  BIGINT UNSIGNED NOT NULL,                -- the deposit that holds the settlement
  account_id      INT UNSIGNED    NOT NULL,                -- the card / e-wallet clearing account
  receipt_txn_id  BIGINT UNSIGNED NOT NULL,                -- the POS sale, payment or sales receipt settled
  amount          DECIMAL(15,2)   NOT NULL DEFAULT 0,      -- what of it was settled
  created_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_cs_deposit (deposit_txn_id),
  KEY ix_cs_receipt (account_id, receipt_txn_id),
  KEY ix_cs_receipt_txn (receipt_txn_id),
  CONSTRAINT fk_cs_deposit FOREIGN KEY (deposit_txn_id) REFERENCES transactions(id) ON DELETE CASCADE,
  CONSTRAINT fk_cs_receipt FOREIGN KEY (receipt_txn_id) REFERENCES transactions(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- General ledger (generated automatically by the posting engine)
DROP TABLE IF EXISTS journal_lines;
CREATE TABLE journal_lines (
  id                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  txn_id            BIGINT UNSIGNED NOT NULL,
  txn_date          DATE         NOT NULL,
  account_id        INT UNSIGNED NOT NULL,
  debit             DECIMAL(15,2) NOT NULL DEFAULT 0,
  credit            DECIMAL(15,2) NOT NULL DEFAULT 0,
  customer_id       INT UNSIGNED NULL,
  vendor_id         INT UNSIGNED NULL,
  item_id           INT UNSIGNED NULL,
  site_id           INT UNSIGNED NULL,
  class_id          INT UNSIGNED NULL,
  other_name_id     INT UNSIGNED NULL,
  memo              VARCHAR(255) NULL,
  cleared           TINYINT(1)   NOT NULL DEFAULT 0,
  reconciliation_id INT UNSIGNED NULL,
  created_at        TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_jl_account_date (account_id, txn_date),
  KEY ix_jl_txn (txn_id),
  KEY ix_jl_customer (customer_id),
  KEY ix_jl_vendor (vendor_id),
  KEY ix_jl_class (class_id, txn_date),
  KEY ix_jl_other_name (other_name_id),
  CONSTRAINT fk_jl_class   FOREIGN KEY (class_id) REFERENCES classes(id),
  CONSTRAINT fk_jl_other_name FOREIGN KEY (other_name_id) REFERENCES other_names(id),
  CONSTRAINT fk_jl_txn     FOREIGN KEY (txn_id) REFERENCES transactions(id) ON DELETE CASCADE,
  CONSTRAINT fk_jl_account FOREIGN KEY (account_id) REFERENCES accounts(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Perpetual inventory movements (generated automatically)
DROP TABLE IF EXISTS inventory_movements;
CREATE TABLE inventory_movements (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  txn_id      BIGINT UNSIGNED NOT NULL,
  txn_line_id BIGINT UNSIGNED NULL,
  txn_date    DATE         NOT NULL,
  item_id     INT UNSIGNED NOT NULL,
  site_id     INT UNSIGNED NOT NULL,
  qty         DECIMAL(15,4) NOT NULL DEFAULT 0,
  unit_cost   DECIMAL(15,4) NOT NULL DEFAULT 0,
  total_cost  DECIMAL(15,2) NOT NULL DEFAULT 0,
  qty_after   DECIMAL(15,4) NOT NULL DEFAULT 0,    -- total on hand (all sites) after the movement
  avg_after   DECIMAL(15,4) NOT NULL DEFAULT 0,    -- average cost after the movement
  created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_im_item_date (item_id, txn_date),
  KEY ix_im_txn (txn_id),
  CONSTRAINT fk_im_txn  FOREIGN KEY (txn_id) REFERENCES transactions(id) ON DELETE CASCADE,
  CONSTRAINT fk_im_item FOREIGN KEY (item_id) REFERENCES items(id),
  CONSTRAINT fk_im_site FOREIGN KEY (site_id) REFERENCES sites(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
--  VENDORS - RECEIPT MANAGEMENT
-- ---------------------------------------------------------------------

DROP TABLE IF EXISTS receipt_documents;
CREATE TABLE receipt_documents (
  id            INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  file_path     VARCHAR(255) NOT NULL,
  original_name VARCHAR(255) NULL,
  mime_type     VARCHAR(80)  NULL,
  source        ENUM('upload','email','mobile') NOT NULL DEFAULT 'upload',
  vendor_id     INT UNSIGNED NULL,
  receipt_date  DATE         NULL,
  amount        DECIMAL(15,2) NULL,
  account_id    INT UNSIGNED NULL,
  memo          VARCHAR(255) NULL,
  status        ENUM('for_review','matched','created','rejected') NOT NULL DEFAULT 'for_review',
  linked_txn_id BIGINT UNSIGNED NULL,
  uploaded_by   INT UNSIGNED NULL,
  uploaded_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  reviewed_by   INT UNSIGNED NULL,
  reviewed_at   DATETIME     NULL,
  CONSTRAINT fk_rd_vendor  FOREIGN KEY (vendor_id) REFERENCES vendors(id),
  CONSTRAINT fk_rd_account FOREIGN KEY (account_id) REFERENCES accounts(id),
  CONSTRAINT fk_rd_txn     FOREIGN KEY (linked_txn_id) REFERENCES transactions(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
--  FIXED ASSETS
-- ---------------------------------------------------------------------

DROP TABLE IF EXISTS asset_categories;
CREATE TABLE asset_categories (
  id                     INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name                   VARCHAR(80)  NOT NULL,
  asset_account_id       INT UNSIGNED NOT NULL,
  accum_dep_account_id   INT UNSIGNED NOT NULL,
  dep_expense_account_id INT UNSIGNED NOT NULL,
  default_method         ENUM('straight_line','declining_balance','units_of_production','syd') NOT NULL DEFAULT 'straight_line',
  default_life_years     DECIMAL(5,2) NOT NULL DEFAULT 5,
  is_active              TINYINT(1)   NOT NULL DEFAULT 1,
  CONSTRAINT fk_ac_asset FOREIGN KEY (asset_account_id) REFERENCES accounts(id),
  CONSTRAINT fk_ac_accum FOREIGN KEY (accum_dep_account_id) REFERENCES accounts(id),
  CONSTRAINT fk_ac_exp   FOREIGN KEY (dep_expense_account_id) REFERENCES accounts(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS asset_locations;
CREATE TABLE asset_locations (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name        VARCHAR(120) NOT NULL,
  is_active   TINYINT(1)   NOT NULL DEFAULT 1,
  created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  DATETIME     NULL,
  UNIQUE KEY uq_asset_locations_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS fixed_assets;
CREATE TABLE fixed_assets (
  id                  INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  asset_no            VARCHAR(30)  NOT NULL,
  description         VARCHAR(160) NOT NULL,
  category_id         INT UNSIGNED NOT NULL,
  location            VARCHAR(120) NULL,
  location_id         INT UNSIGNED NULL,
  site_id             INT UNSIGNED NULL,
  class_id            INT UNSIGNED NULL,      -- default class (depreciation entry when no class is chosen)
  serial_no           VARCHAR(60)  NULL,
  vendor_id           INT UNSIGNED NULL,
  acquisition_date    DATE         NOT NULL,
  cost                DECIMAL(15,2) NOT NULL,
  salvage_value       DECIMAL(15,2) NOT NULL DEFAULT 0,
  useful_life_years   DECIMAL(5,2) NOT NULL,
  method              ENUM('straight_line','declining_balance','units_of_production','syd') NOT NULL,
  db_multiplier       DECIMAL(4,2) NOT NULL DEFAULT 2.00,
  total_units         DECIMAL(15,2) NULL,      -- units of production
  unit_label          VARCHAR(30)  NULL,
  -- change in estimate: new basis applied from basis_date forward
  basis_date          DATE         NULL,
  basis_nbv           DECIMAL(15,2) NULL,
  basis_life_months   INT          NULL,
  -- existing assets: depreciation recorded before the system was used
  opening_accum_dep   DECIMAL(15,2) NOT NULL DEFAULT 0,
  opening_through     DATE         NULL,
  acquisition_txn_id  BIGINT UNSIGNED NULL,
  status              ENUM('active','fully_depreciated','disposed') NOT NULL DEFAULT 'active',
  disposal_date       DATE         NULL,
  disposal_proceeds   DECIMAL(15,2) NULL,
  disposal_txn_id     BIGINT UNSIGNED NULL,
  notes               TEXT         NULL,
  current_meter       DECIMAL(15,2) NULL,     -- odometer / running hours
  meter_unit          VARCHAR(20)  NULL,
  created_at          TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at          DATETIME     NULL,                  -- set by the application (DB::update)
  UNIQUE KEY uq_fa_no (asset_no),
  KEY ix_fa_location (location_id),
  KEY ix_fa_class (class_id),
  CONSTRAINT fk_fa_location FOREIGN KEY (location_id) REFERENCES asset_locations(id),
  CONSTRAINT fk_fa_class  FOREIGN KEY (class_id) REFERENCES classes(id),
  CONSTRAINT fk_fa_cat    FOREIGN KEY (category_id) REFERENCES asset_categories(id),
  CONSTRAINT fk_fa_site   FOREIGN KEY (site_id) REFERENCES sites(id),
  CONSTRAINT fk_fa_vendor FOREIGN KEY (vendor_id) REFERENCES vendors(id),
  CONSTRAINT fk_fa_acq    FOREIGN KEY (acquisition_txn_id) REFERENCES transactions(id) ON DELETE SET NULL,
  CONSTRAINT fk_fa_disp   FOREIGN KEY (disposal_txn_id) REFERENCES transactions(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS asset_depreciation;
CREATE TABLE asset_depreciation (
  id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  asset_id     INT UNSIGNED NOT NULL,
  period_year  SMALLINT     NOT NULL,
  period_month TINYINT      NOT NULL,
  units_used   DECIMAL(15,2) NULL,
  amount       DECIMAL(15,2) NOT NULL,
  txn_id       BIGINT UNSIGNED NOT NULL,
  created_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_ad_period (asset_id, period_year, period_month),
  CONSTRAINT fk_ad_asset FOREIGN KEY (asset_id) REFERENCES fixed_assets(id) ON DELETE CASCADE,
  CONSTRAINT fk_ad_txn   FOREIGN KEY (txn_id) REFERENCES transactions(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS asset_meter_readings;
CREATE TABLE asset_meter_readings (
  asset_id     INT UNSIGNED NOT NULL,
  period_year  SMALLINT     NOT NULL,
  period_month TINYINT      NOT NULL,
  units        DECIMAL(15,2) NOT NULL,
  entered_by   INT UNSIGNED NULL,
  entered_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (asset_id, period_year, period_month),
  CONSTRAINT fk_amr_asset FOREIGN KEY (asset_id) REFERENCES fixed_assets(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- fixed asset maintenance and preventive maintenance
DROP TABLE IF EXISTS asset_pm_schedules;
CREATE TABLE asset_pm_schedules (
  id               INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  asset_id         INT UNSIGNED NOT NULL,
  task_name        VARCHAR(160) NOT NULL,
  task_type        VARCHAR(30)  NOT NULL DEFAULT 'other',  -- registration, change_oil, cleaning, inspection, insurance, other
  interval_value   INT          NULL,                      -- repeat every N ... (NULL = one time only)
  interval_unit    VARCHAR(10)  NULL,                      -- days, weeks, months, years
  meter_interval   DECIMAL(15,2) NULL,                     -- or every N km / hours
  next_due_date    DATE         NULL,
  next_due_meter   DECIMAL(15,2) NULL,
  remind_days      INT          NOT NULL DEFAULT 14,       -- start reminding this many days before the due date
  last_done_date   DATE         NULL,
  last_done_meter  DECIMAL(15,2) NULL,
  assigned_to      VARCHAR(120) NULL,
  notes            VARCHAR(255) NULL,
  is_active        TINYINT(1)   NOT NULL DEFAULT 1,
  created_by       INT UNSIGNED NULL,
  created_at       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at       DATETIME     NULL,
  KEY ix_pm_asset (asset_id),
  KEY ix_pm_due (is_active, next_due_date),
  CONSTRAINT fk_pm_asset FOREIGN KEY (asset_id) REFERENCES fixed_assets(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS asset_maintenance;
CREATE TABLE asset_maintenance (
  id                  INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  maint_no            VARCHAR(30)  NOT NULL,
  asset_id            INT UNSIGNED NOT NULL,
  maint_date          DATE         NOT NULL,
  maint_type          VARCHAR(20)  NOT NULL DEFAULT 'repair',     -- repair, preventive, inspection, upgrade
  status              VARCHAR(20)  NOT NULL DEFAULT 'completed',  -- in_progress, completed, void
  problem             VARCHAR(255) NULL,                          -- what was reported / why
  description         TEXT         NULL,                          -- maintenance description: the work done
  vendor_id           INT UNSIGNED NULL,                          -- supplier of the parts / service
  performed_by        VARCHAR(120) NULL,                          -- mechanic, technician or shop
  ref_no              VARCHAR(60)  NULL,                          -- supplier invoice / job order no.
  meter_reading       DECIMAL(15,2) NULL,
  downtime_days       DECIMAL(7,2) NULL,
  parts_total         DECIMAL(15,2) NOT NULL DEFAULT 0,
  labor_total         DECIMAL(15,2) NOT NULL DEFAULT 0,
  tax_total           DECIMAL(15,2) NOT NULL DEFAULT 0,
  total               DECIMAL(15,2) NOT NULL DEFAULT 0,
  with_vat            TINYINT(1)   NOT NULL DEFAULT 0,
  payment_mode        VARCHAR(20)  NOT NULL DEFAULT 'none',       -- none, bill, check, cash_voucher
  pay_account_id      INT UNSIGNED NULL,                          -- bank (check) or cash account (cash voucher)
  parts_account_id    INT UNSIGNED NULL,
  labor_account_id    INT UNSIGNED NULL,
  class_id            INT UNSIGNED NULL,
  txn_id              BIGINT UNSIGNED NULL,                       -- the bill, check or cash voucher created for it
  schedule_id         INT UNSIGNED NULL,                          -- preventive maintenance task completed by this record
  next_service_date   DATE         NULL,
  notes               TEXT         NULL,
  void_reason         VARCHAR(255) NULL,
  created_by          INT UNSIGNED NULL,
  created_at          TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at          DATETIME     NULL,
  UNIQUE KEY uq_maint_no (maint_no),
  KEY ix_maint_asset (asset_id, maint_date),
  KEY ix_maint_vendor (vendor_id),
  KEY ix_maint_txn (txn_id),
  KEY ix_maint_class (class_id),
  KEY ix_maint_schedule (schedule_id),
  CONSTRAINT fk_maint_asset    FOREIGN KEY (asset_id) REFERENCES fixed_assets(id),
  CONSTRAINT fk_maint_vendor   FOREIGN KEY (vendor_id) REFERENCES vendors(id),
  CONSTRAINT fk_maint_class    FOREIGN KEY (class_id) REFERENCES classes(id),
  CONSTRAINT fk_maint_txn      FOREIGN KEY (txn_id) REFERENCES transactions(id) ON DELETE SET NULL,
  CONSTRAINT fk_maint_schedule FOREIGN KEY (schedule_id) REFERENCES asset_pm_schedules(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS asset_maintenance_parts;
CREATE TABLE asset_maintenance_parts (
  id              INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  maintenance_id  INT UNSIGNED NOT NULL,
  line_no         INT          NOT NULL DEFAULT 0,
  part_no         VARCHAR(60)  NULL,
  description     VARCHAR(200) NOT NULL,
  serial_no       VARCHAR(60)  NULL,
  model_no        VARCHAR(60)  NULL,
  size_spec       VARCHAR(60)  NULL,
  brand           VARCHAR(60)  NULL,
  qty             DECIMAL(15,4) NOT NULL DEFAULT 1,
  unit            VARCHAR(20)  NULL,
  unit_cost       DECIMAL(15,4) NOT NULL DEFAULT 0,
  amount          DECIMAL(15,2) NOT NULL DEFAULT 0,
  warranty_until  DATE         NULL,
  KEY ix_mparts_maint (maintenance_id),
  KEY ix_mparts_partno (part_no),
  CONSTRAINT fk_mparts_maint FOREIGN KEY (maintenance_id) REFERENCES asset_maintenance(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS asset_maintenance_labor;
CREATE TABLE asset_maintenance_labor (
  id              INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  maintenance_id  INT UNSIGNED NOT NULL,
  line_no         INT          NOT NULL DEFAULT 0,
  description     VARCHAR(200) NOT NULL,
  worker          VARCHAR(120) NULL,
  charge_type     VARCHAR(10)  NOT NULL DEFAULT 'hourly',   -- hourly (man-hours x rate) or bulk (one charge)
  hours           DECIMAL(9,2) NOT NULL DEFAULT 0,
  rate            DECIMAL(15,4) NOT NULL DEFAULT 0,
  amount          DECIMAL(15,2) NOT NULL DEFAULT 0,
  KEY ix_mlabor_maint (maintenance_id),
  CONSTRAINT fk_mlabor_maint FOREIGN KEY (maintenance_id) REFERENCES asset_maintenance(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS asset_maintenance_photos;
CREATE TABLE asset_maintenance_photos (
  id              INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  maintenance_id  INT UNSIGNED NOT NULL,
  file_name       VARCHAR(120) NOT NULL,      -- name inside storage/maintenance/
  original_name   VARCHAR(190) NULL,
  mime_type       VARCHAR(60)  NULL,
  file_size       INT UNSIGNED NOT NULL DEFAULT 0,
  caption         VARCHAR(190) NULL,
  uploaded_by     INT UNSIGNED NULL,
  created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_mphotos_maint (maintenance_id),
  CONSTRAINT fk_mphotos_maint FOREIGN KEY (maintenance_id) REFERENCES asset_maintenance(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS asset_pm_log;
CREATE TABLE asset_pm_log (
  id              INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  schedule_id     INT UNSIGNED NOT NULL,
  asset_id        INT UNSIGNED NOT NULL,
  task_name       VARCHAR(160) NOT NULL,
  due_date        DATE         NULL,
  done_date       DATE         NOT NULL,
  done_meter      DECIMAL(15,2) NULL,
  maintenance_id  INT UNSIGNED NULL,
  remarks         VARCHAR(255) NULL,
  done_by         INT UNSIGNED NULL,          -- the user who acknowledged that the task is complete
  created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_pmlog_schedule (schedule_id),
  KEY ix_pmlog_asset (asset_id, done_date),
  CONSTRAINT fk_pmlog_schedule FOREIGN KEY (schedule_id) REFERENCES asset_pm_schedules(id) ON DELETE CASCADE,
  CONSTRAINT fk_pmlog_asset    FOREIGN KEY (asset_id) REFERENCES fixed_assets(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ---------------------------------------------------------------------
--  POINT OF SALE
-- ---------------------------------------------------------------------

DROP TABLE IF EXISTS pos_terminals;
CREATE TABLE pos_terminals (
  id              INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  code            VARCHAR(20)  NOT NULL,
  name            VARCHAR(80)  NOT NULL,
  site_id         INT UNSIGNED NOT NULL,
  cash_account_id INT UNSIGNED NOT NULL,
  receipt_prefix  VARCHAR(10)  NOT NULL DEFAULT 'OR',
  next_receipt_no INT UNSIGNED NOT NULL DEFAULT 1,
  next_z_no       INT UNSIGNED NOT NULL DEFAULT 1,
  is_active       TINYINT(1)   NOT NULL DEFAULT 1,
  class_id        INT UNSIGNED NULL,                      -- default class of sales made at this terminal
  UNIQUE KEY uq_term_code (code),
  CONSTRAINT fk_term_class FOREIGN KEY (class_id) REFERENCES classes(id),
  CONSTRAINT fk_term_site FOREIGN KEY (site_id) REFERENCES sites(id),
  CONSTRAINT fk_term_cash FOREIGN KEY (cash_account_id) REFERENCES accounts(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS pos_shifts;
CREATE TABLE pos_shifts (
  id             INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  terminal_id    INT UNSIGNED NOT NULL,
  cashier_id     INT UNSIGNED NOT NULL,
  business_date  DATE         NOT NULL,
  opened_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  opening_float  DECIMAL(15,2) NOT NULL DEFAULT 0,
  closed_at      DATETIME     NULL,
  expected_cash  DECIMAL(15,2) NULL,
  counted_cash   DECIMAL(15,2) NULL,
  over_short     DECIMAL(15,2) NULL,
  over_short_txn_id BIGINT UNSIGNED NULL,
  deposit_txn_id BIGINT UNSIGNED NULL,
  status         ENUM('open','closed') NOT NULL DEFAULT 'open',
  closed_by      INT UNSIGNED NULL,
  corrected_by   INT UNSIGNED NULL,          -- who last corrected the closing entries (float, drops, count)
  corrected_at   DATETIME     NULL,
  KEY ix_shift_term (terminal_id, status),
  CONSTRAINT fk_shift_term FOREIGN KEY (terminal_id) REFERENCES pos_terminals(id),
  CONSTRAINT fk_shift_user FOREIGN KEY (cashier_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS pos_tenders;
CREATE TABLE pos_tenders (
  id                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  txn_id            BIGINT UNSIGNED NOT NULL,
  payment_method_id INT UNSIGNED NOT NULL,
  amount            DECIMAL(15,2) NOT NULL,     -- net amount applied to the sale (after change)
  reference         VARCHAR(60)  NULL,
  KEY ix_pt_txn (txn_id),
  CONSTRAINT fk_pt_txn FOREIGN KEY (txn_id) REFERENCES transactions(id) ON DELETE CASCADE,
  CONSTRAINT fk_pt_pm  FOREIGN KEY (payment_method_id) REFERENCES payment_methods(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS pos_cash_drops;
CREATE TABLE pos_cash_drops (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  shift_id    INT UNSIGNED NOT NULL,
  amount      DECIMAL(15,2) NOT NULL,
  reason      VARCHAR(255) NULL,
  created_by  INT UNSIGNED NOT NULL,
  approved_by INT UNSIGNED NULL,
  created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_cd_shift FOREIGN KEY (shift_id) REFERENCES pos_shifts(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS pos_readings;
CREATE TABLE pos_readings (
  id             INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  reading_type   ENUM('X','Z') NOT NULL,
  terminal_id    INT UNSIGNED NOT NULL,
  shift_id       INT UNSIGNED NOT NULL,
  z_no           INT UNSIGNED NULL,
  business_date  DATE         NOT NULL,
  first_receipt  VARCHAR(30)  NULL,
  last_receipt   VARCHAR(30)  NULL,
  sales_count    INT          NOT NULL DEFAULT 0,
  gross_sales    DECIMAL(15,2) NOT NULL DEFAULT 0,
  discounts      DECIMAL(15,2) NOT NULL DEFAULT 0,
  returns        DECIMAL(15,2) NOT NULL DEFAULT 0,
  voids          DECIMAL(15,2) NOT NULL DEFAULT 0,
  net_sales      DECIMAL(15,2) NOT NULL DEFAULT 0,
  tax            DECIMAL(15,2) NOT NULL DEFAULT 0,
  tenders_json   TEXT         NULL,
  cash_drops     DECIMAL(15,2) NOT NULL DEFAULT 0,
  expected_cash  DECIMAL(15,2) NOT NULL DEFAULT 0,
  counted_cash   DECIMAL(15,2) NULL,
  over_short     DECIMAL(15,2) NULL,
  created_by     INT UNSIGNED NOT NULL,
  created_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_pr_term  FOREIGN KEY (terminal_id) REFERENCES pos_terminals(id),
  CONSTRAINT fk_pr_shift FOREIGN KEY (shift_id) REFERENCES pos_shifts(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- One-time approval codes a supervisor generates for a cashier or clerk (used once, then expired)
DROP TABLE IF EXISTS approval_codes;
CREATE TABLE approval_codes (
  id            INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  code          VARCHAR(12)  NOT NULL,
  purpose       VARCHAR(160) NULL,
  for_user_id   INT UNSIGNED NULL,          -- the user it is meant for (NULL: any user)
  page_key      VARCHAR(60)  NULL,          -- the page it may approve on (NULL: any page the issuer may approve on)
  max_amount    DECIMAL(15,2) NULL,
  status        VARCHAR(10)  NOT NULL DEFAULT 'open',   -- open / used / expired / cancelled
  issued_by     INT UNSIGNED NOT NULL,
  issued_at     DATETIME     NOT NULL,
  expires_at    DATETIME     NOT NULL,
  used_by       INT UNSIGNED NULL,
  used_at       DATETIME     NULL,
  used_on       VARCHAR(160) NULL,
  used_txn_id   BIGINT UNSIGNED NULL,
  cancelled_by  INT UNSIGNED NULL,
  cancelled_at  DATETIME     NULL,
  UNIQUE KEY uq_approval_codes_code (code),
  KEY ix_approval_codes_status (status, expires_at),
  KEY ix_approval_codes_issued (issued_by, issued_at),
  CONSTRAINT fk_apc_issuer FOREIGN KEY (issued_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
--  BANKING
-- ---------------------------------------------------------------------

DROP TABLE IF EXISTS bank_reconciliations;
CREATE TABLE bank_reconciliations (
  id                 INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  account_id         INT UNSIGNED NOT NULL,
  statement_date     DATE         NOT NULL,
  beginning_balance  DECIMAL(15,2) NOT NULL DEFAULT 0,
  ending_balance     DECIMAL(15,2) NOT NULL DEFAULT 0,
  cleared_balance    DECIMAL(15,2) NOT NULL DEFAULT 0,
  difference         DECIMAL(15,2) NOT NULL DEFAULT 0,
  service_charge_txn_id BIGINT UNSIGNED NULL,
  interest_txn_id    BIGINT UNSIGNED NULL,
  service_charge     DECIMAL(15,2) NOT NULL DEFAULT 0,
  service_date       DATE         NULL,
  service_account_id INT UNSIGNED NULL,
  interest_earned    DECIMAL(15,2) NOT NULL DEFAULT 0,
  interest_date      DATE         NULL,
  interest_account_id INT UNSIGNED NULL,
  class_id           INT UNSIGNED NULL,
  status             ENUM('in_progress','completed') NOT NULL DEFAULT 'in_progress',
  created_by         INT UNSIGNED NULL,
  created_at         TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  completed_by       INT UNSIGNED NULL,
  completed_at       DATETIME     NULL,
  KEY ix_br_account (account_id, statement_date),
  CONSTRAINT fk_br_account FOREIGN KEY (account_id) REFERENCES accounts(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Snapshot of the items cleared in each reconciliation (used by the reports)
DROP TABLE IF EXISTS reconciliation_items;
CREATE TABLE reconciliation_items (
  reconciliation_id INT UNSIGNED NOT NULL,
  txn_id            BIGINT UNSIGNED NOT NULL,
  amount            DECIMAL(15,2) NOT NULL,   -- + deposit / - payment
  cleared           TINYINT(1)   NOT NULL DEFAULT 1,
  PRIMARY KEY (reconciliation_id, txn_id),
  CONSTRAINT fk_ri_rec FOREIGN KEY (reconciliation_id) REFERENCES bank_reconciliations(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Cleared transactions changed after reconciliation
DROP TABLE IF EXISTS reconciliation_discrepancies;
CREATE TABLE reconciliation_discrepancies (
  id                INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  reconciliation_id INT UNSIGNED NULL,
  account_id        INT UNSIGNED NOT NULL,
  txn_id            BIGINT UNSIGNED NOT NULL,
  txn_ref           VARCHAR(80)  NULL,
  change_type       VARCHAR(20)  NOT NULL,   -- amount changed, voided, deleted, uncleared
  cleared_amount    DECIMAL(15,2) NOT NULL DEFAULT 0,
  new_amount        DECIMAL(15,2) NOT NULL DEFAULT 0,
  changed_by        INT UNSIGNED NULL,
  changed_at        TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_rd_account (account_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
--  SECURITY - site and terminal assignments
-- ---------------------------------------------------------------------

DROP TABLE IF EXISTS role_sites;
CREATE TABLE role_sites (
  role_id INT UNSIGNED NOT NULL,
  site_id INT UNSIGNED NOT NULL,
  PRIMARY KEY (role_id, site_id),
  CONSTRAINT fk_rs_role FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE,
  CONSTRAINT fk_rs_site FOREIGN KEY (site_id) REFERENCES sites(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS user_sites;
CREATE TABLE user_sites (
  user_id INT UNSIGNED NOT NULL,
  site_id INT UNSIGNED NOT NULL,
  PRIMARY KEY (user_id, site_id),
  CONSTRAINT fk_us_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_us_site FOREIGN KEY (site_id) REFERENCES sites(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS user_terminals;
CREATE TABLE user_terminals (
  user_id     INT UNSIGNED NOT NULL,
  terminal_id INT UNSIGNED NOT NULL,
  PRIMARY KEY (user_id, terminal_id),
  CONSTRAINT fk_ut_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_ut_term FOREIGN KEY (terminal_id) REFERENCES pos_terminals(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ---------------------------------------------------------------------
--  Memorized transactions, budgets and forecasts, report layouts,
--  CSV imports and database backups
-- ---------------------------------------------------------------------

DROP TABLE IF EXISTS memorized_txns;
CREATE TABLE memorized_txns (
  id             INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name           VARCHAR(120) NOT NULL,
  group_name     VARCHAR(60)  NULL,
  txn_type       VARCHAR(30)  NOT NULL,
  entity_label   VARCHAR(160) NULL,               -- customer / supplier / payee, for the list
  amount         DECIMAL(15,2) NOT NULL DEFAULT 0,
  payload        LONGTEXT     NOT NULL,           -- the header and the lines of the saved transaction
  how            VARCHAR(20)  NOT NULL DEFAULT 'remind',   -- remind, auto, none (list only)
  frequency      VARCHAR(10)  NOT NULL DEFAULT 'monthly',  -- daily, weekly, months, quarterly, yearly
  every_n        INT          NOT NULL DEFAULT 1,
  next_date      DATE         NULL,
  days_in_advance INT         NOT NULL DEFAULT 5,
  remaining      INT          NULL,               -- how many are left to enter (NULL = no limit)
  end_date       DATE         NULL,
  last_entered   DATE         NULL,
  entered_count  INT          NOT NULL DEFAULT 0,
  is_active      TINYINT(1)   NOT NULL DEFAULT 1,
  notes          VARCHAR(255) NULL,
  created_by     INT UNSIGNED NULL,
  created_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at     DATETIME     NULL,
  KEY ix_mt_due (is_active, next_date),
  KEY ix_mt_type (txn_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS budgets;
CREATE TABLE budgets (
  id            INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name          VARCHAR(120) NOT NULL,
  kind          VARCHAR(10)  NOT NULL DEFAULT 'pl',   -- pl = income statement, bs = balance sheet, forecast = sales forecast
  fiscal_year   SMALLINT     NOT NULL,
  start_month   TINYINT      NOT NULL DEFAULT 1,      -- the month the fiscal year starts in
  class_id      INT UNSIGNED NULL,
  customer_id   INT UNSIGNED NULL,                    -- forecast for one customer (NULL = all customers)
  notes         VARCHAR(255) NULL,
  is_active     TINYINT(1)   NOT NULL DEFAULT 1,
  created_by    INT UNSIGNED NULL,
  created_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    DATETIME     NULL,
  UNIQUE KEY uq_budget (kind, fiscal_year, name),
  KEY ix_budget_class (class_id),
  KEY ix_budget_customer (customer_id),
  CONSTRAINT fk_budget_class    FOREIGN KEY (class_id) REFERENCES classes(id),
  CONSTRAINT fk_budget_customer FOREIGN KEY (customer_id) REFERENCES customers(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS budget_lines;
CREATE TABLE budget_lines (
  id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  budget_id    INT UNSIGNED NOT NULL,
  account_id   INT UNSIGNED NOT NULL,
  customer_id  INT UNSIGNED NULL,                 -- forecasts: the customer the amounts belong to
  period_month TINYINT      NOT NULL,             -- 1..12, counted from the start of the fiscal year
  amount       DECIMAL(15,2) NOT NULL DEFAULT 0,
  UNIQUE KEY uq_budget_line (budget_id, account_id, customer_id, period_month),
  KEY ix_bl_account (account_id),
  CONSTRAINT fk_bl_budget   FOREIGN KEY (budget_id) REFERENCES budgets(id) ON DELETE CASCADE,
  CONSTRAINT fk_bl_account  FOREIGN KEY (account_id) REFERENCES accounts(id),
  CONSTRAINT fk_bl_customer FOREIGN KEY (customer_id) REFERENCES customers(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS report_layouts;
CREATE TABLE report_layouts (
  id           INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  report_key   VARCHAR(60)  NOT NULL,
  name         VARCHAR(120) NOT NULL,
  title        VARCHAR(160) NULL,                 -- a heading of your own for the print-out
  columns      TEXT         NULL,                 -- key:Heading, one per line, in the order they print; a leading - means hidden
  options      TEXT         NULL,                 -- name=value, one per line: negatives, zeros, decimals, density and the rest
  is_shared    TINYINT(1)   NOT NULL DEFAULT 0,
  is_default   TINYINT(1)   NOT NULL DEFAULT 0,
  created_by   INT UNSIGNED NULL,
  created_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at   DATETIME     NULL,
  KEY ix_rl_report (report_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS import_batches;
CREATE TABLE import_batches (
  id            INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  import_type   VARCHAR(40)  NOT NULL,
  file_name     VARCHAR(190) NULL,
  rows_total    INT          NOT NULL DEFAULT 0,
  rows_ok       INT          NOT NULL DEFAULT 0,
  rows_failed   INT          NOT NULL DEFAULT 0,
  created_ids   LONGTEXT     NULL,                -- what the import created, so it can be traced
  messages      LONGTEXT     NULL,
  created_by    INT UNSIGNED NULL,
  created_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_ib_type (import_type, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS backup_log;
CREATE TABLE backup_log (
  id           INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  action       VARCHAR(10)  NOT NULL,             -- backup, restore
  file_name    VARCHAR(190) NOT NULL,
  file_size    BIGINT UNSIGNED NOT NULL DEFAULT 0,
  tables_count INT          NOT NULL DEFAULT 0,
  rows_count   INT          NOT NULL DEFAULT 0,
  note         VARCHAR(255) NULL,
  created_by   INT UNSIGNED NULL,
  created_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_bl_action (action, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
--  2. DATA
-- ---------------------------------------------------------------------

-- settings (46 rows)
INSERT INTO `settings` (`setting_key`,`setting_value`,`updated_at`) VALUES
('adopt_group_price','1','2026-10-17 00:06:41'),
('allow_negative_stock','1','2026-10-17 00:06:41'),
('audit_retention_years','10','2026-10-17 00:06:41'),
('bir_signatory_name','','2026-10-17 00:06:41'),
('bir_signatory_tin','','2026-10-17 00:06:41'),
('bir_signatory_title','','2026-10-17 00:06:41'),
('bir_zip_code','','2026-10-17 00:06:41'),
('bt_printer_autoprint','0','2026-10-17 00:06:41'),
('bt_printer_cut','0','2026-10-17 00:06:41'),
('bt_printer_enabled','0','2026-10-17 00:06:41'),
('bt_printer_feed','4','2026-10-17 00:06:41'),
('bt_printer_name','','2026-10-17 00:06:41'),
('bt_printer_width','32','2026-10-17 00:06:41'),
('closing_date','','2026-10-17 00:06:41'),
('company_address','123 Rizal Avenue, Makati City, Metro Manila','2026-10-17 00:06:41'),
('company_email','accounting@sampletrading.test','2026-10-17 00:06:41'),
('company_logo','','2026-10-17 00:06:41'),
('company_name','Sample Trading Company','2026-10-17 00:06:41'),
('company_phone','(02) 8123-4567','2026-10-17 00:06:41'),
('company_tin','000-123-456-000','2026-10-17 00:06:41'),
('costing_method','weighted_average','2026-10-17 00:06:41'),
('finance_charge_grace_days','0','2026-10-17 00:06:41'),
('finance_charge_min','50','2026-10-17 00:06:41'),
('finance_charge_on_charges','0','2026-10-17 00:06:41'),
('finance_charge_rate','12','2026-10-17 00:06:41'),
('fiscal_year_start_month','1','2026-10-17 00:06:41'),
('item_search_by_page','','2026-10-17 00:06:41'),
('item_search_format','code_name','2026-10-17 00:06:41'),
('large_discount_pct','10','2026-10-17 00:06:41'),
('logo_targets','','2026-10-17 00:06:41'),
('max_failed_logins','5','2026-10-17 00:06:41'),
('pos_posting_mode','per_sale','2026-10-17 00:06:41'),
('pos_receipt_footer','Thank you for shopping!\nThis serves as your official receipt.','2026-10-17 00:06:41'),
('pos_receipt_show_customer','1','2026-10-17 00:06:41'),
('pos_receipt_title','OFFICIAL RECEIPT','2026-10-17 00:06:41'),
('pos_receipt_title_charge','CHARGE INVOICE','2026-10-17 00:06:41'),
('pos_receipt_title_payment','ACKNOWLEDGEMENT RECEIPT','2026-10-17 00:06:41'),
('pos_receipt_title_return','RETURN / REFUND','2026-10-17 00:06:41'),
('pw_expiry_days','90','2026-10-17 00:06:41'),
('pw_min_length','8','2026-10-17 00:06:41'),
('pw_require_number','1','2026-10-17 00:06:41'),
('pw_require_symbol','1','2026-10-17 00:06:41'),
('pw_require_upper','1','2026-10-17 00:06:41'),
('session_timeout_minutes','30','2026-10-17 00:06:41'),
('track_group_sales','1','2026-10-17 00:06:41'),
('withholding_agent','1','2026-10-17 00:06:41');

-- users (9 rows)
INSERT INTO `users` (`id`,`username`,`password_hash`,`full_name`,`email`,`employee_no`,`pos_default_site_id`,`pos_default_class_id`,`status`,`approval_status`,`created_via`,`approved_by`,`approved_at`,`rejected_reason`,`is_platform`,`must_change_password`,`password_changed_at`,`failed_attempts`,`last_login_at`,`last_login_ip`,`created_by`,`created_at`,`updated_at`) VALUES
(1,'admin','$2y$12$hGwFvkBiGP1dNornEWZ8Ze0SXXSPStiU7RvH8ECHX30zu9nVchSx2','System Administrator','admin@sampletrading.test','EMP-001',NULL,NULL,'active','approved','admin',NULL,NULL,NULL,0,1,'2026-10-17 00:06:41',0,NULL,NULL,NULL,'2026-10-17 00:06:41',NULL),
(2,'accountant','$2y$12$BG8fKs7dwKTyILT20Ipn1eFlRS6t9XqricE86YaGQKU84hGPnYpjy','Ana Cruz','accountant@sampletrading.test','EMP-002',NULL,NULL,'active','approved','admin',NULL,NULL,NULL,0,0,'2026-10-17 00:06:41',0,NULL,NULL,NULL,'2026-10-17 00:06:41',NULL),
(3,'arclerk','$2y$12$wDeCFW3f7LtkNOmBZvCmDOd/CD8WUDRNJXKeqK868xC1NRT0VrFl6','Ben Garcia','arclerk@sampletrading.test','EMP-003',NULL,NULL,'active','approved','admin',NULL,NULL,NULL,0,0,'2026-10-17 00:06:42',0,NULL,NULL,NULL,'2026-10-17 00:06:42',NULL),
(4,'apclerk','$2y$12$OaOBOlvLV78ELgjKZddBPO9rl1cN/RJc1AA1I4cIqEQYrSo9.iZ0y','Carla Lim','apclerk@sampletrading.test','EMP-004',NULL,NULL,'active','approved','admin',NULL,NULL,NULL,0,0,'2026-10-17 00:06:42',0,NULL,NULL,NULL,'2026-10-17 00:06:42',NULL),
(5,'invclerk','$2y$12$VIEGsHKuoOBpchKDy0A2iOqd4FJYMdsflgvHUtJ0OwbInfTW0ttPi','Dan Villanueva','invclerk@sampletrading.test','EMP-005',NULL,NULL,'active','approved','admin',NULL,NULL,NULL,0,0,'2026-10-17 00:06:42',0,NULL,NULL,NULL,'2026-10-17 00:06:42',NULL),
(6,'salesrep','$2y$12$vl5avj1ieYA4.Cl2uxO0Ze76H3IEz0ySpbRJLY6rKz22omVAP9GOW','Maria Santos','salesrep@sampletrading.test','EMP-006',NULL,NULL,'active','approved','admin',NULL,NULL,NULL,0,0,'2026-10-17 00:06:42',0,NULL,NULL,NULL,'2026-10-17 00:06:42',NULL),
(7,'cashier1','$2y$12$XFmZxwyTCUPkI4f3f4AAiOoLHC4coM4kGgpd5ZNxwIS4FwMiLRAeK','Ella Ramos','cashier1@sampletrading.test','EMP-007',NULL,NULL,'active','approved','admin',NULL,NULL,NULL,0,0,'2026-10-17 00:06:43',0,NULL,NULL,NULL,'2026-10-17 00:06:43',NULL),
(8,'supervisor','$2y$12$idxes6QQpOB3yCYI2GGFhOK5IMyu9fMhmALXVOdbiqqZvRMqtPHgu','Fred Tan','supervisor@sampletrading.test','EMP-008',NULL,NULL,'active','approved','admin',NULL,NULL,NULL,0,0,'2026-10-17 00:06:43',0,NULL,NULL,NULL,'2026-10-17 00:06:43',NULL),
(9,'auditor','$2y$12$SxOGH1.tt2AgbwU9QiNQ1.onqoMxbqHO.VAV.himdjRzwx8M1FdgK','Grace Uy','auditor@sampletrading.test','EMP-009',NULL,NULL,'active','approved','admin',NULL,NULL,NULL,0,0,'2026-10-17 00:06:43',0,NULL,NULL,NULL,'2026-10-17 00:06:43',NULL);

-- roles (9 rows)
INSERT INTO `roles` (`id`,`name`,`description`,`is_admin`,`is_system`,`all_sites`,`created_at`,`updated_at`) VALUES
(1,'Administrator','Everything in every module, including user accounts, roles, page access, the closing date, and the audit trail.',1,1,1,'2026-10-17 00:06:41',NULL),
(2,'Accountant','Chart of Accounts, Fixed Assets, Banking and reconciliation, the BIR Reports and Withholding Tax Table, all module reports, and the financial statements.',0,1,1,'2026-10-17 00:06:41',NULL),
(3,'A/R Clerk','Customers module transactions and the Customer and Receivables reports.',0,1,1,'2026-10-17 00:06:41',NULL),
(4,'A/P Clerk','Vendors module transactions, Pay Bills, advances to suppliers, the Vendors and Payables reports, and BIR Form 2307 for suppliers.',0,1,1,'2026-10-17 00:06:41',NULL),
(5,'Inventory Clerk','Items, sites, receiving, adjustments, assembly builds, disassembly and processing orders, stock counts, and inventory quantity reports.',0,1,1,'2026-10-17 00:06:41',NULL),
(6,'Sales Representative','Estimates, sales orders, and invoices, and the Sales reports.',0,1,1,'2026-10-17 00:06:41',NULL),
(7,'Cashier','POS sales, returns, and cash drops at the assigned terminal only.',0,1,0,'2026-10-17 00:06:41',NULL),
(8,'POS Supervisor','Everything a cashier can do, plus approving voids, refunds, price overrides, and large discounts, and running X- and Z-readings.',0,1,1,'2026-10-17 00:06:41',NULL),
(9,'Auditor','View-only access to all transactions, reports, and the audit trail. Cannot create or change anything.',0,1,1,'2026-10-17 00:06:41',NULL);

-- user_roles (9 rows)
INSERT INTO `user_roles` (`user_id`,`role_id`) VALUES
(1,1),
(2,2),
(3,3),
(4,4),
(5,5),
(6,6),
(7,7),
(8,8),
(9,9);

-- modules (11 rows)
INSERT INTO `modules` (`id`,`code`,`name`,`icon`,`sort_order`) VALUES
(1,'home','Home','house',1),
(2,'coa','Financial','journal-bookmark',2),
(3,'fa','Fixed Assets','building',3),
(4,'cust','Customers','people',4),
(5,'vend','Vendors','truck',5),
(6,'inv','Inventory','box-seam',6),
(7,'pos','Point of Sale','cart',7),
(8,'bank','Banking','bank',8),
(9,'bir','BIR Reports','file-earmark-ruled',9),
(10,'admin','System Administration','shield-lock',10),
(11,'company','Company','buildings',11);

-- pages (195 rows)
INSERT INTO `pages` (`id`,`page_key`,`module_id`,`name`,`page_type`,`menu_group`,`sort_order`,`show_in_menu`,`description`) VALUES
(1,'home.dashboard',1,'Home Dashboard','center','Home',10,1,NULL),
(2,'home.reports',1,'Report Center','center','Home',20,1,NULL),
(3,'home.memorized',1,'Memorized Reports','list','Home',30,1,NULL),
(4,'home.report_layouts',1,'Saved Report Layouts','list','Home',40,1,NULL),
(5,'home.search',1,'Search','center','Home',50,0,NULL),
(6,'home.find',1,'Find','center','Home',60,1,NULL),
(7,'rpt.find',1,'Find Results','report','Reports',70,0,NULL),
(8,'coa.accounts',2,'Chart of Accounts','list','Lists',80,1,NULL),
(9,'coa.classes',2,'Class List','list','Lists',90,1,NULL),
(10,'coa.names',2,'Employees & Other Names','list','Lists',100,1,NULL),
(11,'coa.memorized_txns',2,'Memorized Transactions','list','Lists',110,1,NULL),
(12,'coa.budgets',2,'Set Up Budgets','setup','Setup',120,1,NULL),
(13,'coa.journal',2,'Make Journal Entries','transaction','Transactions',130,1,NULL),
(14,'coa.default_accounts',2,'Module Default Accounts','setup','Setup',140,1,NULL),
(15,'coa.lists',2,'Terms, Tax Codes & Other Lists','setup','Setup',150,1,NULL),
(16,'rpt.trial_balance',2,'Trial Balance','report','Reports',160,1,NULL),
(17,'rpt.balance_sheet',2,'Balance Sheet','report','Reports',170,1,NULL),
(18,'rpt.balance_sheet_class',2,'Balance Sheet by Class','report','Reports',180,1,NULL),
(19,'rpt.trial_balance_range',2,'Trial Balance by Date Range','report','Reports',190,1,NULL),
(20,'rpt.trial_balance_totals',2,'Trial Balance of Totals','report','Reports',200,1,NULL),
(21,'rpt.balance_sheet_range',2,'Balance Sheet by Date Range','report','Reports',210,1,NULL),
(22,'rpt.budget_income',2,'Income Statement vs Budget','report','Reports',220,1,NULL),
(23,'rpt.budget_balance',2,'Balance Sheet vs Budget','report','Reports',230,1,NULL),
(24,'rpt.income_statement',2,'Income Statement','report','Reports',240,1,NULL),
(25,'rpt.income_statement_class',2,'Income Statement by Class','report','Reports',250,1,NULL),
(26,'rpt.cash_flow',2,'Statement of Cash Flows','report','Reports',260,1,NULL),
(27,'rpt.general_ledger',2,'General Ledger','report','Reports',270,1,NULL),
(28,'rpt.subsidiary_ledger',2,'Subsidiary Ledger','report','Reports',280,1,NULL),
(29,'rpt.schedule_of_accounts',2,'Schedule of Accounts','report','Reports',290,1,NULL),
(30,'rpt.journal',2,'Journal','report','Reports',300,1,NULL),
(31,'fa.register',3,'Fixed Asset Register','center','Transactions',310,1,NULL),
(32,'fa.depreciation',3,'Run Depreciation','transaction','Transactions',320,1,NULL),
(33,'fa.disposal',3,'Dispose of Assets','transaction','Transactions',330,1,NULL),
(34,'fa.maintenance',3,'Asset Maintenance','transaction','Transactions',340,1,NULL),
(35,'fa.pm',3,'Preventive Maintenance','transaction','Transactions',350,1,NULL),
(36,'fa.categories',3,'Asset Categories','setup','Setup',360,1,NULL),
(37,'fa.locations',3,'Asset Locations','setup','Setup',370,1,NULL),
(38,'rpt.fa_register',3,'Fixed Asset Register Report','report','Reports',380,1,NULL),
(39,'rpt.fa_schedule',3,'Depreciation Schedule by Asset','report','Reports',390,1,NULL),
(40,'rpt.fa_by_category',3,'Depreciation by Category','report','Reports',400,1,NULL),
(41,'rpt.fa_additions',3,'Additions and Disposals','report','Reports',410,1,NULL),
(42,'rpt.fa_maint_history',3,'Maintenance History','report','Reports',420,1,NULL),
(43,'rpt.fa_maint_cost',3,'Maintenance Cost by Asset','report','Reports',430,1,NULL),
(44,'rpt.fa_maint_parts',3,'Spare Parts Used','report','Reports',440,1,NULL),
(45,'rpt.fa_maint_labor',3,'Maintenance Labor','report','Reports',450,1,NULL),
(46,'rpt.fa_pm_upcoming',3,'Upcoming Preventive Maintenance','report','Reports',460,1,NULL),
(47,'rpt.fa_pm_log',3,'Completed Preventive Maintenance','report','Reports',470,1,NULL),
(48,'cust.center',4,'Customer Center','center','Transactions',480,1,NULL),
(49,'cust.estimates',4,'Create Estimates','transaction','Transactions',490,1,NULL),
(50,'cust.sales_orders',4,'Create Sales Orders','transaction','Transactions',500,1,NULL),
(51,'cust.invoices',4,'Create Invoices','transaction','Transactions',510,1,NULL),
(52,'cust.batch_invoices',4,'Create Batch Invoices','transaction','Transactions',520,1,NULL),
(53,'cust.sales_receipts',4,'Enter Sales Receipts','transaction','Transactions',530,1,NULL),
(54,'cust.statement_charges',4,'Enter Statement Charges','transaction','Transactions',540,1,NULL),
(55,'cust.statements',4,'Create Statements','transaction','Transactions',550,1,NULL),
(56,'cust.finance_charges',4,'Assess Finance Charges','transaction','Transactions',560,1,NULL),
(57,'cust.forecast',4,'Set Up Forecast','setup','Transactions',570,1,NULL),
(58,'cust.payments',4,'Receive Payments','transaction','Transactions',580,1,NULL),
(59,'cust.credit_memos',4,'Create Credit Memos/Refunds','transaction','Transactions',590,1,NULL),
(60,'rpt.ar_aging_summary',4,'A/R Aging Summary','report','Customer and Receivables Reports',600,1,NULL),
(61,'rpt.ar_aging_detail',4,'A/R Aging Detail','report','Customer and Receivables Reports',610,1,NULL),
(62,'rpt.customer_balance_summary',4,'Customer Balance Summary','report','Customer and Receivables Reports',620,1,NULL),
(63,'rpt.customer_balance_detail',4,'Customer Balance Detail','report','Customer and Receivables Reports',630,1,NULL),
(64,'rpt.open_invoices',4,'Open Invoices','report','Customer and Receivables Reports',640,1,NULL),
(65,'rpt.collections',4,'Collections Report','report','Customer and Receivables Reports',650,1,NULL),
(66,'rpt.avg_days_summary',4,'Average Days to Pay Summary','report','Customer and Receivables Reports',660,1,NULL),
(67,'rpt.avg_days_detail',4,'Average Days to Pay','report','Customer and Receivables Reports',670,1,NULL),
(68,'rpt.ar_graph',4,'Accounts Receivable Graph','report','Customer and Receivables Reports',680,1,NULL),
(69,'rpt.unbilled_costs',4,'Unbilled Cost by Job','report','Customer and Receivables Reports',690,1,NULL),
(70,'rpt.txn_list_customer',4,'Transaction List by Customer','report','Customer and Receivables Reports',700,1,NULL),
(71,'rpt.item_price_list',4,'Item Price List','report','Customer and Receivables Reports',710,1,NULL),
(72,'rpt.sales_customer_summary',4,'Sales by Customer Summary','report','Sales Reports',720,1,NULL),
(73,'rpt.forecast_vs_actual',4,'Forecast vs Actual by Customer','report','Sales Reports',730,1,NULL),
(74,'rpt.sales_customer_detail',4,'Sales by Customer Detail','report','Sales Reports',740,1,NULL),
(75,'rpt.income_customer_summary',4,'Income by Customer Summary','report','Sales Reports',750,1,NULL),
(76,'rpt.income_customer_detail',4,'Income by Customer Detail','report','Sales Reports',760,1,NULL),
(77,'rpt.sales_item_summary',4,'Sales by Item Summary','report','Sales Reports',770,1,NULL),
(78,'rpt.sales_item_detail',4,'Sales by Item Detail','report','Sales Reports',780,1,NULL),
(79,'rpt.sales_item_group',4,'Sales by Item Group','report','Sales Reports',790,1,NULL),
(80,'rpt.sales_rep_summary',4,'Sales by Rep Summary','report','Sales Reports',800,1,NULL),
(81,'rpt.sales_rep_detail',4,'Sales by Rep Detail','report','Sales Reports',810,1,NULL),
(82,'rpt.inventory_sales_site',4,'Inventory Sales by Site','report','Sales Reports',820,1,NULL),
(83,'rpt.sales_inv_movement',4,'Sales Report Through Inventory Movement','report','Sales Reports',830,1,NULL),
(84,'rpt.pending_sales',4,'Pending Sales','report','Sales Reports',840,1,NULL),
(85,'rpt.open_so_customer',4,'Open Sales Orders by Customer','report','Sales Reports',850,1,NULL),
(86,'rpt.open_so_item',4,'Open Sales Orders by Item','report','Sales Reports',860,1,NULL),
(87,'vend.center',5,'Vendor Center','center','Transactions',870,1,NULL),
(88,'vend.bill_tracker',5,'Bill Tracker','center','Transactions',880,1,NULL),
(89,'vend.bills',5,'Enter Bills','transaction','Transactions',890,1,NULL),
(90,'vend.debit_memos',5,'Supplier Debit Memos','transaction','Transactions',900,1,NULL),
(91,'vend.pay_bills',5,'Pay Bills','transaction','Transactions',910,1,NULL),
(92,'vend.receipts',5,'Receipt Management','transaction','Transactions',920,1,NULL),
(93,'vend.purchase_orders',5,'Create Purchase Orders','transaction','Transactions',930,1,NULL),
(94,'vend.receive_bill',5,'Receive Items and Enter Bills','transaction','Transactions',940,1,NULL),
(95,'vend.receive_items',5,'Receive Items','transaction','Transactions',950,1,NULL),
(96,'vend.bill_received',5,'Enter Bill for Received Items','transaction','Transactions',960,1,NULL),
(97,'vend.advances',5,'Advances to Suppliers','transaction','Transactions',970,1,NULL),
(98,'rpt.ap_aging_summary',5,'A/P Aging Summary','report','Vendors and Payables Reports',980,1,NULL),
(99,'rpt.ap_aging_detail',5,'A/P Aging Detail','report','Vendors and Payables Reports',990,1,NULL),
(100,'rpt.vendor_balance_summary',5,'Vendor Balance Summary','report','Vendors and Payables Reports',1000,1,NULL);
INSERT INTO `pages` (`id`,`page_key`,`module_id`,`name`,`page_type`,`menu_group`,`sort_order`,`show_in_menu`,`description`) VALUES
(101,'rpt.vendor_balance_detail',5,'Vendor Balance Detail','report','Vendors and Payables Reports',1010,1,NULL),
(102,'rpt.unpaid_bills',5,'Unpaid Bills Detail','report','Vendors and Payables Reports',1020,1,NULL),
(103,'rpt.txn_list_vendor',5,'Transaction List by Vendor','report','Vendors and Payables Reports',1030,1,NULL),
(104,'rpt.vendor_contacts',5,'Vendor Contact List','report','Vendors and Payables Reports',1040,1,NULL),
(105,'rpt.expenses_vendor_summary',5,'Expenses by Vendor Summary','report','Vendors and Payables Reports',1050,1,NULL),
(106,'rpt.expenses_vendor_detail',5,'Expenses by Vendor Detail','report','Vendors and Payables Reports',1060,1,NULL),
(107,'rpt.vendor_advances',5,'Advances to Suppliers','report','Vendors and Payables Reports',1070,1,NULL),
(108,'inv.center',6,'Inventory Center','center','Transactions',1080,1,NULL),
(109,'inv.items',6,'Item List','list','Lists',1090,1,NULL),
(110,'inv.categories',6,'Category List','list','Lists',1100,1,NULL),
(111,'inv.sites',6,'Inventory Site List','list','Lists',1110,1,NULL),
(112,'inv.uom',6,'U/M Set List','list','Lists',1120,1,NULL),
(113,'inv.formulas',6,'Processing Formulas (Multi-Output BOM)','list','Lists',1130,1,NULL),
(114,'inv.transfers',6,'Transfer Inventory','transaction','Transactions',1140,1,NULL),
(115,'inv.adjust',6,'Adjust Quantity/Value on Hand','transaction','Transactions',1150,1,NULL),
(116,'inv.build',6,'Build Assemblies','transaction','Transactions',1160,1,NULL),
(117,'inv.process',6,'Disassemble / Process Items','transaction','Transactions',1170,1,NULL),
(118,'inv.physical_count',6,'Physical Inventory Count','transaction','Transactions',1180,1,NULL),
(119,'inv.change_prices',6,'Change Item Prices','transaction','Transactions',1190,1,NULL),
(120,'inv.set_prices',6,'Set Item Prices and Levels','transaction','Transactions',1200,1,NULL),
(121,'rpt.qoh_by_site',6,'Quantity on Hand by Site','report','Inventory Reports',1210,1,NULL),
(122,'rpt.inv_valuation_summary',6,'Inventory Valuation Summary','report','Inventory Reports',1220,1,NULL),
(123,'rpt.inv_valuation_site',6,'Inventory Valuation Summary by Site','report','Inventory Reports',1230,1,NULL),
(124,'rpt.inv_valuation_detail',6,'Inventory Valuation Detail','report','Inventory Reports',1240,1,NULL),
(125,'rpt.stock_status_item',6,'Inventory Stock Status by Item','report','Inventory Reports',1250,1,NULL),
(126,'rpt.stock_status_vendor',6,'Inventory Stock Status by Vendor','report','Inventory Reports',1260,1,NULL),
(127,'rpt.stock_status_site',6,'Inventory Stock Status by Site','report','Inventory Reports',1270,1,NULL),
(128,'rpt.physical_worksheet',6,'Physical Inventory Worksheet','report','Inventory Reports',1280,1,NULL),
(129,'rpt.pending_builds',6,'Pending Builds','report','Inventory Reports',1290,1,NULL),
(130,'rpt.pending_builds_site',6,'Pending Builds by Site','report','Inventory Reports',1300,1,NULL),
(131,'rpt.processing_register',6,'Processing & Disassembly Register','report','Inventory Reports',1310,1,NULL),
(132,'rpt.coproduct_costs',6,'Co-product & By-product Cost Allocation','report','Inventory Reports',1320,1,NULL),
(133,'rpt.process_yield',6,'Processing Yield Analysis','report','Inventory Reports',1330,1,NULL),
(134,'rpt.negative_inventory',6,'Negative Inventory Listing','report','Inventory Reports',1340,1,NULL),
(135,'rpt.inv_no_movement',6,'No. of Days Inventory Has No Movement','report','Inventory Reports',1350,1,NULL),
(136,'rpt.inv_custom',6,'Customized Inventory Report','report','Inventory Reports',1360,1,NULL),
(137,'rpt.inv_movement_summary',6,'Inventory Movement Summary Report','report','Inventory Reports',1370,1,NULL),
(138,'rpt.inv_movement_detail',6,'Inventory Movement Detailed Report','report','Inventory Reports',1380,1,NULL),
(139,'rpt.inv_movement_txns',6,'Inventory Movement Transactions','report','Inventory Reports',1390,0,NULL),
(140,'pos.register',7,'POS Register','transaction','Transactions',1400,1,NULL),
(141,'pos.shifts',7,'Shifts, Cash Drops & Readings','transaction','Transactions',1410,1,NULL),
(142,'pos.receipts',7,'POS Receipts, Returns & Voids','transaction','Transactions',1420,1,NULL),
(143,'pos.approval_codes',7,'Approval Codes','transaction','Transactions',1430,1,NULL),
(144,'pos.terminals',7,'POS Terminals','setup','Setup',1440,1,NULL),
(145,'rpt.pos_sales_txn',7,'POS Sales by Transaction No. (detail)','report','Reports',1450,1,NULL),
(146,'rpt.pos_sales_item',7,'POS Sales by Item','report','Reports',1460,1,NULL),
(147,'rpt.pos_sales_item_group',7,'POS Sales by Item Group','report','Reports',1470,1,NULL),
(148,'rpt.pos_sales_category',7,'POS Sales by Category','report','Reports',1480,1,NULL),
(149,'rpt.pos_sales_cashier',7,'POS Sales by Cashier & Payment Method','report','Reports',1490,1,NULL),
(150,'rpt.pos_sales_payment',7,'POS Sales by Payment Method','report','Reports',1500,0,NULL),
(151,'rpt.pos_sales_hour',7,'POS Sales by Hour','report','Reports',1510,1,NULL),
(152,'rpt.pos_daily_summary',7,'POS Daily Sales Summary','report','Reports',1520,1,NULL),
(153,'rpt.pos_readings',7,'X- and Z-Reading Summary','report','Reports',1530,1,NULL),
(154,'rpt.pos_discount_log',7,'POS Discount Log','report','Reports',1540,1,NULL),
(155,'rpt.pos_void_log',7,'POS Void and Refund Log','report','Reports',1550,1,NULL),
(156,'rpt.pos_ending_inventory',7,'Ending Inventory - POS Cashier','report','Reports',1560,1,NULL),
(157,'bank.write_checks',8,'Write Checks','transaction','Transactions',1570,1,NULL),
(158,'bank.cash_voucher',8,'Cash Voucher','transaction','Transactions',1580,1,NULL),
(159,'bank.register',8,'Use Register','center','Transactions',1590,1,NULL),
(160,'bank.deposits',8,'Make Deposits','transaction','Transactions',1600,1,NULL),
(161,'bank.transfers',8,'Transfer Funds','transaction','Transactions',1610,1,NULL),
(162,'bank.reconcile',8,'Reconcile','transaction','Transactions',1620,1,NULL),
(163,'rpt.recon_summary',8,'Reconciliation Summary','report','Reports',1630,1,NULL),
(164,'rpt.recon_detail',8,'Reconciliation Detail','report','Reports',1640,1,NULL),
(165,'rpt.recon_discrepancy',8,'Reconciliation Discrepancy','report','Reports',1650,1,NULL),
(166,'rpt.check_register',8,'Check Register','report','Reports',1660,1,NULL),
(167,'bir.form_2307',9,'Print BIR Form 2307','transaction','Transactions',1670,1,NULL),
(168,'bir.wht_table',9,'Withholding Tax Table','setup','Setup',1680,1,NULL),
(169,'rpt.bir_wht_summary',9,'Summary of Taxes Withheld from Vendors/Suppliers','report','BIR Reports',1690,1,NULL),
(170,'rpt.bir_ewt_register',9,'Expanded Withholding Tax Register (1% / 2%)','report','BIR Reports',1700,1,NULL),
(171,'rpt.bir_remittance',9,'Withholding Tax Remittances (0619-E, 1601-EQ, 1600-VT)','report','BIR Reports',1710,1,NULL),
(172,'rpt.bir_vat_withholding',9,'VAT Withholding Register (1600-VT)','report','BIR Reports',1720,1,NULL),
(173,'rpt.bir_sales_register',9,'Output VAT / Sales Register','report','BIR Reports',1730,1,NULL),
(174,'rpt.bir_purchase_register',9,'Input VAT / Purchases Register','report','BIR Reports',1740,1,NULL),
(175,'rpt.bir_cvat_withheld',9,'Creditable VAT Withheld Schedule (2550Q Schedule 3)','report','BIR Reports',1750,1,NULL),
(176,'rpt.bir_2550q',9,'Quarterly VAT Return Worksheet (2550Q)','report','BIR Reports',1760,1,NULL),
(177,'admin.users',10,'User Accounts','admin','Setup',1770,1,NULL),
(178,'admin.roles',10,'User Role Configuration','admin','Setup',1780,1,NULL),
(179,'admin.page_access',10,'Page Access Configuration','admin','Setup',1790,1,NULL),
(180,'admin.effective_access',10,'Effective Access (View as User)','admin','Setup',1800,1,NULL),
(181,'admin.settings',10,'Company, Security & Closing Date','admin','Setup',1810,1,NULL),
(182,'admin.utilities',10,'Utilities: Verify & Rebuild Data','admin','Setup',1820,1,NULL),
(183,'admin.import',10,'Import from CSV','admin','Utilities',1830,1,NULL),
(184,'admin.backup',10,'Backup & Restore','admin','Utilities',1840,1,NULL),
(185,'admin.multi_company',10,'Multi-Company Setup','admin','Setup',1850,1,NULL),
(186,'admin.audit_trail',10,'Audit Trail','report','Audit Reports',1860,1,NULL),
(187,'admin.txn_history',10,'Transaction History','report','Audit Reports',1870,1,NULL),
(188,'rpt.voided_deleted_summary',10,'Voided and Deleted Transactions Summary','report','Audit Reports',1880,1,NULL),
(189,'rpt.voided_deleted_detail',10,'Voided and Deleted Transactions Detail','report','Audit Reports',1890,1,NULL),
(190,'rpt.user_activity',10,'User Activity','report','Audit Reports',1900,1,NULL),
(191,'rpt.login_history',10,'Login History','report','Audit Reports',1910,1,NULL),
(192,'rpt.user_access',10,'User Access and Permission Changes','report','Audit Reports',1920,1,NULL),
(193,'company.profile',11,'Company Profile & Code','admin','Company',1930,1,NULL),
(194,'company.users',11,'Employees & Users','admin','Company',1940,1,NULL),
(195,'company.join_requests',11,'Join Requests','admin','Company',1950,1,NULL);

-- role_page_access (485 rows)
INSERT INTO `role_page_access` (`role_id`,`page_id`,`allowed`,`can_create`,`can_edit`,`can_delete`,`can_print`,`can_approve`) VALUES
(2,1,1,0,0,0,1,0),
(2,2,1,0,0,0,1,0),
(2,3,1,0,0,0,1,0),
(2,4,1,0,0,0,1,0),
(2,5,1,0,0,0,1,0),
(2,6,1,0,0,0,1,0),
(2,7,1,0,0,0,1,0),
(2,8,1,1,1,1,1,0),
(2,9,1,1,1,1,1,0),
(2,10,1,1,1,1,1,0),
(2,11,1,1,1,1,1,0),
(2,12,1,1,1,1,1,0),
(2,13,1,1,1,1,1,0),
(2,14,1,1,1,1,1,0),
(2,15,1,1,1,1,1,0),
(2,16,1,1,1,1,1,0),
(2,17,1,1,1,1,1,0),
(2,18,1,1,1,1,1,0),
(2,19,1,1,1,1,1,0),
(2,20,1,1,1,1,1,0),
(2,21,1,1,1,1,1,0),
(2,22,1,1,1,1,1,0),
(2,23,1,1,1,1,1,0),
(2,24,1,1,1,1,1,0),
(2,25,1,1,1,1,1,0),
(2,26,1,1,1,1,1,0),
(2,27,1,1,1,1,1,0),
(2,28,1,1,1,1,1,0),
(2,29,1,1,1,1,1,0),
(2,30,1,1,1,1,1,0),
(2,31,1,1,1,1,1,0),
(2,32,1,1,1,1,1,0),
(2,33,1,1,1,1,1,0),
(2,34,1,1,1,1,1,0),
(2,35,1,1,1,1,1,0),
(2,36,1,1,1,1,1,0),
(2,37,1,1,1,1,1,0),
(2,38,1,1,1,1,1,0),
(2,39,1,1,1,1,1,0),
(2,40,1,1,1,1,1,0),
(2,41,1,1,1,1,1,0),
(2,42,1,1,1,1,1,0),
(2,43,1,1,1,1,1,0),
(2,44,1,1,1,1,1,0),
(2,45,1,1,1,1,1,0),
(2,46,1,1,1,1,1,0),
(2,47,1,1,1,1,1,0),
(2,48,1,0,0,0,1,0),
(2,51,1,0,0,0,1,0),
(2,58,1,0,0,0,1,0),
(2,60,1,0,0,0,1,0),
(2,61,1,0,0,0,1,0),
(2,62,1,0,0,0,1,0),
(2,63,1,0,0,0,1,0),
(2,64,1,0,0,0,1,0),
(2,65,1,0,0,0,1,0),
(2,66,1,0,0,0,1,0),
(2,67,1,0,0,0,1,0),
(2,68,1,0,0,0,1,0),
(2,69,1,0,0,0,1,0),
(2,70,1,0,0,0,1,0),
(2,71,1,0,0,0,1,0),
(2,72,1,0,0,0,1,0),
(2,73,1,0,0,0,1,0),
(2,74,1,0,0,0,1,0),
(2,75,1,0,0,0,1,0),
(2,76,1,0,0,0,1,0),
(2,77,1,0,0,0,1,0),
(2,78,1,0,0,0,1,0),
(2,79,1,0,0,0,1,0),
(2,80,1,0,0,0,1,0),
(2,81,1,0,0,0,1,0),
(2,82,1,0,0,0,1,0),
(2,83,1,0,0,0,1,0),
(2,84,1,0,0,0,1,0),
(2,85,1,0,0,0,1,0),
(2,86,1,0,0,0,1,0),
(2,87,1,0,0,0,1,0),
(2,88,1,0,0,0,1,0),
(2,89,1,0,0,0,1,0),
(2,91,1,0,0,0,1,0),
(2,97,1,0,0,0,1,0),
(2,98,1,0,0,0,1,0),
(2,99,1,0,0,0,1,0),
(2,100,1,0,0,0,1,0),
(2,101,1,0,0,0,1,0),
(2,102,1,0,0,0,1,0),
(2,103,1,0,0,0,1,0),
(2,104,1,0,0,0,1,0),
(2,105,1,0,0,0,1,0),
(2,106,1,0,0,0,1,0),
(2,107,1,0,0,0,1,0),
(2,108,1,0,0,0,1,0),
(2,109,1,0,0,0,1,0),
(2,110,1,0,0,0,1,0),
(2,112,1,0,0,0,1,0),
(2,113,1,0,0,0,1,0),
(2,115,1,0,0,0,1,0),
(2,117,1,0,0,0,1,0),
(2,121,1,0,0,0,1,0);
INSERT INTO `role_page_access` (`role_id`,`page_id`,`allowed`,`can_create`,`can_edit`,`can_delete`,`can_print`,`can_approve`) VALUES
(2,122,1,0,0,0,1,0),
(2,123,1,0,0,0,1,0),
(2,124,1,0,0,0,1,0),
(2,125,1,0,0,0,1,0),
(2,126,1,0,0,0,1,0),
(2,127,1,0,0,0,1,0),
(2,128,1,0,0,0,1,0),
(2,129,1,0,0,0,1,0),
(2,130,1,0,0,0,1,0),
(2,131,1,0,0,0,1,0),
(2,132,1,0,0,0,1,0),
(2,133,1,0,0,0,1,0),
(2,134,1,0,0,0,1,0),
(2,135,1,0,0,0,1,0),
(2,136,1,0,0,0,1,0),
(2,137,1,0,0,0,1,0),
(2,138,1,0,0,0,1,0),
(2,139,1,0,0,0,1,0),
(2,145,1,0,0,0,1,0),
(2,146,1,0,0,0,1,0),
(2,147,1,0,0,0,1,0),
(2,148,1,0,0,0,1,0),
(2,149,1,0,0,0,1,0),
(2,150,1,0,0,0,1,0),
(2,151,1,0,0,0,1,0),
(2,152,1,0,0,0,1,0),
(2,153,1,0,0,0,1,0),
(2,154,1,0,0,0,1,0),
(2,155,1,0,0,0,1,0),
(2,156,1,0,0,0,1,0),
(2,157,1,1,1,1,1,0),
(2,158,1,1,1,1,1,0),
(2,159,1,1,1,1,1,0),
(2,160,1,1,1,1,1,0),
(2,161,1,1,1,1,1,0),
(2,162,1,1,1,1,1,0),
(2,163,1,1,1,1,1,0),
(2,164,1,1,1,1,1,0),
(2,165,1,1,1,1,1,0),
(2,166,1,1,1,1,1,0),
(2,167,1,1,1,1,1,0),
(2,168,1,1,1,1,1,0),
(2,169,1,1,1,1,1,0),
(2,170,1,1,1,1,1,0),
(2,171,1,1,1,1,1,0),
(2,172,1,1,1,1,1,0),
(2,173,1,1,1,1,1,0),
(2,174,1,1,1,1,1,0),
(2,175,1,1,1,1,1,0),
(2,176,1,1,1,1,1,0),
(2,182,1,0,0,0,1,0),
(3,1,1,0,0,0,1,0),
(3,2,1,0,0,0,1,0),
(3,3,1,0,0,0,1,0),
(3,4,1,0,0,0,1,0),
(3,5,1,0,0,0,1,0),
(3,6,1,0,0,0,1,0),
(3,7,1,0,0,0,1,0),
(3,48,1,1,1,0,1,0),
(3,49,1,1,1,0,1,0),
(3,50,1,1,1,0,1,0),
(3,51,1,1,1,0,1,0),
(3,52,1,1,1,0,1,0),
(3,53,1,1,1,0,1,0),
(3,54,1,1,1,0,1,0),
(3,55,1,1,1,0,1,0),
(3,56,1,1,1,0,1,0),
(3,57,1,1,1,0,1,0),
(3,58,1,1,1,0,1,0),
(3,59,1,1,1,0,1,0),
(3,60,1,0,0,0,1,0),
(3,61,1,0,0,0,1,0),
(3,62,1,0,0,0,1,0),
(3,63,1,0,0,0,1,0),
(3,64,1,0,0,0,1,0),
(3,65,1,0,0,0,1,0),
(3,66,1,0,0,0,1,0),
(3,67,1,0,0,0,1,0),
(3,68,1,0,0,0,1,0),
(3,69,1,0,0,0,1,0),
(3,70,1,0,0,0,1,0),
(3,71,1,0,0,0,1,0),
(3,109,1,0,0,0,0,0),
(4,1,1,0,0,0,1,0),
(4,2,1,0,0,0,1,0),
(4,3,1,0,0,0,1,0),
(4,4,1,0,0,0,1,0),
(4,5,1,0,0,0,1,0),
(4,6,1,0,0,0,1,0),
(4,7,1,0,0,0,1,0),
(4,87,1,1,1,0,1,0),
(4,88,1,1,1,0,1,0),
(4,89,1,1,1,0,1,0),
(4,90,1,1,1,0,1,0),
(4,91,1,1,1,0,1,0),
(4,92,1,1,1,0,1,0),
(4,93,1,1,1,0,1,0),
(4,94,1,1,1,0,1,0),
(4,95,1,1,1,0,1,0),
(4,96,1,1,1,0,1,0);
INSERT INTO `role_page_access` (`role_id`,`page_id`,`allowed`,`can_create`,`can_edit`,`can_delete`,`can_print`,`can_approve`) VALUES
(4,97,1,1,1,0,1,0),
(4,98,1,0,0,0,1,0),
(4,99,1,0,0,0,1,0),
(4,100,1,0,0,0,1,0),
(4,101,1,0,0,0,1,0),
(4,102,1,0,0,0,1,0),
(4,103,1,0,0,0,1,0),
(4,104,1,0,0,0,1,0),
(4,105,1,0,0,0,1,0),
(4,106,1,0,0,0,1,0),
(4,107,1,0,0,0,1,0),
(4,109,1,0,0,0,0,0),
(4,167,1,0,0,0,1,0),
(4,168,1,0,0,0,0,0),
(4,169,1,0,0,0,1,0),
(4,170,1,0,0,0,1,0),
(4,171,1,0,0,0,1,0),
(4,172,1,0,0,0,1,0),
(5,1,1,0,0,0,1,0),
(5,2,1,0,0,0,1,0),
(5,3,1,0,0,0,1,0),
(5,4,1,0,0,0,1,0),
(5,5,1,0,0,0,1,0),
(5,6,1,0,0,0,1,0),
(5,7,1,0,0,0,1,0),
(5,93,1,0,0,0,1,0),
(5,95,1,1,1,0,1,0),
(5,108,1,0,0,0,1,0),
(5,109,1,1,1,0,1,0),
(5,110,1,1,1,1,1,0),
(5,111,1,1,1,0,1,0),
(5,112,1,1,1,0,1,0),
(5,113,1,1,1,0,1,0),
(5,114,1,1,1,0,1,0),
(5,115,1,1,1,0,1,0),
(5,116,1,1,1,0,1,0),
(5,117,1,1,1,0,1,0),
(5,118,1,0,0,0,1,0),
(5,121,1,0,0,0,1,0),
(5,125,1,0,0,0,1,0),
(5,126,1,0,0,0,1,0),
(5,127,1,0,0,0,1,0),
(5,128,1,0,0,0,1,0),
(5,129,1,0,0,0,1,0),
(5,130,1,0,0,0,1,0),
(5,131,1,0,0,0,1,0),
(5,133,1,0,0,0,1,0),
(5,134,1,0,0,0,1,0),
(5,135,1,0,0,0,1,0),
(5,137,1,0,0,0,1,0),
(5,138,1,0,0,0,1,0),
(5,139,1,0,0,0,1,0),
(6,1,1,0,0,0,1,0),
(6,2,1,0,0,0,1,0),
(6,3,1,0,0,0,1,0),
(6,4,1,0,0,0,1,0),
(6,5,1,0,0,0,1,0),
(6,6,1,0,0,0,1,0),
(6,7,1,0,0,0,1,0),
(6,48,1,0,0,0,1,0),
(6,49,1,1,1,0,1,0),
(6,50,1,1,1,0,1,0),
(6,51,1,1,1,0,1,0),
(6,71,1,0,0,0,1,0),
(6,72,1,0,0,0,1,0),
(6,73,1,0,0,0,1,0),
(6,74,1,0,0,0,1,0),
(6,75,1,0,0,0,1,0),
(6,76,1,0,0,0,1,0),
(6,77,1,0,0,0,1,0),
(6,78,1,0,0,0,1,0),
(6,79,1,0,0,0,1,0),
(6,80,1,0,0,0,1,0),
(6,81,1,0,0,0,1,0),
(6,82,1,0,0,0,1,0),
(6,83,1,0,0,0,1,0),
(6,84,1,0,0,0,1,0),
(6,85,1,0,0,0,1,0),
(6,86,1,0,0,0,1,0),
(6,139,1,0,0,0,1,0),
(7,1,1,0,0,0,0,0),
(7,140,1,1,0,0,1,0),
(7,141,1,1,0,0,1,0),
(7,142,1,1,0,1,1,0),
(7,156,1,0,0,0,1,0),
(8,1,1,0,0,0,0,0),
(8,2,1,0,0,0,0,0),
(8,140,1,1,1,1,1,1),
(8,141,1,1,1,1,1,1),
(8,142,1,1,1,1,1,1),
(8,143,1,1,1,1,1,1),
(8,144,1,0,0,0,1,0),
(8,145,1,0,0,0,1,0),
(8,146,1,0,0,0,1,0),
(8,147,1,0,0,0,1,0),
(8,148,1,0,0,0,1,0),
(8,149,1,0,0,0,1,0),
(8,150,1,0,0,0,1,0),
(8,151,1,0,0,0,1,0),
(8,152,1,0,0,0,1,0);
INSERT INTO `role_page_access` (`role_id`,`page_id`,`allowed`,`can_create`,`can_edit`,`can_delete`,`can_print`,`can_approve`) VALUES
(8,153,1,0,0,0,1,0),
(8,154,1,0,0,0,1,0),
(8,155,1,0,0,0,1,0),
(8,156,1,0,0,0,1,0),
(9,1,1,0,0,0,1,0),
(9,2,1,0,0,0,1,0),
(9,3,1,0,0,0,1,0),
(9,4,1,0,0,0,1,0),
(9,5,1,0,0,0,1,0),
(9,6,1,0,0,0,1,0),
(9,7,1,0,0,0,1,0),
(9,8,1,0,0,0,1,0),
(9,9,1,0,0,0,1,0),
(9,10,1,0,0,0,1,0),
(9,11,1,0,0,0,1,0),
(9,12,1,0,0,0,1,0),
(9,13,1,0,0,0,1,0),
(9,14,1,0,0,0,1,0),
(9,15,1,0,0,0,1,0),
(9,16,1,0,0,0,1,0),
(9,17,1,0,0,0,1,0),
(9,18,1,0,0,0,1,0),
(9,19,1,0,0,0,1,0),
(9,20,1,0,0,0,1,0),
(9,21,1,0,0,0,1,0),
(9,22,1,0,0,0,1,0),
(9,23,1,0,0,0,1,0),
(9,24,1,0,0,0,1,0),
(9,25,1,0,0,0,1,0),
(9,26,1,0,0,0,1,0),
(9,27,1,0,0,0,1,0),
(9,28,1,0,0,0,1,0),
(9,29,1,0,0,0,1,0),
(9,30,1,0,0,0,1,0),
(9,31,1,0,0,0,1,0),
(9,32,1,0,0,0,1,0),
(9,33,1,0,0,0,1,0),
(9,34,1,0,0,0,1,0),
(9,35,1,0,0,0,1,0),
(9,36,1,0,0,0,1,0),
(9,37,1,0,0,0,1,0),
(9,38,1,0,0,0,1,0),
(9,39,1,0,0,0,1,0),
(9,40,1,0,0,0,1,0),
(9,41,1,0,0,0,1,0),
(9,42,1,0,0,0,1,0),
(9,43,1,0,0,0,1,0),
(9,44,1,0,0,0,1,0),
(9,45,1,0,0,0,1,0),
(9,46,1,0,0,0,1,0),
(9,47,1,0,0,0,1,0),
(9,48,1,0,0,0,1,0),
(9,49,1,0,0,0,1,0),
(9,50,1,0,0,0,1,0),
(9,51,1,0,0,0,1,0),
(9,52,1,0,0,0,1,0),
(9,53,1,0,0,0,1,0),
(9,54,1,0,0,0,1,0),
(9,55,1,0,0,0,1,0),
(9,56,1,0,0,0,1,0),
(9,57,1,0,0,0,1,0),
(9,58,1,0,0,0,1,0),
(9,59,1,0,0,0,1,0),
(9,60,1,0,0,0,1,0),
(9,61,1,0,0,0,1,0),
(9,62,1,0,0,0,1,0),
(9,63,1,0,0,0,1,0),
(9,64,1,0,0,0,1,0),
(9,65,1,0,0,0,1,0),
(9,66,1,0,0,0,1,0),
(9,67,1,0,0,0,1,0),
(9,68,1,0,0,0,1,0),
(9,69,1,0,0,0,1,0),
(9,70,1,0,0,0,1,0),
(9,71,1,0,0,0,1,0),
(9,72,1,0,0,0,1,0),
(9,73,1,0,0,0,1,0),
(9,74,1,0,0,0,1,0),
(9,75,1,0,0,0,1,0),
(9,76,1,0,0,0,1,0),
(9,77,1,0,0,0,1,0),
(9,78,1,0,0,0,1,0),
(9,79,1,0,0,0,1,0),
(9,80,1,0,0,0,1,0),
(9,81,1,0,0,0,1,0),
(9,82,1,0,0,0,1,0),
(9,83,1,0,0,0,1,0),
(9,84,1,0,0,0,1,0),
(9,85,1,0,0,0,1,0),
(9,86,1,0,0,0,1,0),
(9,87,1,0,0,0,1,0),
(9,88,1,0,0,0,1,0),
(9,89,1,0,0,0,1,0),
(9,90,1,0,0,0,1,0),
(9,91,1,0,0,0,1,0),
(9,92,1,0,0,0,1,0),
(9,93,1,0,0,0,1,0),
(9,94,1,0,0,0,1,0),
(9,95,1,0,0,0,1,0),
(9,96,1,0,0,0,1,0);
INSERT INTO `role_page_access` (`role_id`,`page_id`,`allowed`,`can_create`,`can_edit`,`can_delete`,`can_print`,`can_approve`) VALUES
(9,97,1,0,0,0,1,0),
(9,98,1,0,0,0,1,0),
(9,99,1,0,0,0,1,0),
(9,100,1,0,0,0,1,0),
(9,101,1,0,0,0,1,0),
(9,102,1,0,0,0,1,0),
(9,103,1,0,0,0,1,0),
(9,104,1,0,0,0,1,0),
(9,105,1,0,0,0,1,0),
(9,106,1,0,0,0,1,0),
(9,107,1,0,0,0,1,0),
(9,108,1,0,0,0,1,0),
(9,109,1,0,0,0,1,0),
(9,110,1,0,0,0,1,0),
(9,111,1,0,0,0,1,0),
(9,112,1,0,0,0,1,0),
(9,113,1,0,0,0,1,0),
(9,114,1,0,0,0,1,0),
(9,115,1,0,0,0,1,0),
(9,116,1,0,0,0,1,0),
(9,117,1,0,0,0,1,0),
(9,118,1,0,0,0,1,0),
(9,119,1,0,0,0,1,0),
(9,120,1,0,0,0,1,0),
(9,121,1,0,0,0,1,0),
(9,122,1,0,0,0,1,0),
(9,123,1,0,0,0,1,0),
(9,124,1,0,0,0,1,0),
(9,125,1,0,0,0,1,0),
(9,126,1,0,0,0,1,0),
(9,127,1,0,0,0,1,0),
(9,128,1,0,0,0,1,0),
(9,129,1,0,0,0,1,0),
(9,130,1,0,0,0,1,0),
(9,131,1,0,0,0,1,0),
(9,132,1,0,0,0,1,0),
(9,133,1,0,0,0,1,0),
(9,134,1,0,0,0,1,0),
(9,135,1,0,0,0,1,0),
(9,136,1,0,0,0,1,0),
(9,137,1,0,0,0,1,0),
(9,138,1,0,0,0,1,0),
(9,139,1,0,0,0,1,0),
(9,142,1,0,0,0,1,0),
(9,143,1,0,0,0,1,0),
(9,144,1,0,0,0,1,0),
(9,145,1,0,0,0,1,0),
(9,146,1,0,0,0,1,0),
(9,147,1,0,0,0,1,0),
(9,148,1,0,0,0,1,0),
(9,149,1,0,0,0,1,0),
(9,150,1,0,0,0,1,0),
(9,151,1,0,0,0,1,0),
(9,152,1,0,0,0,1,0),
(9,153,1,0,0,0,1,0),
(9,154,1,0,0,0,1,0),
(9,155,1,0,0,0,1,0),
(9,156,1,0,0,0,1,0),
(9,157,1,0,0,0,1,0),
(9,158,1,0,0,0,1,0),
(9,159,1,0,0,0,1,0),
(9,160,1,0,0,0,1,0),
(9,161,1,0,0,0,1,0),
(9,162,1,0,0,0,1,0),
(9,163,1,0,0,0,1,0),
(9,164,1,0,0,0,1,0),
(9,165,1,0,0,0,1,0),
(9,166,1,0,0,0,1,0),
(9,167,1,0,0,0,1,0),
(9,168,1,0,0,0,1,0),
(9,169,1,0,0,0,1,0),
(9,170,1,0,0,0,1,0),
(9,171,1,0,0,0,1,0),
(9,172,1,0,0,0,1,0),
(9,173,1,0,0,0,1,0),
(9,174,1,0,0,0,1,0),
(9,175,1,0,0,0,1,0),
(9,176,1,0,0,0,1,0),
(9,186,1,0,0,0,1,0),
(9,187,1,0,0,0,1,0),
(9,188,1,0,0,0,1,0),
(9,189,1,0,0,0,1,0),
(9,190,1,0,0,0,1,0),
(9,191,1,0,0,0,1,0),
(9,192,1,0,0,0,1,0);

-- role_special_permissions (33 rows)
INSERT INTO `role_special_permissions` (`role_id`,`perm_key`,`perm_value`) VALUES
(2,'closed_period_changes','0'),
(2,'coa_changes','1'),
(2,'credit_limit_override','0'),
(2,'design_reports','1'),
(2,'max_amount',''),
(2,'max_discount_pct','0'),
(2,'max_price_override_pct','0'),
(2,'view_bank_balances','1'),
(2,'view_costs','1'),
(3,'credit_limit_override','0'),
(3,'max_amount','50000'),
(3,'max_discount_pct','10'),
(3,'max_price_override_pct','5'),
(3,'view_bank_balances','0'),
(3,'view_costs','0'),
(4,'max_amount','100000'),
(4,'view_bank_balances','0'),
(4,'view_costs','1'),
(5,'max_amount','20000'),
(5,'view_costs','0'),
(6,'max_discount_pct','5'),
(6,'max_price_override_pct','0'),
(6,'view_costs','0'),
(7,'max_amount','0'),
(7,'max_discount_pct','5'),
(7,'max_price_override_pct','0'),
(7,'view_costs','0'),
(8,'max_amount','20000'),
(8,'max_discount_pct','30'),
(8,'max_price_override_pct','20'),
(8,'view_costs','0'),
(9,'view_bank_balances','1'),
(9,'view_costs','1');

-- sequences (26 rows)
INSERT INTO `sequences` (`seq_key`,`prefix`,`next_no`,`pad`) VALUES
('adjustment','ADJ-',1,5),
('advance_apply','AAP-',1,5),
('asset','FA-',1,5),
('bill','BILL-',1,5),
('build','BLD-',1,5),
('cash_voucher','CAV-',1,5),
('check','',1001,4),
('credit_memo','CM-',1,5),
('debit_memo','DM-',1,5),
('deposit','DEP-',1,5),
('estimate','EST-',1,5),
('finance_charge','FC-',1,5),
('inv_transfer','IT-',1,5),
('invoice','INV-',1,5),
('item_receipt','IR-',1,5),
('journal','JE-',1,5),
('maintenance','MNT-',1,5),
('payment','PMT-',1,5),
('pos','POS-',1,6),
('processing','PRC-',1,5),
('purchase_order','PO-',1,5),
('sales_order','SO-',1,5),
('sales_receipt','SR-',1,5),
('statement_charge','SC-',1,5),
('transfer','TRF-',1,5),
('vendor_advance','ADV-',1,5);

-- accounts (72 rows)
INSERT INTO `accounts` (`id`,`code`,`name`,`account_type`,`category`,`normal_balance`,`parent_id`,`description`,`bank_account_no`,`with_sl`,`is_active`,`is_system`,`created_at`,`updated_at`) VALUES
(1,'1000','Cash','Bank','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(2,'1001','Cash on Hand - Store Registers','Bank','Asset','Debit',1,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(3,'1005','Petty Cash Fund','Bank','Asset','Debit',1,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(4,'1006','Revolving Fund','Bank','Asset','Debit',1,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(5,'1010','Cash in Bank - BDO Checking','Bank','Asset','Debit',1,NULL,'0012-3456-7890',0,1,0,'2026-10-17 00:06:41',NULL),
(6,'1020','Cash in Bank - BPI Savings','Bank','Asset','Debit',1,NULL,'1234-5678-90',0,1,0,'2026-10-17 00:06:41',NULL),
(7,'1050','Undeposited Funds','Other Current Asset','Asset','Debit',NULL,NULL,NULL,0,1,1,'2026-10-17 00:06:41',NULL),
(8,'1060','Card Clearing','Other Current Asset','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(9,'1065','E-wallet Clearing','Other Current Asset','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(10,'1070','P.O. Card Clearing','Other Current Asset','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(11,'1100','Accounts Receivable','Accounts Receivable','Asset','Debit',NULL,NULL,NULL,0,1,1,'2026-10-17 00:06:41',NULL),
(12,'1150','Allowance for Doubtful Accounts','Other Current Asset','Asset','Credit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(13,'1200','Inventory','Other Current Asset','Asset','Debit',NULL,NULL,NULL,0,1,1,'2026-10-17 00:06:41',NULL),
(14,'1300','Input Tax','Other Current Asset','Asset','Debit',NULL,NULL,NULL,0,1,1,'2026-10-17 00:06:41',NULL),
(15,'1310','Creditable Withholding Tax','Other Current Asset','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(16,'1315','Creditable VAT Withheld','Other Current Asset','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(17,'1400','Prepaid Expenses','Other Current Asset','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(18,'1410','Advances to Suppliers','Other Current Asset','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(19,'1500','Land','Fixed Asset','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(20,'1510','Building','Fixed Asset','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(21,'1515','Accumulated Depreciation - Building','Fixed Asset','Asset','Credit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(22,'1520','Machinery and Equipment','Fixed Asset','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(23,'1525','Accumulated Depreciation - Machinery','Fixed Asset','Asset','Credit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(24,'1530','Transportation Equipment','Fixed Asset','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(25,'1535','Accumulated Depreciation - Transportation','Fixed Asset','Asset','Credit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(26,'1540','Furniture and Fixtures','Fixed Asset','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(27,'1545','Accumulated Depreciation - Furniture','Fixed Asset','Asset','Credit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(28,'1550','Computer and POS Equipment','Fixed Asset','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(29,'1555','Accumulated Depreciation - Computer and POS','Fixed Asset','Asset','Credit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(30,'1600','Security Deposits','Other Asset','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(31,'2000','Accounts Payable','Accounts Payable','Liability','Credit',NULL,NULL,NULL,0,1,1,'2026-10-17 00:06:41',NULL),
(32,'2050','Company Credit Card','Credit Card','Liability','Credit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(33,'2100','Output Tax','Other Current Liability','Liability','Credit',NULL,NULL,NULL,0,1,1,'2026-10-17 00:06:41',NULL),
(34,'2110','Withholding Tax Payable','Other Current Liability','Liability','Credit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(35,'2115','VAT Withheld Payable','Other Current Liability','Liability','Credit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(36,'2120','Gift Vouchers Outstanding','Other Current Liability','Liability','Credit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(37,'2130','Customer Deposits','Other Current Liability','Liability','Credit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(38,'2200','Accrued Expenses','Other Current Liability','Liability','Credit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(39,'2500','Loans Payable','Long Term Liability','Liability','Credit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(40,'3000','Owner\'s Capital','Equity','Equity','Credit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(41,'3100','Owner\'s Drawings','Equity','Equity','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(42,'3200','Retained Earnings','Equity','Equity','Credit',NULL,NULL,NULL,0,1,1,'2026-10-17 00:06:41',NULL),
(43,'3900','Opening Balance Equity','Equity','Equity','Credit',NULL,NULL,NULL,0,1,1,'2026-10-17 00:06:41',NULL),
(44,'4000','Sales','Income','Income','Credit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(45,'4010','Service Income','Income','Income','Credit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(46,'4020','Delivery Income','Income','Income','Credit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(47,'4050','Sales Returns and Allowances','Income','Income','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(48,'4060','Sales Discounts','Income','Income','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(49,'4070','Item Group Price Variance','Income','Income','Credit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(50,'4110','Reimbursable Expense Income','Income','Income','Credit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(51,'4100','Finance Charge Income','Other Income','Income','Credit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(52,'4200','Interest Income','Other Income','Income','Credit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(53,'4300','Gain (Loss) on Disposal of Assets','Other Income','Income','Credit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(54,'5000','Cost of Goods Sold','Cost of Goods Sold','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(55,'5050','Purchase Discounts','Cost of Goods Sold','Expense','Credit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(56,'5100','Inventory Adjustments and Shrinkage','Cost of Goods Sold','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(57,'5200','Direct Labor Absorbed','Cost of Goods Sold','Expense','Credit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(58,'6000','Salaries and Wages','Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(59,'6010','Rent Expense','Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(60,'6020','Utilities Expense','Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(61,'6030','Repairs and Maintenance','Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(62,'6040','Office Supplies Expense','Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(63,'6050','Fuel and Oil','Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(64,'6060','Meals and Representation','Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(65,'6070','Professional Fees','Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(66,'6080','Bank and Merchant Charges','Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(67,'6090','Depreciation Expense','Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(68,'6100','Freight and Delivery','Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(69,'6110','Purchases - Non-inventory','Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(70,'6200','Cash Over and Short','Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(71,'6900','Miscellaneous Expense','Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL),
(72,'7000','Interest Expense','Other Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:41',NULL);

-- default_accounts (32 rows)
INSERT INTO `default_accounts` (`setting_key`,`label`,`module`,`account_id`) VALUES
('ap','Accounts Payable','vend',31),
('ar','Accounts Receivable','cust',11),
('card_clearing','Card Clearing','pos',8),
('cash_on_hand','Cash on Hand (Register)','pos',2),
('cash_over_short','Cash Over and Short','pos',70),
('cogs','Cost of Goods Sold','inv',54),
('cvat_withheld','Creditable VAT Withheld','cust',16),
('cwt','Creditable Withholding Tax','cust',15),
('default_expense','Default Purchases / Expense','vend',69),
('ewallet_clearing','E-wallet Clearing','pos',9),
('finance_charge_income','Finance Charge Income','cust',51),
('gain_loss_disposal','Gain / Loss on Disposal of Assets','fa',53),
('group_price_variance','Item Group Price Variance','inv',49),
('input_tax','Input Tax','vend',14),
('interest_income','Interest Income','bank',52),
('inventory_adjustment','Inventory Adjustment (Shrinkage)','inv',56),
('inventory_asset','Inventory Asset','inv',13),
('merchant_fees','Bank / Merchant Charges','bank',66),
('opening_equity','Opening Balance Equity','coa',43),
('output_tax','Output Tax','cust',33),
('processing_absorbed','Processing Labor & Overhead Absorbed','inv',57),
('processing_variance','Processing / Disassembly Variance','inv',56),
('purchase_discounts','Purchase Discounts','vend',55),
('reimbursable_income','Reimbursable Expense Income','cust',50),
('retained_earnings','Retained Earnings','coa',42),
('sales_discounts','Sales Discounts','cust',48),
('sales_income','Default Sales Income','cust',44),
('sales_returns','Sales Returns and Allowances','cust',47),
('undeposited_funds','Undeposited Funds','cust',7),
('vat_withheld_payable','VAT Withheld Payable','vend',35),
('vendor_advances','Advances to Suppliers','vend',18),
('wht_payable','Withholding Tax Payable (Expanded)','vend',34);

-- terms (5 rows)
INSERT INTO `terms` (`id`,`name`,`net_days`,`discount_pct`,`discount_days`,`is_active`) VALUES
(1,'Due on receipt',0,'0.00',0,1),
(2,'Net 15',15,'0.00',0,1),
(3,'Net 30',30,'0.00',0,1),
(4,'2% 10 Net 30',30,'2.00',10,1),
(5,'Net 60',60,'0.00',0,1);

-- tax_codes (4 rows)
INSERT INTO `tax_codes` (`id`,`code`,`name`,`rate`,`sales_account_id`,`purchase_account_id`,`is_active`) VALUES
(1,'VAT12','VAT 12%','12.000',33,14,1),
(2,'ZR','Zero-rated','0.000',33,14,1),
(3,'EX','VAT-exempt','0.000',33,14,1),
(4,'NT','Non-taxable','0.000',33,14,1);

-- payment_methods (9 rows)
INSERT INTO `payment_methods` (`id`,`name`,`method_type`,`clearing_account_id`,`is_active`,`show_in_pos`) VALUES
(1,'Cash','cash',NULL,1,1),
(2,'Check','check',NULL,1,0),
(3,'Credit/Debit Card','card',8,1,1),
(4,'GCash','ewallet',9,1,1),
(5,'Maya','ewallet',9,1,1),
(6,'Bank Transfer','bank_transfer',NULL,1,0),
(7,'Gift Voucher','voucher',36,1,1),
(8,'P.O. Card','card',10,1,1),
(9,'Bank','bank_transfer',5,1,1);

-- price_levels (10 rows)
INSERT INTO `price_levels` (`id`,`name`,`adjust_pct`,`is_active`) VALUES
(1,'Wholesale','-5.00',1),
(2,'VIP','-10.00',1),
(3,'Retail Plus','5.00',1),
(4,'Price Level 4','0.00',1),
(5,'Price Level 5','0.00',1),
(6,'Price Level 6','0.00',1),
(7,'Price Level 7','0.00',1),
(8,'Price Level 8','0.00',1),
(9,'Price Level 9','0.00',1),
(10,'Price Level 10','0.00',1);

-- sales_reps (2 rows)
INSERT INTO `sales_reps` (`id`,`name`,`initials`,`user_id`,`commission_pct`,`is_active`) VALUES
(1,'Maria Santos','MS',6,'3.00',1),
(2,'Jose Reyes','JR',NULL,'2.50',1);

-- customer_types (4 rows)
INSERT INTO `customer_types` (`id`,`name`) VALUES
(1,'Corporate'),
(2,'Retail'),
(3,'School'),
(4,'Government');

-- billing_groups (1 rows)
INSERT INTO `billing_groups` (`id`,`name`) VALUES
(1,'Monthly Service Contracts');

-- customers (9 rows)
INSERT INTO `customers` (`id`,`parent_id`,`name`,`company_name`,`contact_person`,`phone`,`mobile`,`email`,`billing_address`,`shipping_address`,`tin`,`wht_ids`,`terms_id`,`credit_limit`,`price_level_id`,`tax_code_id`,`payment_method_id`,`customer_type_id`,`sales_rep_id`,`billing_group_id`,`allow_pos_charge`,`notes`,`is_active`,`created_at`,`updated_at`) VALUES
(1,NULL,'ABC Trading Corp.','ABC Trading Corporation','Mr. Albert Co','(02) 8777-1001',NULL,'ap@abctrading.test','45 Buendia Ave., Makati City','45 Buendia Ave., Makati City','111-222-333-000',NULL,3,'250000.00',NULL,1,2,1,1,NULL,1,NULL,1,'2026-10-17 00:06:43',NULL),
(2,1,'Office Renovation Project',NULL,NULL,NULL,NULL,NULL,'45 Buendia Ave., Makati City',NULL,NULL,NULL,3,'0.00',NULL,1,NULL,1,1,NULL,0,NULL,1,'2026-10-17 00:06:43',NULL),
(3,NULL,'Metro School Supplies','Metro School Supplies Inc.','Ms. Bea Lim','(02) 8777-2002',NULL,'purchasing@metroschool.test','88 España Blvd., Manila',NULL,NULL,NULL,2,'100000.00',1,1,NULL,2,2,NULL,0,NULL,1,'2026-10-17 00:06:43',NULL),
(4,NULL,'Cebu Tech Hub','Cebu Tech Hub Co.','Mr. Carlo Sy','(032) 255-3003',NULL,'finance@cebutech.test','IT Park, Lahug, Cebu City',NULL,NULL,NULL,4,'150000.00',2,1,NULL,1,2,NULL,0,NULL,1,'2026-10-17 00:06:43',NULL),
(5,NULL,'Bright Minds Academy','Bright Minds Academy','Dr. Dina Reyes','(02) 8777-4004',NULL,'admin@brightminds.test','12 Katipunan Ave., Quezon City',NULL,NULL,NULL,2,'60000.00',NULL,1,NULL,3,1,1,0,NULL,1,'2026-10-17 00:06:43',NULL),
(6,NULL,'Green Valley Clinic','Green Valley Clinic','Dr. Eric Tan','(02) 8777-5005',NULL,NULL,'5 Shaw Blvd., Mandaluyong',NULL,NULL,NULL,2,'40000.00',NULL,1,NULL,1,1,1,0,NULL,1,'2026-10-17 00:06:43',NULL),
(7,NULL,'City Government of Makati','City Government of Makati','Procurement Office','(02) 8870-1000',NULL,'procurement@makati.test','Makati City Hall, J.P. Rizal St., Makati City',NULL,'000-456-789-000','3,1',3,'0.00',NULL,1,2,4,NULL,NULL,0,NULL,1,'2026-10-17 00:06:43',NULL),
(8,NULL,'Juan Dela Cruz',NULL,'Juan Dela Cruz',NULL,'0917-555-0000',NULL,NULL,NULL,NULL,NULL,1,'0.00',NULL,1,1,2,NULL,NULL,0,NULL,1,'2026-10-17 00:06:43',NULL),
(9,NULL,'Walk-in Customer',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'0.00',NULL,1,1,2,NULL,NULL,0,NULL,1,'2026-10-17 00:06:43',NULL);

-- vendors (8 rows)
INSERT INTO `vendors` (`id`,`name`,`company_name`,`contact_person`,`phone`,`fax`,`email`,`address`,`tin`,`terms_id`,`credit_limit`,`default_expense_account_id`,`tax_code_id`,`account_no`,`wht_ids`,`notes`,`is_active`,`created_at`,`updated_at`) VALUES
(1,'TechDistributors Inc.','TechDistributors Inc.','Rico Lopez','(02) 8555-0101',NULL,'sales@techdist.test','Pasig City','203-908-117-000',3,'0.00',NULL,1,'TD-88012','1',NULL,1,'2026-10-17 00:06:43',NULL),
(2,'Office Depot PH','Office Depot PH','Liza Go','(02) 8555-0202',NULL,'orders@officedepot.test','Quezon City','233-817-750-000',2,'0.00',62,1,'OD-4410',NULL,NULL,1,'2026-10-17 00:06:43',NULL),
(3,'Meralco','Meralco','Customer Service','16211',NULL,'billing@meralco.test','Pasig City','689-401-719-000',1,'0.00',60,1,'1234-5678-9012',NULL,NULL,1,'2026-10-17 00:06:43',NULL),
(4,'Metro Property Leasing','Metro Property Leasing','Tony Chua','(02) 8555-0303',NULL,'leasing@metroprop.test','Makati City','169-498-223-000',1,'0.00',59,1,'L-2291',NULL,NULL,1,'2026-10-17 00:06:43',NULL),
(5,'Petron Service Station','Petron Service Station',NULL,'(02) 8555-0404',NULL,NULL,'Makati City','647-803-518-000',1,'0.00',63,1,NULL,NULL,NULL,1,'2026-10-17 00:06:43',NULL),
(6,'JRS Express','JRS Express','Operations','(02) 8555-0505',NULL,'ops@jrs.test','Manila','352-195-375-000',2,'0.00',68,1,'JRS-7781','2',NULL,1,'2026-10-17 00:06:43',NULL),
(7,'Accounting Partners & Co.','Accounting Partners & Co.','Atty. Reyes','(02) 8555-0606',NULL,'hello@apco.test','Taguig City','356-937-930-000',3,'0.00',65,1,NULL,'2',NULL,1,'2026-10-17 00:06:43',NULL),
(8,'Industrial Machines Corp.','Industrial Machines Corp.','Sales','(02) 8555-0707',NULL,'sales@imc.test','Laguna','349-201-221-000',3,'0.00',NULL,1,'IMC-100','1',NULL,1,'2026-10-17 00:06:43',NULL);

-- sites (5 rows)
INSERT INTO `sites` (`id`,`code`,`name`,`site_type`,`address`,`is_active`) VALUES
(1,'WH','Main Warehouse','warehouse',NULL,1),
(2,'ST1','Makati Store','store',NULL,1),
(3,'ST2','Cebu Store','store',NULL,1),
(4,'VAN1','Delivery Van 1','van',NULL,1),
(5,'DMG','Damaged Goods','damaged',NULL,1);

-- item_categories (6 rows)
INSERT INTO `item_categories` (`id`,`name`) VALUES
(1,'Computers'),
(2,'Accessories'),
(3,'Services'),
(4,'Bundles'),
(5,'Supplies'),
(6,'Charges');

-- uom_sets (5 rows)
INSERT INTO `uom_sets` (`id`,`name`,`uom_kind`,`base_unit`,`is_active`,`created_at`,`updated_at`) VALUES
(1,'Piece','count','pc',1,'2026-10-17 00:06:41',NULL),
(2,'Weight (kg)','weight','kg',1,'2026-10-17 00:06:41',NULL),
(3,'Volume (L)','volume','L',1,'2026-10-17 00:06:41',NULL),
(4,'Length (m)','length','m',1,'2026-10-17 00:06:41',NULL),
(5,'Time (hour)','time','hr',1,'2026-10-17 00:06:41',NULL);

-- uom_units (16 rows)
INSERT INTO `uom_units` (`id`,`set_id`,`code`,`name`,`factor`,`is_base`,`is_sales_default`,`is_purchase_default`,`sort_order`) VALUES
(1,1,'pc','Piece','1.000000',1,1,0,0),
(2,1,'dz','Dozen (12 pieces)','12.000000',0,0,0,1),
(3,1,'box','Box of 24','24.000000',0,0,1,2),
(4,1,'case','Case of 144','144.000000',0,0,0,3),
(5,2,'kg','Kilogram','1.000000',1,1,1,0),
(6,2,'g','Gram','0.001000',0,0,0,1),
(7,2,'sack','Sack of 25 kg','25.000000',0,0,0,2),
(8,3,'L','Liter','1.000000',1,1,1,0),
(9,3,'mL','Milliliter','0.001000',0,0,0,1),
(10,3,'drum','Drum of 200 L','200.000000',0,0,0,2),
(11,4,'m','Meter','1.000000',1,1,1,0),
(12,4,'cm','Centimeter','0.010000',0,0,0,1),
(13,4,'roll','Roll of 100 m','100.000000',0,0,0,2),
(14,5,'hr','Hour','1.000000',1,1,1,0),
(15,5,'day','Day (8 hours)','8.000000',0,0,0,1),
(16,5,'wk','Week (40 hours)','40.000000',0,0,0,2);

-- items (27 rows)
INSERT INTO `items` (`id`,`item_type`,`code`,`barcode`,`name`,`description`,`purchase_description`,`category_id`,`unit`,`uom_set_id`,`sales_uom_id`,`purchase_uom_id`,`cost`,`avg_cost`,`sales_price`,`discount_pct`,`income_account_id`,`cogs_account_id`,`asset_account_id`,`expense_account_id`,`tax_code_id`,`group_variance_account_id`,`preferred_vendor_id`,`reorder_point`,`max_stock`,`build_point`,`is_active`,`created_at`,`updated_at`) VALUES
(1,'inventory','LAP-001','4800000000011','Laptop 14-inch i5 16GB','Laptop 14-inch i5 16GB','Laptop 14-inch i5 16GB',1,'pc',1,NULL,NULL,'32000.0000','0.0000','39990.0000','0.00',44,54,13,NULL,1,NULL,1,'5.0000','20.0000','0.0000',1,'2026-10-17 00:06:43',NULL),
(2,'inventory','MON-024','4800000000028','Monitor 24-inch IPS','Monitor 24-inch IPS','Monitor 24-inch IPS',1,'pc',1,NULL,NULL,'6500.0000','0.0000','8990.0000','0.00',44,54,13,NULL,1,NULL,1,'5.0000','30.0000','0.0000',1,'2026-10-17 00:06:43',NULL),
(3,'inventory','KEY-001','4800000000035','Keyboard USB','Keyboard USB','Keyboard USB',2,'pc',1,NULL,NULL,'650.0000','0.0000','999.0000','0.00',44,54,13,NULL,1,NULL,1,'10.0000','50.0000','0.0000',1,'2026-10-17 00:06:43',NULL),
(4,'inventory','MOU-001','4800000000042','Wireless Mouse','Wireless Mouse','Wireless Mouse',2,'pc',1,NULL,NULL,'350.0000','0.0000','599.0000','0.00',44,54,13,NULL,1,NULL,1,'15.0000','80.0000','0.0000',1,'2026-10-17 00:06:43',NULL),
(5,'inventory','USB-032','4800000000059','USB Flash Drive 32GB','USB Flash Drive 32GB','USB Flash Drive 32GB',2,'pc',1,NULL,NULL,'180.0000','0.0000','350.0000','0.00',44,54,13,NULL,1,NULL,1,'20.0000','100.0000','0.0000',1,'2026-10-17 00:06:43',NULL),
(6,'inventory','BAG-001','4800000000066','Laptop Backpack','Laptop Backpack','Laptop Backpack',2,'pc',1,NULL,NULL,'500.0000','0.0000','899.0000','0.00',44,54,13,NULL,1,NULL,1,'10.0000','40.0000','0.0000',1,'2026-10-17 00:06:43',NULL),
(7,'inventory','CAB-HDMI','4800000000073','HDMI Cable 1.5m','HDMI Cable 1.5m','HDMI Cable 1.5m',2,'pc',1,NULL,NULL,'90.0000','0.0000','199.0000','0.00',44,54,13,NULL,1,NULL,1,'20.0000','100.0000','0.0000',1,'2026-10-17 00:06:43',NULL),
(8,'inventory','RAM-8GB','4800000000080','RAM 8GB DDR4','RAM 8GB DDR4','RAM 8GB DDR4',2,'pc',1,NULL,NULL,'1100.0000','0.0000','1690.0000','0.00',44,54,13,NULL,1,NULL,1,'10.0000','40.0000','0.0000',1,'2026-10-17 00:06:43',NULL),
(9,'inventory','SSD-512','4800000000097','SSD 512GB NVMe','SSD 512GB NVMe','SSD 512GB NVMe',2,'pc',1,NULL,NULL,'2200.0000','0.0000','3290.0000','0.00',44,54,13,NULL,1,NULL,1,'10.0000','40.0000','0.0000',1,'2026-10-17 00:06:43',NULL),
(10,'service','LAB-ASM',NULL,'Assembly Labor (per set)','Assembly labor',NULL,3,'hr',5,NULL,NULL,'150.0000','0.0000','0.0000','0.00',45,57,NULL,57,4,NULL,NULL,'0.0000','0.0000','0.0000',1,'2026-10-17 00:06:43',NULL),
(11,'assembly','SET-OFFICE','4800000000103','Office Monitor Set','Monitor + keyboard + mouse + HDMI cable, assembled',NULL,4,'pc',1,NULL,NULL,'0.0000','0.0000','12990.0000','0.00',44,54,13,NULL,1,NULL,NULL,'3.0000','15.0000','3.0000',1,'2026-10-17 00:06:43',NULL),
(12,'service','SRV-INSTALL',NULL,'Installation and Setup','On-site installation and setup',NULL,3,'hr',5,NULL,NULL,'0.0000','0.0000','1500.0000','0.00',45,54,NULL,NULL,1,NULL,NULL,'0.0000','0.0000','0.0000',1,'2026-10-17 00:06:43',NULL),
(13,'service','SRV-REPAIR',NULL,'Repair Service (per hour)','Repair service',NULL,3,'hr',5,NULL,NULL,'0.0000','0.0000','800.0000','0.00',45,54,NULL,NULL,1,NULL,NULL,'0.0000','0.0000','0.0000',1,'2026-10-17 00:06:43',NULL),
(14,'service','SRV-MAINT',NULL,'Monthly IT Maintenance','Monthly IT maintenance contract',NULL,3,'hr',5,NULL,NULL,'0.0000','0.0000','5000.0000','0.00',45,54,NULL,NULL,1,NULL,NULL,'0.0000','0.0000','0.0000',1,'2026-10-17 00:06:43',NULL),
(15,'non_inventory','NI-TONER',NULL,'Toner Cartridge (special order)','Toner cartridge - special order',NULL,5,'pc',1,NULL,NULL,'2500.0000','0.0000','3200.0000','0.00',44,54,NULL,54,1,NULL,2,'0.0000','0.0000','0.0000',1,'2026-10-17 00:06:43',NULL),
(16,'other_charge','DEL-FEE',NULL,'Delivery Fee','Delivery fee',NULL,6,'pc',1,NULL,NULL,'0.0000','0.0000','250.0000','0.00',46,54,NULL,68,1,NULL,NULL,'0.0000','0.0000','0.0000',1,'2026-10-17 00:06:43',NULL),
(17,'other_charge','REIMB',NULL,'Reimbursable Expense','Reimbursable expense',NULL,6,'pc',1,NULL,NULL,'0.0000','0.0000','0.0000','0.00',50,54,NULL,71,4,NULL,NULL,'0.0000','0.0000','0.0000',1,'2026-10-17 00:06:43',NULL),
(18,'other_charge','LATE-FEE',NULL,'Late Payment Fee','Late payment fee',NULL,6,'pc',1,NULL,NULL,'0.0000','0.0000','200.0000','0.00',51,54,NULL,NULL,4,NULL,NULL,'0.0000','0.0000','0.0000',1,'2026-10-17 00:06:43',NULL),
(19,'discount','DISC-10',NULL,'10% Discount','10% discount',NULL,6,'pc',1,NULL,NULL,'0.0000','0.0000','0.0000','10.00',48,54,NULL,NULL,1,NULL,NULL,'0.0000','0.0000','0.0000',1,'2026-10-17 00:06:43',NULL),
(20,'discount','DISC-AMT',NULL,'Fixed Discount','Discount',NULL,6,'pc',1,NULL,NULL,'0.0000','0.0000','100.0000','0.00',48,54,NULL,NULL,1,NULL,NULL,'0.0000','0.0000','0.0000',1,'2026-10-17 00:06:43',NULL),
(21,'subtotal','SUBTOTAL',NULL,'Subtotal','Subtotal',NULL,NULL,'pc',1,NULL,NULL,'0.0000','0.0000','0.0000','0.00',44,54,NULL,NULL,NULL,NULL,NULL,'0.0000','0.0000','0.0000',1,'2026-10-17 00:06:43',NULL),
(22,'group','GRP-WFH',NULL,'Work-from-Home Bundle','Laptop + mouse + backpack',NULL,4,'pc',1,NULL,NULL,'0.0000','0.0000','40000.0000','0.00',44,54,NULL,NULL,NULL,NULL,NULL,'0.0000','0.0000','0.0000',1,'2026-10-17 00:06:43',NULL),
(23,'payment','DOWNPMT',NULL,'Down Payment Received','Less: down payment received',NULL,NULL,'pc',1,NULL,NULL,'0.0000','0.0000','0.0000','0.00',44,54,NULL,NULL,NULL,NULL,NULL,'0.0000','0.0000','0.0000',1,'2026-10-17 00:06:43',NULL),
(24,'inventory','USB-032-BX50','4800000000110','USB Flash Drive 32GB (Box of 50)','USB Flash Drive 32GB, box of 50','USB Flash Drive 32GB, box of 50',2,'box',NULL,NULL,NULL,'8500.0000','0.0000','16500.0000','0.00',44,54,13,NULL,1,NULL,1,'1.0000','5.0000','0.0000',1,'2026-10-17 00:06:43',NULL),
(25,'inventory','TRD-PC',NULL,'Trade-in Desktop PC (used)','Used desktop PC taken in for parts / refurbishing','Trade-in desktop PC',1,'pc',1,NULL,NULL,'3000.0000','0.0000','0.0000','0.00',44,54,13,NULL,1,NULL,NULL,'0.0000','0.0000','0.0000',1,'2026-10-17 00:06:43',NULL),
(26,'inventory','REF-PC',NULL,'Refurbished Desktop PC','Refurbished desktop PC with new SSD, 90-day warranty',NULL,1,'pc',1,NULL,NULL,'0.0000','0.0000','14990.0000','0.00',44,54,13,NULL,1,NULL,NULL,'0.0000','0.0000','0.0000',1,'2026-10-17 00:06:43',NULL),
(27,'inventory','SCRAP-KG',NULL,'Scrap Metal and Plastic','Scrap metal and plastic (sold by the kilo)',NULL,5,'kg',2,NULL,NULL,'15.0000','0.0000','25.0000','0.00',44,54,13,NULL,3,NULL,NULL,'0.0000','0.0000','0.0000',1,'2026-10-17 00:06:43',NULL);

-- item_components (8 rows)
INSERT INTO `item_components` (`parent_item_id`,`component_item_id`,`qty`) VALUES
(11,2,'1.0000'),
(11,3,'1.0000'),
(11,4,'1.0000'),
(11,7,'1.0000'),
(11,10,'1.0000'),
(22,1,'1.0000'),
(22,4,'1.0000'),
(22,6,'1.0000');

-- process_formulas (3 rows)
INSERT INTO `process_formulas` (`id`,`code`,`name`,`process_type`,`alloc_method`,`site_id`,`description`,`is_active`,`created_by`,`created_at`,`updated_at`) VALUES
(1,'BRK-USB50','Break bulk: USB 32GB box of 50','dekit','quantity',NULL,'Open a box of 50 and sell the drives one by one.',1,NULL,'2026-10-17 00:06:43',NULL),
(2,'TD-PC','Trade-in PC teardown','disassembly','sales_value',NULL,'Strip a trade-in PC for resaleable parts; the chassis is sold as scrap by the kilo.',1,NULL,'2026-10-17 00:06:43',NULL),
(3,'RFB-PC','Refurbish trade-in PC (new SSD)','co_product','percent',NULL,'Trade-in PC plus a new SSD become a refurbished PC; the old RAM is recovered for resale.',1,NULL,'2026-10-17 00:06:43',NULL);

-- process_formula_lines (13 rows)
INSERT INTO `process_formula_lines` (`id`,`formula_id`,`line_no`,`line_type`,`item_id`,`account_id`,`description`,`qty`,`output_role`,`alloc_basis`,`amount`) VALUES
(1,1,1,'input',24,NULL,NULL,'1.0000',NULL,'0.0000','0.00'),
(2,1,2,'output',5,NULL,NULL,'50.0000','co_product','0.0000','0.00'),
(3,2,1,'input',25,NULL,NULL,'1.0000',NULL,'0.0000','0.00'),
(4,2,2,'cost',NULL,57,'Technician labor (1 hour)','0.0000',NULL,'0.0000','150.00'),
(5,2,3,'output',8,NULL,NULL,'2.0000','co_product','0.0000','0.00'),
(6,2,4,'output',9,NULL,NULL,'1.0000','co_product','0.0000','0.00'),
(7,2,5,'output',27,NULL,NULL,'4.0000','by_product','15.0000','0.00'),
(8,3,1,'input',25,NULL,NULL,'1.0000',NULL,'0.0000','0.00'),
(9,3,2,'input',9,NULL,NULL,'1.0000',NULL,'0.0000','0.00'),
(10,3,3,'cost',NULL,57,'Refurbishing labor and testing','0.0000',NULL,'0.0000','400.00'),
(11,3,4,'output',26,NULL,NULL,'1.0000','co_product','85.0000','0.00'),
(12,3,5,'output',8,NULL,NULL,'2.0000','co_product','15.0000','0.00'),
(13,3,6,'output',27,NULL,NULL,'1.0000','scrap','0.0000','0.00');

-- price_level_items (1 rows)
INSERT INTO `price_level_items` (`price_level_id`,`item_id`,`custom_price`) VALUES
(2,1,'36500.0000');

-- withholding_taxes (3 rows)
INSERT INTO `withholding_taxes` (`id`,`code`,`atc`,`name`,`tax_kind`,`rate`,`base_type`,`applies_to`,`payable_account_id`,`receivable_account_id`,`description`,`sort_order`,`is_active`,`created_at`,`updated_at`) VALUES
(1,'WT-GOODS','WC158','WT on Goods','income','1.0000','net_of_vat','both',NULL,NULL,'Goods bought from regular suppliers by government payors and top withholding agents (RR 11-2018)',10,1,'2026-10-17 00:06:41',NULL),
(2,'WT-SERVICES','WC160','WT on Services','income','2.0000','net_of_vat','both',NULL,NULL,'Services bought from regular suppliers by government payors and top withholding agents (RR 11-2018)',20,1,'2026-10-17 00:06:41',NULL),
(3,'WT-VAT','WV010','WT on VAT','vat','5.0000','net_of_vat','both',NULL,NULL,'Creditable VAT withheld by government buyers on VATable purchases (5% of the VAT-exclusive payment)',30,1,'2026-10-17 00:06:41',NULL);

-- asset_categories (6 rows)
INSERT INTO `asset_categories` (`id`,`name`,`asset_account_id`,`accum_dep_account_id`,`dep_expense_account_id`,`default_method`,`default_life_years`,`is_active`) VALUES
(1,'Buildings',20,21,67,'straight_line','25.00',1),
(2,'Machinery and Equipment',22,23,67,'straight_line','5.00',1),
(3,'Production Machinery (usage-based)',22,23,67,'units_of_production','5.00',1),
(4,'Transportation Equipment',24,25,67,'declining_balance','5.00',1),
(5,'Furniture and Fixtures',26,27,67,'straight_line','10.00',1),
(6,'Computer and POS Equipment',28,29,67,'declining_balance','3.00',1);

-- pos_terminals (2 rows)
INSERT INTO `pos_terminals` (`id`,`code`,`name`,`site_id`,`cash_account_id`,`receipt_prefix`,`next_receipt_no`,`next_z_no`,`is_active`,`class_id`) VALUES
(1,'POS-01','Makati Counter 1',2,2,'MK1-',1,1,1,NULL),
(2,'POS-02','Cebu Counter 1',3,2,'CB1-',1,1,1,NULL);

-- role_sites (2 rows)
INSERT INTO `role_sites` (`role_id`,`site_id`) VALUES
(7,2),
(7,3);

-- user_sites (2 rows)
INSERT INTO `user_sites` (`user_id`,`site_id`) VALUES
(7,2),
(8,2);

-- user_terminals (2 rows)
INSERT INTO `user_terminals` (`user_id`,`terminal_id`) VALUES
(7,1),
(8,1);

-- ---------------------------------------------------------------------
--  3. AUDIT TRAIL PROTECTION (created after the data is loaded)
-- ---------------------------------------------------------------------
--  Audit trail protection: entries can never be changed or deleted,
--  not even by administrators or directly in the database.
-- ---------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_audit_trail_no_update;
DROP TRIGGER IF EXISTS trg_audit_trail_no_delete;

DELIMITER $$
CREATE TRIGGER trg_audit_trail_no_update BEFORE UPDATE ON audit_trail
FOR EACH ROW
BEGIN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Audit trail entries are read-only and cannot be changed.';
END$$

CREATE TRIGGER trg_audit_trail_no_delete BEFORE DELETE ON audit_trail
FOR EACH ROW
BEGIN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Audit trail entries are permanent and cannot be deleted.';
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
--  v29: the comparative statements (as database/migrations/2026_11_12_comparative_statements_menu.sql)
-- ---------------------------------------------------------------------

SET @cmp_coa  = (SELECT id FROM modules WHERE code = 'coa' LIMIT 1);
SET @cmp_sort = (SELECT COALESCE(MAX(sort_order), 300) FROM pages WHERE page_key = 'rpt.income_statement_class');

INSERT IGNORE INTO pages (page_key, module_id, name, page_type, menu_group, sort_order, show_in_menu) VALUES
  ('rpt.cmp_is_month',   @cmp_coa, 'Comparative Income Statement by Month',        'report', 'Reports', @cmp_sort + 1, 1),
  ('rpt.cmp_is_quarter', @cmp_coa, 'Comparative Income Statement by Quarter',      'report', 'Reports', @cmp_sort + 2, 1),
  ('rpt.cmp_is_year',    @cmp_coa, 'Comparative Income Statement by Year',         'report', 'Reports', @cmp_sort + 3, 1),
  ('rpt.cmp_is_custom',  @cmp_coa, 'Comparative Income Statement by Custom Range', 'report', 'Reports', @cmp_sort + 4, 1),
  ('rpt.cmp_bs_month',   @cmp_coa, 'Comparative Balance Sheet by Month',           'report', 'Reports', @cmp_sort + 5, 1),
  ('rpt.cmp_bs_quarter', @cmp_coa, 'Comparative Balance Sheet by Quarter',         'report', 'Reports', @cmp_sort + 6, 1),
  ('rpt.cmp_bs_year',    @cmp_coa, 'Comparative Balance Sheet by Year',            'report', 'Reports', @cmp_sort + 7, 1),
  ('rpt.cmp_bs_custom',  @cmp_coa, 'Comparative Balance Sheet by Custom Date',     'report', 'Reports', @cmp_sort + 8, 1);

INSERT IGNORE INTO role_page_access (role_id, page_id, allowed, can_create, can_edit, can_delete, can_print, can_approve)
SELECT src.role_id, dst.id, 1, 0, 0, 0, src.can_print, 0
  FROM role_page_access src
  JOIN pages sp  ON sp.id = src.page_id AND sp.page_key = 'rpt.income_statement'
  JOIN pages dst ON dst.page_key IN ('rpt.cmp_is_month', 'rpt.cmp_is_quarter', 'rpt.cmp_is_year', 'rpt.cmp_is_custom')
 WHERE src.allowed = 1;

INSERT IGNORE INTO role_page_access (role_id, page_id, allowed, can_create, can_edit, can_delete, can_print, can_approve)
SELECT src.role_id, dst.id, 1, 0, 0, 0, src.can_print, 0
  FROM role_page_access src
  JOIN pages sp  ON sp.id = src.page_id AND sp.page_key = 'rpt.balance_sheet'
  JOIN pages dst ON dst.page_key IN ('rpt.cmp_bs_month', 'rpt.cmp_bs_quarter', 'rpt.cmp_bs_year', 'rpt.cmp_bs_custom')
 WHERE src.allowed = 1;


-- ---------------------------------------------------------------------
--  v31: the Average Cost Changes report (as database/migrations/2026_11_26_average_cost_books.sql)
-- ---------------------------------------------------------------------

SET @acc_mod  = (SELECT module_id FROM pages WHERE page_key = 'rpt.inv_valuation_detail' LIMIT 1);
SET @acc_sort = (SELECT COALESCE(MAX(sort_order), 1240) FROM pages WHERE page_key = 'rpt.inv_valuation_detail');

INSERT IGNORE INTO pages (page_key, module_id, name, page_type, menu_group, sort_order, show_in_menu) VALUES
  ('rpt.avg_cost_changes', @acc_mod, 'Average Cost Changes', 'report', 'Inventory Reports', @acc_sort + 5, 1);

INSERT IGNORE INTO role_page_access (role_id, page_id, allowed, can_create, can_edit, can_delete, can_print, can_approve)
SELECT src.role_id, dst.id, 1, 0, 0, 0, src.can_print, 0
  FROM role_page_access src
  JOIN pages sp  ON sp.id = src.page_id AND sp.page_key = 'rpt.inv_valuation_detail'
  JOIN pages dst ON dst.page_key = 'rpt.avg_cost_changes'
 WHERE src.allowed = 1;

SET FOREIGN_KEY_CHECKS = 1;
