-- =====================================================================
--  G-SMaRT Accounting - complete database
--  Generated 2026-10-17 00:06:40 +08:00 from database `accounting_system`
--  74 tables, 1952 rows (81 transactions)
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
('adopt_group_price','1','2026-10-17 00:06:36'),
('allow_negative_stock','1','2026-10-17 00:06:36'),
('audit_retention_years','10','2026-10-17 00:06:36'),
('bir_signatory_name','','2026-10-17 00:06:36'),
('bir_signatory_tin','','2026-10-17 00:06:36'),
('bir_signatory_title','','2026-10-17 00:06:36'),
('bir_zip_code','','2026-10-17 00:06:36'),
('bt_printer_autoprint','0','2026-10-17 00:06:36'),
('bt_printer_cut','0','2026-10-17 00:06:36'),
('bt_printer_enabled','0','2026-10-17 00:06:36'),
('bt_printer_feed','4','2026-10-17 00:06:36'),
('bt_printer_name','','2026-10-17 00:06:36'),
('bt_printer_width','32','2026-10-17 00:06:36'),
('closing_date','2026-07-29','2026-10-17 00:06:40'),
('company_address','123 Rizal Avenue, Makati City, Metro Manila','2026-10-17 00:06:36'),
('company_email','accounting@sampletrading.test','2026-10-17 00:06:36'),
('company_logo','','2026-10-17 00:06:36'),
('company_name','Sample Trading Company','2026-10-17 00:06:36'),
('company_phone','(02) 8123-4567','2026-10-17 00:06:36'),
('company_tin','000-123-456-000','2026-10-17 00:06:36'),
('costing_method','weighted_average','2026-10-17 00:06:36'),
('finance_charge_grace_days','0','2026-10-17 00:06:36'),
('finance_charge_min','50','2026-10-17 00:06:36'),
('finance_charge_on_charges','0','2026-10-17 00:06:36'),
('finance_charge_rate','12','2026-10-17 00:06:36'),
('fiscal_year_start_month','1','2026-10-17 00:06:36'),
('item_search_by_page','','2026-10-17 00:06:36'),
('item_search_format','code_name','2026-10-17 00:06:36'),
('large_discount_pct','10','2026-10-17 00:06:36'),
('logo_targets','','2026-10-17 00:06:36'),
('max_failed_logins','5','2026-10-17 00:06:36'),
('pos_posting_mode','per_sale','2026-10-17 00:06:36'),
('pos_receipt_footer','Thank you for shopping!\nThis serves as your official receipt.','2026-10-17 00:06:36'),
('pos_receipt_show_customer','1','2026-10-17 00:06:36'),
('pos_receipt_title','OFFICIAL RECEIPT','2026-10-17 00:06:36'),
('pos_receipt_title_charge','CHARGE INVOICE','2026-10-17 00:06:36'),
('pos_receipt_title_payment','ACKNOWLEDGEMENT RECEIPT','2026-10-17 00:06:36'),
('pos_receipt_title_return','RETURN / REFUND','2026-10-17 00:06:36'),
('pw_expiry_days','90','2026-10-17 00:06:36'),
('pw_min_length','8','2026-10-17 00:06:36'),
('pw_require_number','1','2026-10-17 00:06:36'),
('pw_require_symbol','1','2026-10-17 00:06:36'),
('pw_require_upper','1','2026-10-17 00:06:36'),
('session_timeout_minutes','30','2026-10-17 00:06:36'),
('track_group_sales','1','2026-10-17 00:06:36'),
('withholding_agent','1','2026-10-17 00:06:36');

-- users (9 rows)
INSERT INTO `users` (`id`,`username`,`password_hash`,`full_name`,`email`,`employee_no`,`pos_default_site_id`,`pos_default_class_id`,`status`,`approval_status`,`created_via`,`approved_by`,`approved_at`,`rejected_reason`,`is_platform`,`must_change_password`,`password_changed_at`,`failed_attempts`,`last_login_at`,`last_login_ip`,`created_by`,`created_at`,`updated_at`) VALUES
(1,'admin','$2y$12$ePC8xidyV50OJXoYX8uGAOQ7JarVOa6c4u5pyYGdiv7dMxhvmg1em','System Administrator','admin@sampletrading.test','EMP-001',NULL,NULL,'active','approved','admin',NULL,NULL,NULL,0,1,'2026-10-17 00:06:37',0,NULL,NULL,NULL,'2026-10-17 00:06:37',NULL),
(2,'accountant','$2y$12$H9Tk2IEBmg55goClqzvlwOeevKp73en7/rrAqtUxfGaJRu7YHpBIu','Ana Cruz','accountant@sampletrading.test','EMP-002',NULL,NULL,'active','approved','admin',NULL,NULL,NULL,0,0,'2026-10-17 00:06:37',0,NULL,NULL,NULL,'2026-10-17 00:06:37',NULL),
(3,'arclerk','$2y$12$vyd7Nkv7ayQmOwuvzwcQJOwUXtfIdgpJ4IiowbL0Pi6abU/AJRcaC','Ben Garcia','arclerk@sampletrading.test','EMP-003',NULL,NULL,'active','approved','admin',NULL,NULL,NULL,0,0,'2026-10-17 00:06:37',0,NULL,NULL,NULL,'2026-10-17 00:06:37',NULL),
(4,'apclerk','$2y$12$7/JNfldcQaw7zAy/8LYApeUHxGake5vdMUN.I0cg7lcVEzEBV0AvW','Carla Lim','apclerk@sampletrading.test','EMP-004',NULL,NULL,'active','approved','admin',NULL,NULL,NULL,0,0,'2026-10-17 00:06:38',2,NULL,NULL,NULL,'2026-10-17 00:06:38','2026-10-17 00:06:40'),
(5,'invclerk','$2y$12$do80hDDlLRS6fHXd3Bo/IO3AmRgeli2jdMM9scRnSUMXzS/rC7vlq','Dan Villanueva','invclerk@sampletrading.test','EMP-005',NULL,NULL,'active','approved','admin',NULL,NULL,NULL,0,0,'2026-10-17 00:06:38',0,NULL,NULL,NULL,'2026-10-17 00:06:38',NULL),
(6,'salesrep','$2y$12$oF8BJ6q261cxXPmi09gis.i93wWb/CeVuY5Nhrqaeklo.uoC1LpGi','Maria Santos','salesrep@sampletrading.test','EMP-006',NULL,NULL,'active','approved','admin',NULL,NULL,NULL,0,0,'2026-10-17 00:06:38',0,NULL,NULL,NULL,'2026-10-17 00:06:38',NULL),
(7,'cashier1','$2y$12$xrKQB29fXKEGy4MgOdIspOOWSG4pDV4eV3Y0n8qtOfthlVUyWEjKW','Ella Ramos','cashier1@sampletrading.test','EMP-007',NULL,NULL,'active','approved','admin',NULL,NULL,NULL,0,0,'2026-10-17 00:06:38',0,NULL,NULL,NULL,'2026-10-17 00:06:38',NULL),
(8,'supervisor','$2y$12$c2sLff8PJntOGfs5f4QkfesVA5pbD9AaQOgYbGOiEJNGSZ9id34mC','Fred Tan','supervisor@sampletrading.test','EMP-008',NULL,NULL,'active','approved','admin',NULL,NULL,NULL,0,0,'2026-10-17 00:06:39',0,NULL,NULL,NULL,'2026-10-17 00:06:39',NULL),
(9,'auditor','$2y$12$e.9nGAgBymmwNCa3yokVJ.KJjevsaIDYmMIAcPKKkj4oVl/ttGuzy','Grace Uy','auditor@sampletrading.test','EMP-009',NULL,NULL,'active','approved','admin',NULL,NULL,NULL,0,0,'2026-10-17 00:06:39',0,NULL,NULL,NULL,'2026-10-17 00:06:39',NULL);

-- roles (9 rows)
INSERT INTO `roles` (`id`,`name`,`description`,`is_admin`,`is_system`,`all_sites`,`created_at`,`updated_at`) VALUES
(1,'Administrator','Everything in every module, including user accounts, roles, page access, the closing date, and the audit trail.',1,1,1,'2026-10-17 00:06:36',NULL),
(2,'Accountant','Chart of Accounts, Fixed Assets, Banking and reconciliation, the BIR Reports and Withholding Tax Table, all module reports, and the financial statements.',0,1,1,'2026-10-17 00:06:36',NULL),
(3,'A/R Clerk','Customers module transactions and the Customer and Receivables reports.',0,1,1,'2026-10-17 00:06:36',NULL),
(4,'A/P Clerk','Vendors module transactions, Pay Bills, advances to suppliers, the Vendors and Payables reports, and BIR Form 2307 for suppliers.',0,1,1,'2026-10-17 00:06:36',NULL),
(5,'Inventory Clerk','Items, sites, receiving, adjustments, assembly builds, disassembly and processing orders, stock counts, and inventory quantity reports.',0,1,1,'2026-10-17 00:06:36',NULL),
(6,'Sales Representative','Estimates, sales orders, and invoices, and the Sales reports.',0,1,1,'2026-10-17 00:06:36',NULL),
(7,'Cashier','POS sales, returns, and cash drops at the assigned terminal only.',0,1,0,'2026-10-17 00:06:36',NULL),
(8,'POS Supervisor','Everything a cashier can do, plus approving voids, refunds, price overrides, and large discounts, and running X- and Z-readings.',0,1,1,'2026-10-17 00:06:36',NULL),
(9,'Auditor','View-only access to all transactions, reports, and the audit trail. Cannot create or change anything.',0,1,1,'2026-10-17 00:06:36',NULL);

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

-- user_page_overrides (2 rows)
INSERT INTO `user_page_overrides` (`user_id`,`page_id`,`allowed`,`can_create`,`can_edit`,`can_delete`,`can_print`,`can_approve`,`reason`,`created_by`,`created_at`) VALUES
(3,56,0,0,0,0,0,0,'Finance charges are assessed by the accountant',1,'2026-10-17 00:06:40'),
(6,62,1,0,0,0,1,0,'Needs balances for account visits',1,'2026-10-17 00:06:40');

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

-- audit_trail (109 rows)
INSERT INTO `audit_trail` (`id`,`created_at`,`user_id`,`username`,`user_roles`,`ip_address`,`workstation`,`site_id`,`terminal_id`,`module`,`page_key`,`action`,`record_type`,`record_id`,`record_ref`,`amount`,`changes`,`snapshot`,`reason`,`approved_by`) VALUES
(1,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',NULL,NULL,'coa','coa.journal','create','transaction',1,'Opening Balance OB-0001','3320000.00',NULL,'{\"txn_type\":\"opening_balance\",\"txn_no\":\"OB-0001\",\"txn_date\":\"2026-07-29\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Opening balances\",\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"3320000.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"journal\",\"item\":null,\"account\":\"1010\",\"description\":\"BDO checking opening balance\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"2500000.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"journal\",\"item\":null,\"account\":\"1020\",\"description\":\"BPI savings opening balance\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"800000.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"journal\",\"item\":null,\"account\":\"1005\",\"description\":\"Petty cash fund\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"10000.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"journal\",\"item\":null,\"account\":\"1001\",\"description\":\"Register cash funds\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"10000.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"journal\",\"item\":null,\"account\":\"3000\",\"description\":\"Owner\'s capital\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"-3320000.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(2,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',NULL,NULL,'bank','bank.write_checks','create','transaction',2,'Check 1001','500000.00',NULL,'{\"txn_type\":\"check\",\"txn_no\":\"1001\",\"txn_date\":\"2026-08-01\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Purchase of Packaging Machine PM-500\",\"subtotal\":\"500000.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"500000.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":\"Industrial Machines Corp.\",\"account\":\"Cash in Bank - BDO Checking\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"expense\",\"item\":null,\"account\":\"1520\",\"description\":\"Packaging Machine PM-500\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"500000.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(3,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',NULL,NULL,'fa','fa.register','create','asset',1,'FA-00001 Packaging Machine PM-500','500000.00',NULL,NULL,NULL,NULL),
(4,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',NULL,NULL,'vend','vend.bills','create','transaction',3,'Bill BILL-00001','1200000.00',NULL,'{\"txn_type\":\"bill\",\"txn_no\":\"BILL-00001\",\"txn_date\":\"2026-08-01\",\"due_date\":\"2026-08-31\",\"ref_no\":\"IMC-5521\",\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":3,\"sales_rep_id\":null,\"memo\":\"Purchase of Delivery Van (L300)\",\"subtotal\":\"1200000.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"1200000.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":\"Industrial Machines Corp.\",\"account\":\"Accounts Payable\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"expense\",\"item\":null,\"account\":\"1530\",\"description\":\"Delivery Van (L300)\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"1200000.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(5,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',NULL,NULL,'fa','fa.register','create','asset',2,'FA-00002 Delivery Van (L300)','1200000.00',NULL,NULL,NULL,NULL),
(6,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',NULL,NULL,'bank','bank.write_checks','create','transaction',4,'Check 1002','60000.00',NULL,'{\"txn_type\":\"check\",\"txn_no\":\"1002\",\"txn_date\":\"2026-08-01\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Purchase of POS Terminal Set (Makati)\",\"subtotal\":\"60000.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"60000.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":\"TechDistributors Inc.\",\"account\":\"Cash in Bank - BDO Checking\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"expense\",\"item\":null,\"account\":\"1550\",\"description\":\"POS Terminal Set (Makati)\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"60000.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(7,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',NULL,NULL,'fa','fa.register','create','asset',3,'FA-00003 POS Terminal Set (Makati)','60000.00',NULL,NULL,NULL,NULL),
(8,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',NULL,NULL,'vend','vend.bills','create','transaction',5,'Bill BILL-00002','500000.00',NULL,'{\"txn_type\":\"bill\",\"txn_no\":\"BILL-00002\",\"txn_date\":\"2026-08-01\",\"due_date\":\"2026-08-31\",\"ref_no\":\"IMC-5530\",\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":3,\"sales_rep_id\":null,\"memo\":\"Purchase of Printing Machine PR-300\",\"subtotal\":\"500000.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"500000.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":\"Industrial Machines Corp.\",\"account\":\"Accounts Payable\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"expense\",\"item\":null,\"account\":\"1520\",\"description\":\"Printing Machine PR-300\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"500000.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(9,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',NULL,NULL,'fa','fa.register','create','asset',4,'FA-00004 Printing Machine PR-300','500000.00',NULL,NULL,NULL,NULL),
(10,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',NULL,NULL,'vend','vend.bills','create','transaction',6,'Bill BILL-00003','12500.00',NULL,'{\"txn_type\":\"bill\",\"txn_no\":\"BILL-00003\",\"txn_date\":\"2026-09-27\",\"due_date\":\"2026-10-27\",\"ref_no\":\"IMC-SV-0192\",\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":3,\"sales_rep_id\":null,\"memo\":\"Repair of FA-00002 Delivery Van (L300) (MNT-00001)\",\"subtotal\":\"12500.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"12500.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":\"Industrial Machines Corp.\",\"account\":\"Accounts Payable\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"expense\",\"item\":null,\"account\":\"6030\",\"description\":\"Parts - MNT-00001 FA-00002 Delivery Van (L300)\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"11000.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"expense\",\"item\":null,\"account\":\"6030\",\"description\":\"Labor - MNT-00001 FA-00002 Delivery Van (L300)\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"1500.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}','Maintenance record MNT-00001',NULL),
(11,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',1,NULL,'vend','vend.purchase_orders','create','transaction',7,'Purchase Order PO-00001','1201984.00',NULL,'{\"txn_type\":\"purchase_order\",\"txn_no\":\"PO-00001\",\"txn_date\":\"2026-08-03\",\"due_date\":\"2026-08-08\",\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Initial stock\",\"subtotal\":\"1073200.00\",\"tax_total\":\"128784.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"1201984.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":\"TechDistributors Inc.\",\"account\":null,\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"LAP-001\",\"account\":null,\"description\":\"Laptop 14-inch i5 16GB\",\"qty\":\"20.0000\",\"rate\":\"32000.0000\",\"discount_amount\":\"0.00\",\"amount\":\"640000.00\",\"tax_amount\":\"76800.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"MON-024\",\"account\":null,\"description\":\"Monitor 24-inch IPS\",\"qty\":\"40.0000\",\"rate\":\"6500.0000\",\"discount_amount\":\"0.00\",\"amount\":\"260000.00\",\"tax_amount\":\"31200.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"KEY-001\",\"account\":null,\"description\":\"Keyboard USB\",\"qty\":\"60.0000\",\"rate\":\"650.0000\",\"discount_amount\":\"0.00\",\"amount\":\"39000.00\",\"tax_amount\":\"4680.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"MOU-001\",\"account\":null,\"description\":\"Wireless Mouse\",\"qty\":\"80.0000\",\"rate\":\"350.0000\",\"discount_amount\":\"0.00\",\"amount\":\"28000.00\",\"tax_amount\":\"3360.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"USB-032\",\"account\":null,\"description\":\"USB Flash Drive 32GB\",\"qty\":\"100.0000\",\"rate\":\"180.0000\",\"discount_amount\":\"0.00\",\"amount\":\"18000.00\",\"tax_amount\":\"2160.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"BAG-001\",\"account\":null,\"description\":\"Laptop Backpack\",\"qty\":\"30.0000\",\"rate\":\"500.0000\",\"discount_amount\":\"0.00\",\"amount\":\"15000.00\",\"tax_amount\":\"1800.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"CAB-HDMI\",\"account\":null,\"description\":\"HDMI Cable 1.5m\",\"qty\":\"80.0000\",\"rate\":\"90.0000\",\"discount_amount\":\"0.00\",\"amount\":\"7200.00\",\"tax_amount\":\"864.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"RAM-8GB\",\"account\":null,\"description\":\"RAM 8GB DDR4\",\"qty\":\"20.0000\",\"rate\":\"1100.0000\",\"discount_amount\":\"0.00\",\"amount\":\"22000.00\",\"tax_amount\":\"2640.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"SSD-512\",\"account\":null,\"description\":\"SSD 512GB NVMe\",\"qty\":\"20.0000\",\"rate\":\"2200.0000\",\"discount_amount\":\"0.00\",\"amount\":\"44000.00\",\"tax_amount\":\"5280.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(12,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',1,NULL,'vend','vend.bills','create','transaction',8,'Bill BILL-00004','1128064.00',NULL,'{\"txn_type\":\"bill\",\"txn_no\":\"BILL-00004\",\"txn_date\":\"2026-08-06\",\"due_date\":\"2026-09-05\",\"ref_no\":\"TD-INV-10231\",\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":3,\"sales_rep_id\":null,\"memo\":\"Received against Purchase Order PO-00001\",\"subtotal\":\"1007200.00\",\"tax_total\":\"120864.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"1128064.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":\"TechDistributors Inc.\",\"account\":\"Accounts Payable\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"LAP-001\",\"account\":null,\"description\":\"Laptop 14-inch i5 16GB\",\"qty\":\"20.0000\",\"rate\":\"32000.0000\",\"discount_amount\":\"0.00\",\"amount\":\"640000.00\",\"tax_amount\":\"76800.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"MON-024\",\"account\":null,\"description\":\"Monitor 24-inch IPS\",\"qty\":\"40.0000\",\"rate\":\"6500.0000\",\"discount_amount\":\"0.00\",\"amount\":\"260000.00\",\"tax_amount\":\"31200.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"KEY-001\",\"account\":null,\"description\":\"Keyboard USB\",\"qty\":\"60.0000\",\"rate\":\"650.0000\",\"discount_amount\":\"0.00\",\"amount\":\"39000.00\",\"tax_amount\":\"4680.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"MOU-001\",\"account\":null,\"description\":\"Wireless Mouse\",\"qty\":\"80.0000\",\"rate\":\"350.0000\",\"discount_amount\":\"0.00\",\"amount\":\"28000.00\",\"tax_amount\":\"3360.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"USB-032\",\"account\":null,\"description\":\"USB Flash Drive 32GB\",\"qty\":\"100.0000\",\"rate\":\"180.0000\",\"discount_amount\":\"0.00\",\"amount\":\"18000.00\",\"tax_amount\":\"2160.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"BAG-001\",\"account\":null,\"description\":\"Laptop Backpack\",\"qty\":\"30.0000\",\"rate\":\"500.0000\",\"discount_amount\":\"0.00\",\"amount\":\"15000.00\",\"tax_amount\":\"1800.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"CAB-HDMI\",\"account\":null,\"description\":\"HDMI Cable 1.5m\",\"qty\":\"80.0000\",\"rate\":\"90.0000\",\"discount_amount\":\"0.00\",\"amount\":\"7200.00\",\"tax_amount\":\"864.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(13,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',1,NULL,'vend','vend.receive_items','create','transaction',9,'Item Receipt IR-00001','66000.00',NULL,'{\"txn_type\":\"item_receipt\",\"txn_no\":\"IR-00001\",\"txn_date\":\"2026-08-08\",\"due_date\":null,\"ref_no\":\"DS-7781\",\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":null,\"subtotal\":\"66000.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"66000.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":\"TechDistributors Inc.\",\"account\":\"Accounts Payable\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"RAM-8GB\",\"account\":null,\"description\":\"RAM 8GB DDR4\",\"qty\":\"20.0000\",\"rate\":\"1100.0000\",\"discount_amount\":\"0.00\",\"amount\":\"22000.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"SSD-512\",\"account\":null,\"description\":\"SSD 512GB NVMe\",\"qty\":\"20.0000\",\"rate\":\"2200.0000\",\"discount_amount\":\"0.00\",\"amount\":\"44000.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(14,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',1,NULL,'vend','vend.bills','convert','transaction',9,'Bill BILL-00005','75040.00','[{\"field\":\"txn_type\",\"old\":\"item_receipt\",\"new\":\"bill\"},{\"field\":\"txn_no\",\"old\":\"IR-00001\",\"new\":\"BILL-00005\"},{\"field\":\"txn_date\",\"old\":\"2026-08-08\",\"new\":\"2026-08-12\"},{\"field\":\"due_date\",\"old\":null,\"new\":\"2026-09-11\"},{\"field\":\"ref_no\",\"old\":\"DS-7781\",\"new\":\"TD-INV-10288\"},{\"field\":\"terms_id\",\"old\":null,\"new\":3},{\"field\":\"memo\",\"old\":null,\"new\":\"Bill for received items\"},{\"field\":\"subtotal\",\"old\":\"66000.00\",\"new\":\"67000.00\"},{\"field\":\"tax_total\",\"old\":\"0.00\",\"new\":\"8040.00\"},{\"field\":\"total\",\"old\":\"66000.00\",\"new\":\"75040.00\"},{\"field\":\"lines[1].tax_amount\",\"old\":\"0.00\",\"new\":\"2640.00\"},{\"field\":\"lines[2].rate\",\"old\":\"2200.0000\",\"new\":\"2250.0000\"},{\"field\":\"lines[2].amount\",\"old\":\"44000.00\",\"new\":\"45000.00\"},{\"field\":\"lines[2].tax_amount\",\"old\":\"0.00\",\"new\":\"5400.00\"}]','{\"txn_type\":\"bill\",\"txn_no\":\"BILL-00005\",\"txn_date\":\"2026-08-12\",\"due_date\":\"2026-09-11\",\"ref_no\":\"TD-INV-10288\",\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":3,\"sales_rep_id\":null,\"memo\":\"Bill for received items\",\"subtotal\":\"67000.00\",\"tax_total\":\"8040.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"75040.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":\"TechDistributors Inc.\",\"account\":\"Accounts Payable\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"RAM-8GB\",\"account\":null,\"description\":\"RAM 8GB DDR4\",\"qty\":\"20.0000\",\"rate\":\"1100.0000\",\"discount_amount\":\"0.00\",\"amount\":\"22000.00\",\"tax_amount\":\"2640.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"SSD-512\",\"account\":null,\"description\":\"SSD 512GB NVMe\",\"qty\":\"20.0000\",\"rate\":\"2250.0000\",\"discount_amount\":\"0.00\",\"amount\":\"45000.00\",\"tax_amount\":\"5400.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(15,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',1,NULL,'vend','vend.purchase_orders','create','transaction',10,'Purchase Order PO-00002','376880.00',NULL,'{\"txn_type\":\"purchase_order\",\"txn_no\":\"PO-00002\",\"txn_date\":\"2026-10-12\",\"due_date\":\"2026-10-24\",\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Restock laptops and RAM\",\"subtotal\":\"336500.00\",\"tax_total\":\"40380.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"376880.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":\"TechDistributors Inc.\",\"account\":null,\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"LAP-001\",\"account\":null,\"description\":\"Laptop 14-inch i5 16GB\",\"qty\":\"10.0000\",\"rate\":\"32000.0000\",\"discount_amount\":\"0.00\",\"amount\":\"320000.00\",\"tax_amount\":\"38400.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"RAM-8GB\",\"account\":null,\"description\":\"RAM 8GB DDR4\",\"qty\":\"15.0000\",\"rate\":\"1100.0000\",\"discount_amount\":\"0.00\",\"amount\":\"16500.00\",\"tax_amount\":\"1980.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(16,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',NULL,NULL,'vend','vend.bills','create','transaction',11,'Bill BILL-00006','11200.00',NULL,'{\"txn_type\":\"bill\",\"txn_no\":\"BILL-00006\",\"txn_date\":\"2026-09-07\",\"due_date\":\"2026-09-22\",\"ref_no\":\"OD-99812\",\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":2,\"sales_rep_id\":null,\"memo\":null,\"subtotal\":\"10000.00\",\"tax_total\":\"1200.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"11200.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":\"Office Depot PH\",\"account\":\"Accounts Payable\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"NI-TONER\",\"account\":null,\"description\":\"Toner Cartridge (special order)\",\"qty\":\"4.0000\",\"rate\":\"2500.0000\",\"discount_amount\":\"0.00\",\"amount\":\"10000.00\",\"tax_amount\":\"1200.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(17,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',1,NULL,'vend','vend.bills','create','transaction',12,'Bill BILL-00007','80640.00',NULL,'{\"txn_type\":\"bill\",\"txn_no\":\"BILL-00007\",\"txn_date\":\"2026-09-09\",\"due_date\":\"2026-10-09\",\"ref_no\":\"TD-INV-10344\",\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":3,\"sales_rep_id\":null,\"memo\":\"Keyboards bought by the box\",\"subtotal\":\"72000.00\",\"tax_total\":\"8640.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"80640.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":\"TechDistributors Inc.\",\"account\":\"Accounts Payable\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"KEY-001\",\"account\":null,\"description\":\"Keyboard USB (box of 24)\",\"qty\":\"120.0000\",\"rate\":\"600.0000\",\"discount_amount\":\"0.00\",\"amount\":\"72000.00\",\"tax_amount\":\"8640.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(18,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',1,NULL,'inv','inv.transfers','create','transaction',13,'Inventory Transfer IT-00001','0.00',NULL,'{\"txn_type\":\"inventory_transfer\",\"txn_no\":\"IT-00001\",\"txn_date\":\"2026-08-14\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":2,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Stock for store\",\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"0.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"LAP-001\",\"account\":null,\"description\":\"Store stock\",\"qty\":\"4.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"MON-024\",\"account\":null,\"description\":\"Store stock\",\"qty\":\"6.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"KEY-001\",\"account\":null,\"description\":\"Store stock\",\"qty\":\"10.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"MOU-001\",\"account\":null,\"description\":\"Store stock\",\"qty\":\"20.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"USB-032\",\"account\":null,\"description\":\"Store stock\",\"qty\":\"30.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"BAG-001\",\"account\":null,\"description\":\"Store stock\",\"qty\":\"8.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"CAB-HDMI\",\"account\":null,\"description\":\"Store stock\",\"qty\":\"15.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(19,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',1,NULL,'inv','inv.transfers','create','transaction',14,'Inventory Transfer IT-00002','0.00',NULL,'{\"txn_type\":\"inventory_transfer\",\"txn_no\":\"IT-00002\",\"txn_date\":\"2026-08-15\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":3,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Stock for store\",\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"0.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"LAP-001\",\"account\":null,\"description\":\"Store stock\",\"qty\":\"4.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"MON-024\",\"account\":null,\"description\":\"Store stock\",\"qty\":\"6.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"KEY-001\",\"account\":null,\"description\":\"Store stock\",\"qty\":\"10.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"MOU-001\",\"account\":null,\"description\":\"Store stock\",\"qty\":\"20.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"USB-032\",\"account\":null,\"description\":\"Store stock\",\"qty\":\"30.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"BAG-001\",\"account\":null,\"description\":\"Store stock\",\"qty\":\"8.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"CAB-HDMI\",\"account\":null,\"description\":\"Store stock\",\"qty\":\"15.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(20,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',1,NULL,'inv','inv.build','create','transaction',15,'Build Assembly BLD-00001','0.00',NULL,'{\"txn_type\":\"build_assembly\",\"txn_no\":\"BLD-00001\",\"txn_date\":\"2026-08-18\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Weekly build\",\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"0.00\",\"status\":\"completed\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"SET-OFFICE\",\"account\":null,\"description\":\"Office Monitor Set\",\"qty\":\"5.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"component\",\"item\":\"MON-024\",\"account\":null,\"description\":\"Component\",\"qty\":\"5.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"component\",\"item\":\"KEY-001\",\"account\":null,\"description\":\"Component\",\"qty\":\"5.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"component\",\"item\":\"MOU-001\",\"account\":null,\"description\":\"Component\",\"qty\":\"5.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"component\",\"item\":\"CAB-HDMI\",\"account\":null,\"description\":\"Component\",\"qty\":\"5.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"component\",\"item\":\"LAB-ASM\",\"account\":null,\"description\":\"Component\",\"qty\":\"5.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(21,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',1,NULL,'inv','inv.transfers','create','transaction',16,'Inventory Transfer IT-00003','0.00',NULL,'{\"txn_type\":\"inventory_transfer\",\"txn_no\":\"IT-00003\",\"txn_date\":\"2026-08-19\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":2,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Display set for Makati store\",\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"0.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"SET-OFFICE\",\"account\":null,\"description\":\"Office Monitor Set\",\"qty\":\"2.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(22,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',1,NULL,'inv','inv.build','create','transaction',17,'Build Assembly BLD-00002','0.00',NULL,'{\"txn_type\":\"build_assembly\",\"txn_no\":\"BLD-00002\",\"txn_date\":\"2026-10-14\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Waiting for monitors\",\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"0.00\",\"status\":\"pending\",\"is_pending\":1,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"SET-OFFICE\",\"account\":null,\"description\":\"Office Monitor Set\",\"qty\":\"30.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"component\",\"item\":\"MON-024\",\"account\":null,\"description\":\"Component\",\"qty\":\"30.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"component\",\"item\":\"KEY-001\",\"account\":null,\"description\":\"Component\",\"qty\":\"30.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"component\",\"item\":\"MOU-001\",\"account\":null,\"description\":\"Component\",\"qty\":\"30.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"component\",\"item\":\"CAB-HDMI\",\"account\":null,\"description\":\"Component\",\"qty\":\"30.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"component\",\"item\":\"LAB-ASM\",\"account\":null,\"description\":\"Component\",\"qty\":\"30.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(23,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',1,NULL,'vend','vend.bills','create','transaction',18,'Bill BILL-00008','48720.00',NULL,'{\"txn_type\":\"bill\",\"txn_no\":\"BILL-00008\",\"txn_date\":\"2026-09-01\",\"due_date\":\"2026-10-01\",\"ref_no\":\"TD-INV-10390\",\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":3,\"sales_rep_id\":null,\"memo\":\"Bulk USB boxes and trade-in PCs\",\"subtotal\":\"43500.00\",\"tax_total\":\"5220.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"48720.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":\"TechDistributors Inc.\",\"account\":\"Accounts Payable\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"USB-032-BX50\",\"account\":null,\"description\":\"USB Flash Drive 32GB (Box of 50)\",\"qty\":\"3.0000\",\"rate\":\"8500.0000\",\"discount_amount\":\"0.00\",\"amount\":\"25500.00\",\"tax_amount\":\"3060.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"TRD-PC\",\"account\":null,\"description\":\"Trade-in Desktop PC (used)\",\"qty\":\"6.0000\",\"rate\":\"3000.0000\",\"discount_amount\":\"0.00\",\"amount\":\"18000.00\",\"tax_amount\":\"2160.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(24,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',1,NULL,'inv','inv.process','create','transaction',19,'Processing Order PRC-00001','17000.00',NULL,'{\"txn_type\":\"item_processing\",\"txn_no\":\"PRC-00001\",\"txn_date\":\"2026-09-07\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Opened two boxes for single-unit sales\",\"subtotal\":\"17000.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"17000.00\",\"status\":\"completed\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":\"dekit\",\"alloc_method\":\"quantity\",\"process_formula_id\":1,\"process_batches\":\"2.0000\",\"customer\":null,\"vendor\":null,\"account\":null,\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"input\",\"item\":\"USB-032-BX50\",\"account\":null,\"description\":\"USB Flash Drive 32GB (Box of 50)\",\"qty\":\"2.0000\",\"rate\":\"8500.0000\",\"discount_amount\":\"0.00\",\"amount\":\"17000.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"output\",\"item\":\"USB-032\",\"account\":null,\"description\":\"USB Flash Drive 32GB\",\"qty\":\"100.0000\",\"rate\":\"170.0000\",\"discount_amount\":\"0.00\",\"amount\":\"17000.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":\"co_product\",\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(25,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',1,NULL,'inv','inv.process','create','transaction',20,'Processing Order PRC-00002','9450.00',NULL,'{\"txn_type\":\"item_processing\",\"txn_no\":\"PRC-00002\",\"txn_date\":\"2026-09-12\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Teardown of trade-ins; one RAM stick failed testing\",\"subtotal\":\"9000.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"9450.00\",\"status\":\"completed\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":\"disassembly\",\"alloc_method\":\"sales_value\",\"process_formula_id\":2,\"process_batches\":\"3.0000\",\"customer\":null,\"vendor\":null,\"account\":null,\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"input\",\"item\":\"TRD-PC\",\"account\":null,\"description\":\"Trade-in Desktop PC (used)\",\"qty\":\"3.0000\",\"rate\":\"3000.0000\",\"discount_amount\":\"0.00\",\"amount\":\"9000.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"cost\",\"item\":null,\"account\":\"5200\",\"description\":\"Technician labor (1 hour)\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"450.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"output\",\"item\":\"RAM-8GB\",\"account\":null,\"description\":\"RAM 8GB DDR4\",\"qty\":\"5.0000\",\"rate\":\"853.7640\",\"discount_amount\":\"0.00\",\"amount\":\"4268.82\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":\"co_product\",\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"output\",\"item\":\"SSD-512\",\"account\":null,\"description\":\"SSD 512GB NVMe\",\"qty\":\"3.0000\",\"rate\":\"1662.0600\",\"discount_amount\":\"0.00\",\"amount\":\"4986.18\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":\"co_product\",\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"output\",\"item\":\"SCRAP-KG\",\"account\":null,\"description\":\"Scrap Metal and Plastic\",\"qty\":\"13.0000\",\"rate\":\"15.0000\",\"discount_amount\":\"0.00\",\"amount\":\"195.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":\"by_product\",\"alloc_basis\":\"15.0000\",\"class\":null}]}',NULL,NULL),
(26,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',1,NULL,'inv','inv.process','create','transaction',21,'Processing Order PRC-00003','11146.62',NULL,'{\"txn_type\":\"item_processing\",\"txn_no\":\"PRC-00003\",\"txn_date\":\"2026-09-22\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Refurbished units for the Makati store\",\"subtotal\":\"10346.62\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"11146.62\",\"status\":\"completed\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":\"co_product\",\"alloc_method\":\"percent\",\"process_formula_id\":3,\"process_batches\":\"2.0000\",\"customer\":null,\"vendor\":null,\"account\":null,\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"input\",\"item\":\"TRD-PC\",\"account\":null,\"description\":\"Trade-in Desktop PC (used)\",\"qty\":\"2.0000\",\"rate\":\"3000.0000\",\"discount_amount\":\"0.00\",\"amount\":\"6000.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"input\",\"item\":\"SSD-512\",\"account\":null,\"description\":\"SSD 512GB NVMe\",\"qty\":\"2.0000\",\"rate\":\"2173.3100\",\"discount_amount\":\"0.00\",\"amount\":\"4346.62\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"cost\",\"item\":null,\"account\":\"5200\",\"description\":\"Refurbishing labor and testing\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"800.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"output\",\"item\":\"REF-PC\",\"account\":null,\"description\":\"Refurbished Desktop PC\",\"qty\":\"2.0000\",\"rate\":\"4737.3150\",\"discount_amount\":\"0.00\",\"amount\":\"9474.63\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":\"co_product\",\"alloc_basis\":\"85.0000\",\"class\":null},{\"line_kind\":\"output\",\"item\":\"RAM-8GB\",\"account\":null,\"description\":\"RAM 8GB DDR4\",\"qty\":\"4.0000\",\"rate\":\"417.9975\",\"discount_amount\":\"0.00\",\"amount\":\"1671.99\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":\"co_product\",\"alloc_basis\":\"15.0000\",\"class\":null},{\"line_kind\":\"output\",\"item\":\"SCRAP-KG\",\"account\":null,\"description\":\"Scrap Metal and Plastic\",\"qty\":\"2.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":\"scrap\",\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(27,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',2,NULL,'inv','inv.process','create','transaction',22,'Processing Order PRC-00004','7706.67',NULL,'{\"txn_type\":\"item_processing\",\"txn_no\":\"PRC-00004\",\"txn_date\":\"2026-10-02\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":2,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Display set taken apart; parts back to stock\",\"subtotal\":\"7706.67\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"7706.67\",\"status\":\"completed\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":\"disassembly\",\"alloc_method\":\"average_cost\",\"process_formula_id\":null,\"process_batches\":\"1.0000\",\"customer\":null,\"vendor\":null,\"account\":\"Inventory Adjustments and Shrinkage\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"input\",\"item\":\"SET-OFFICE\",\"account\":null,\"description\":\"Office Monitor Set\",\"qty\":\"1.0000\",\"rate\":\"7706.6700\",\"discount_amount\":\"0.00\",\"amount\":\"7706.67\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"output\",\"item\":\"CAB-HDMI\",\"account\":null,\"description\":\"HDMI Cable 1.5m\",\"qty\":\"1.0000\",\"rate\":\"90.0000\",\"discount_amount\":\"0.00\",\"amount\":\"90.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":\"co_product\",\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"output\",\"item\":\"KEY-001\",\"account\":null,\"description\":\"Keyboard USB\",\"qty\":\"1.0000\",\"rate\":\"616.6700\",\"discount_amount\":\"0.00\",\"amount\":\"616.67\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":\"co_product\",\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"output\",\"item\":\"MON-024\",\"account\":null,\"description\":\"Monitor 24-inch IPS\",\"qty\":\"1.0000\",\"rate\":\"6500.0000\",\"discount_amount\":\"0.00\",\"amount\":\"6500.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":\"co_product\",\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"output\",\"item\":\"MOU-001\",\"account\":null,\"description\":\"Wireless Mouse\",\"qty\":\"1.0000\",\"rate\":\"350.0000\",\"discount_amount\":\"0.00\",\"amount\":\"350.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":\"co_product\",\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(28,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',1,NULL,'inv','inv.process','create','transaction',23,'Processing Order PRC-00005','6300.00',NULL,'{\"txn_type\":\"item_processing\",\"txn_no\":\"PRC-00005\",\"txn_date\":\"2026-10-15\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Waiting for more trade-in units\",\"subtotal\":\"6000.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"6300.00\",\"status\":\"pending\",\"is_pending\":1,\"is_voided\":0,\"receipt_no\":null,\"process_type\":\"disassembly\",\"alloc_method\":\"sales_value\",\"process_formula_id\":2,\"process_batches\":\"2.0000\",\"customer\":null,\"vendor\":null,\"account\":null,\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"input\",\"item\":\"TRD-PC\",\"account\":null,\"description\":\"Trade-in Desktop PC (used)\",\"qty\":\"2.0000\",\"rate\":\"3000.0000\",\"discount_amount\":\"0.00\",\"amount\":\"6000.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"cost\",\"item\":null,\"account\":\"5200\",\"description\":\"Technician labor (1 hour)\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"300.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"output\",\"item\":\"RAM-8GB\",\"account\":null,\"description\":\"RAM 8GB DDR4\",\"qty\":\"4.0000\",\"rate\":\"782.9225\",\"discount_amount\":\"0.00\",\"amount\":\"3131.69\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":\"co_product\",\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"output\",\"item\":\"SSD-512\",\"account\":null,\"description\":\"SSD 512GB NVMe\",\"qty\":\"2.0000\",\"rate\":\"1524.1550\",\"discount_amount\":\"0.00\",\"amount\":\"3048.31\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":\"co_product\",\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"output\",\"item\":\"SCRAP-KG\",\"account\":null,\"description\":\"Scrap Metal and Plastic\",\"qty\":\"8.0000\",\"rate\":\"15.0000\",\"discount_amount\":\"0.00\",\"amount\":\"120.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":\"by_product\",\"alloc_basis\":\"15.0000\",\"class\":null}]}',NULL,NULL),
(29,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',NULL,NULL,'cust','cust.estimates','create','transaction',24,'Estimate EST-00001','305368.00',NULL,'{\"txn_type\":\"estimate\",\"txn_no\":\"EST-00001\",\"txn_date\":\"2026-08-20\",\"due_date\":\"2026-09-19\",\"ref_no\":null,\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":1,\"memo\":\"Office equipment for 5 workstations\",\"subtotal\":\"272650.00\",\"tax_total\":\"32718.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"305368.00\",\"status\":\"pending\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"ABC Trading Corp.\",\"vendor\":null,\"account\":null,\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"LAP-001\",\"account\":null,\"description\":\"Laptop 14-inch i5 16GB\",\"qty\":\"5.0000\",\"rate\":\"39990.0000\",\"discount_amount\":\"0.00\",\"amount\":\"199950.00\",\"tax_amount\":\"23994.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"SET-OFFICE\",\"account\":null,\"description\":\"Office Monitor Set\",\"qty\":\"5.0000\",\"rate\":\"12990.0000\",\"discount_amount\":\"0.00\",\"amount\":\"64950.00\",\"tax_amount\":\"7794.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"SRV-INSTALL\",\"account\":null,\"description\":\"Installation and Setup\",\"qty\":\"5.0000\",\"rate\":\"1500.0000\",\"discount_amount\":\"0.00\",\"amount\":\"7500.00\",\"tax_amount\":\"900.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"DEL-FEE\",\"account\":null,\"description\":\"Delivery Fee\",\"qty\":\"1.0000\",\"rate\":\"250.0000\",\"discount_amount\":\"0.00\",\"amount\":\"250.00\",\"tax_amount\":\"30.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(30,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',1,NULL,'cust','cust.sales_orders','create','transaction',25,'Sales Order SO-00001','305368.00',NULL,'{\"txn_type\":\"sales_order\",\"txn_no\":\"SO-00001\",\"txn_date\":\"2026-08-22\",\"due_date\":null,\"ref_no\":\"ABC-PO-7781\",\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":1,\"memo\":null,\"subtotal\":\"272650.00\",\"tax_total\":\"32718.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"305368.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"ABC Trading Corp.\",\"vendor\":null,\"account\":null,\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"LAP-001\",\"account\":null,\"description\":\"Laptop 14-inch i5 16GB\",\"qty\":\"5.0000\",\"rate\":\"39990.0000\",\"discount_amount\":\"0.00\",\"amount\":\"199950.00\",\"tax_amount\":\"23994.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"SET-OFFICE\",\"account\":null,\"description\":\"Office Monitor Set\",\"qty\":\"5.0000\",\"rate\":\"12990.0000\",\"discount_amount\":\"0.00\",\"amount\":\"64950.00\",\"tax_amount\":\"7794.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"SRV-INSTALL\",\"account\":null,\"description\":\"Installation and Setup\",\"qty\":\"5.0000\",\"rate\":\"1500.0000\",\"discount_amount\":\"0.00\",\"amount\":\"7500.00\",\"tax_amount\":\"900.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"DEL-FEE\",\"account\":null,\"description\":\"Delivery Fee\",\"qty\":\"1.0000\",\"rate\":\"250.0000\",\"discount_amount\":\"0.00\",\"amount\":\"250.00\",\"tax_amount\":\"30.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(31,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',1,NULL,'cust','cust.invoices','create','transaction',26,'Invoice INV-00001','183332.80',NULL,'{\"txn_type\":\"invoice\",\"txn_no\":\"INV-00001\",\"txn_date\":\"2026-08-28\",\"due_date\":\"2026-09-27\",\"ref_no\":\"ABC-PO-7781\",\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":3,\"sales_rep_id\":1,\"memo\":null,\"subtotal\":\"163690.00\",\"tax_total\":\"19642.80\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"183332.80\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"ABC Trading Corp.\",\"vendor\":null,\"account\":\"Accounts Receivable\",\"class\":\"Head Office\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"LAP-001\",\"account\":null,\"description\":\"Laptop 14-inch i5 16GB\",\"qty\":\"3.0000\",\"rate\":\"39990.0000\",\"discount_amount\":\"0.00\",\"amount\":\"119970.00\",\"tax_amount\":\"14396.40\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"SET-OFFICE\",\"account\":null,\"description\":\"Office Monitor Set\",\"qty\":\"3.0000\",\"rate\":\"12990.0000\",\"discount_amount\":\"0.00\",\"amount\":\"38970.00\",\"tax_amount\":\"4676.40\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"SRV-INSTALL\",\"account\":null,\"description\":\"Installation and Setup\",\"qty\":\"3.0000\",\"rate\":\"1500.0000\",\"discount_amount\":\"0.00\",\"amount\":\"4500.00\",\"tax_amount\":\"540.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"DEL-FEE\",\"account\":null,\"description\":\"Delivery Fee\",\"qty\":\"1.0000\",\"rate\":\"250.0000\",\"discount_amount\":\"0.00\",\"amount\":\"250.00\",\"tax_amount\":\"30.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(32,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',NULL,NULL,'vend','vend.bills','create','transaction',27,'Bill BILL-00009','2016.00',NULL,'{\"txn_type\":\"bill\",\"txn_no\":\"BILL-00009\",\"txn_date\":\"2026-09-02\",\"due_date\":\"2026-09-17\",\"ref_no\":\"JRS-55012\",\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":2,\"sales_rep_id\":null,\"memo\":null,\"subtotal\":\"1800.00\",\"tax_total\":\"216.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"2016.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":\"JRS Express\",\"account\":\"Accounts Payable\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"expense\",\"item\":null,\"account\":\"6100\",\"description\":\"Freight - Office Renovation Project\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"1800.00\",\"tax_amount\":\"216.00\",\"site_id\":null,\"is_billable\":1,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(33,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',NULL,NULL,'bank','bank.write_checks','create','transaction',28,'Check 1003','950.00',NULL,'{\"txn_type\":\"check\",\"txn_no\":\"1003\",\"txn_date\":\"2026-09-03\",\"due_date\":null,\"ref_no\":null,\"payee_name\":\"Hardware Depot\",\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Cables and conduits for job\",\"subtotal\":\"950.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"950.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":\"Petty Cash Fund\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"expense\",\"item\":null,\"account\":\"6900\",\"description\":\"Conduits - Office Renovation Project\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"950.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":1,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(34,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',1,NULL,'cust','cust.invoices','create','transaction',29,'Invoice INV-00002','6944.00',NULL,'{\"txn_type\":\"invoice\",\"txn_no\":\"INV-00002\",\"txn_date\":\"2026-09-27\",\"due_date\":\"2026-10-27\",\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":3,\"sales_rep_id\":1,\"memo\":null,\"subtotal\":\"6200.00\",\"tax_total\":\"744.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"6944.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"Office Renovation Project\",\"vendor\":null,\"account\":\"Accounts Receivable\",\"class\":\"Head Office\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"SRV-INSTALL\",\"account\":null,\"description\":\"Installation and Setup\",\"qty\":\"2.0000\",\"rate\":\"1500.0000\",\"discount_amount\":\"0.00\",\"amount\":\"3000.00\",\"tax_amount\":\"360.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"SRV-REPAIR\",\"account\":null,\"description\":\"Repair Service (per hour)\",\"qty\":\"4.0000\",\"rate\":\"800.0000\",\"discount_amount\":\"0.00\",\"amount\":\"3200.00\",\"tax_amount\":\"384.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(35,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',1,NULL,'cust','cust.invoices','create','transaction',30,'Invoice INV-00003','89577.60',NULL,'{\"txn_type\":\"invoice\",\"txn_no\":\"INV-00003\",\"txn_date\":\"2026-10-05\",\"due_date\":\"2026-11-04\",\"ref_no\":\"ABC-PO-7781\",\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":3,\"sales_rep_id\":1,\"memo\":null,\"subtotal\":\"79980.00\",\"tax_total\":\"9597.60\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"89577.60\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"ABC Trading Corp.\",\"vendor\":null,\"account\":\"Accounts Receivable\",\"class\":\"Head Office\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"LAP-001\",\"account\":null,\"description\":\"Laptop 14-inch i5 16GB\",\"qty\":\"2.0000\",\"rate\":\"39990.0000\",\"discount_amount\":\"0.00\",\"amount\":\"79980.00\",\"tax_amount\":\"9597.60\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(36,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',1,NULL,'cust','cust.invoices','create','transaction',31,'Invoice INV-00004','39444.07',NULL,'{\"txn_type\":\"invoice\",\"txn_no\":\"INV-00004\",\"txn_date\":\"2026-08-30\",\"due_date\":\"2026-09-14\",\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":2,\"sales_rep_id\":2,\"memo\":null,\"subtotal\":\"35217.92\",\"tax_total\":\"4226.15\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"39444.07\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"Metro School Supplies\",\"vendor\":null,\"account\":\"Accounts Receivable\",\"class\":\"Head Office\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"USB-032\",\"account\":null,\"description\":\"USB Flash Drive 32GB\",\"qty\":\"40.0000\",\"rate\":\"332.5000\",\"discount_amount\":\"0.00\",\"amount\":\"13300.00\",\"tax_amount\":\"1596.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"KEY-001\",\"account\":null,\"description\":\"Keyboard USB\",\"qty\":\"15.0000\",\"rate\":\"949.0500\",\"discount_amount\":\"0.00\",\"amount\":\"14235.75\",\"tax_amount\":\"1708.29\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"MOU-001\",\"account\":null,\"description\":\"Wireless Mouse\",\"qty\":\"15.0000\",\"rate\":\"569.0500\",\"discount_amount\":\"0.00\",\"amount\":\"8535.75\",\"tax_amount\":\"1024.29\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"SUBTOTAL\",\"account\":null,\"description\":\"Subtotal\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"DISC-10\",\"account\":null,\"description\":\"10% Discount\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"-853.58\",\"tax_amount\":\"-102.43\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(37,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',1,NULL,'cust','cust.invoices','create','transaction',32,'Invoice INV-00005','13800.08',NULL,'{\"txn_type\":\"invoice\",\"txn_no\":\"INV-00005\",\"txn_date\":\"2026-09-12\",\"due_date\":\"2026-09-27\",\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":2,\"sales_rep_id\":2,\"memo\":null,\"subtotal\":\"12321.50\",\"tax_total\":\"1478.58\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"13800.08\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"Metro School Supplies\",\"vendor\":null,\"account\":\"Accounts Receivable\",\"class\":\"Head Office\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"BAG-001\",\"account\":null,\"description\":\"Laptop Backpack\",\"qty\":\"10.0000\",\"rate\":\"854.0500\",\"discount_amount\":\"0.00\",\"amount\":\"8540.50\",\"tax_amount\":\"1024.86\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"CAB-HDMI\",\"account\":null,\"description\":\"HDMI Cable 1.5m\",\"qty\":\"20.0000\",\"rate\":\"189.0500\",\"discount_amount\":\"0.00\",\"amount\":\"3781.00\",\"tax_amount\":\"453.72\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(38,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',1,NULL,'cust','cust.invoices','create','transaction',33,'Invoice INV-00006','96718.72',NULL,'{\"txn_type\":\"invoice\",\"txn_no\":\"INV-00006\",\"txn_date\":\"2026-09-17\",\"due_date\":\"2026-10-17\",\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":4,\"sales_rep_id\":2,\"memo\":null,\"subtotal\":\"86356.00\",\"tax_total\":\"10362.72\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"96718.72\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"Cebu Tech Hub\",\"vendor\":null,\"account\":\"Accounts Receivable\",\"class\":\"Head Office\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"LAP-001\",\"account\":null,\"description\":\"Laptop 14-inch i5 16GB\",\"qty\":\"2.0000\",\"rate\":\"36500.0000\",\"discount_amount\":\"0.00\",\"amount\":\"73000.00\",\"tax_amount\":\"8760.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"RAM-8GB\",\"account\":null,\"description\":\"RAM 8GB DDR4\",\"qty\":\"4.0000\",\"rate\":\"1521.0000\",\"discount_amount\":\"0.00\",\"amount\":\"6084.00\",\"tax_amount\":\"730.08\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"SSD-512\",\"account\":null,\"description\":\"SSD 512GB NVMe\",\"qty\":\"2.0000\",\"rate\":\"2961.0000\",\"discount_amount\":\"0.00\",\"amount\":\"5922.00\",\"tax_amount\":\"710.64\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"SRV-INSTALL\",\"account\":null,\"description\":\"Installation and Setup\",\"qty\":\"1.0000\",\"rate\":\"1350.0000\",\"discount_amount\":\"0.00\",\"amount\":\"1350.00\",\"tax_amount\":\"162.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(39,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',1,NULL,'cust','cust.invoices','create','transaction',34,'Invoice INV-00007','12768.00',NULL,'{\"txn_type\":\"invoice\",\"txn_no\":\"INV-00007\",\"txn_date\":\"2026-08-03\",\"due_date\":\"2026-08-18\",\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":2,\"sales_rep_id\":1,\"memo\":null,\"subtotal\":\"11400.00\",\"tax_total\":\"1368.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"12768.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"Green Valley Clinic\",\"vendor\":null,\"account\":\"Accounts Receivable\",\"class\":\"Head Office\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"SRV-MAINT\",\"account\":null,\"description\":\"Monthly IT Maintenance\",\"qty\":\"1.0000\",\"rate\":\"5000.0000\",\"discount_amount\":\"0.00\",\"amount\":\"5000.00\",\"tax_amount\":\"600.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"NI-TONER\",\"account\":null,\"description\":\"Toner Cartridge (special order)\",\"qty\":\"2.0000\",\"rate\":\"3200.0000\",\"discount_amount\":\"0.00\",\"amount\":\"6400.00\",\"tax_amount\":\"768.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(40,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',1,NULL,'cust','cust.invoices','create','transaction',35,'Invoice INV-00008','5600.00',NULL,'{\"txn_type\":\"invoice\",\"txn_no\":\"INV-00008\",\"txn_date\":\"2026-08-16\",\"due_date\":\"2026-08-31\",\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":2,\"sales_rep_id\":1,\"memo\":\"Monthly IT maintenance\",\"subtotal\":\"5000.00\",\"tax_total\":\"600.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"5600.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"Bright Minds Academy\",\"vendor\":null,\"account\":\"Accounts Receivable\",\"class\":\"Head Office\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"SRV-MAINT\",\"account\":null,\"description\":\"Monthly IT Maintenance\",\"qty\":\"1.0000\",\"rate\":\"5000.0000\",\"discount_amount\":\"0.00\",\"amount\":\"5000.00\",\"tax_amount\":\"600.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(41,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',1,NULL,'cust','cust.invoices','create','transaction',36,'Invoice INV-00009','5600.00',NULL,'{\"txn_type\":\"invoice\",\"txn_no\":\"INV-00009\",\"txn_date\":\"2026-08-16\",\"due_date\":\"2026-08-31\",\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":2,\"sales_rep_id\":1,\"memo\":\"Monthly IT maintenance\",\"subtotal\":\"5000.00\",\"tax_total\":\"600.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"5600.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"Green Valley Clinic\",\"vendor\":null,\"account\":\"Accounts Receivable\",\"class\":\"Head Office\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"SRV-MAINT\",\"account\":null,\"description\":\"Monthly IT Maintenance\",\"qty\":\"1.0000\",\"rate\":\"5000.0000\",\"discount_amount\":\"0.00\",\"amount\":\"5000.00\",\"tax_amount\":\"600.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(42,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',1,NULL,'cust','cust.invoices','create','transaction',37,'Invoice INV-00010','5600.00',NULL,'{\"txn_type\":\"invoice\",\"txn_no\":\"INV-00010\",\"txn_date\":\"2026-09-16\",\"due_date\":\"2026-10-01\",\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":2,\"sales_rep_id\":1,\"memo\":\"Monthly IT maintenance\",\"subtotal\":\"5000.00\",\"tax_total\":\"600.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"5600.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"Bright Minds Academy\",\"vendor\":null,\"account\":\"Accounts Receivable\",\"class\":\"Head Office\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"SRV-MAINT\",\"account\":null,\"description\":\"Monthly IT Maintenance\",\"qty\":\"1.0000\",\"rate\":\"5000.0000\",\"discount_amount\":\"0.00\",\"amount\":\"5000.00\",\"tax_amount\":\"600.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(43,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',1,NULL,'cust','cust.invoices','create','transaction',38,'Invoice INV-00011','5600.00',NULL,'{\"txn_type\":\"invoice\",\"txn_no\":\"INV-00011\",\"txn_date\":\"2026-09-16\",\"due_date\":\"2026-10-01\",\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":2,\"sales_rep_id\":1,\"memo\":\"Monthly IT maintenance\",\"subtotal\":\"5000.00\",\"tax_total\":\"600.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"5600.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"Green Valley Clinic\",\"vendor\":null,\"account\":\"Accounts Receivable\",\"class\":\"Head Office\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"SRV-MAINT\",\"account\":null,\"description\":\"Monthly IT Maintenance\",\"qty\":\"1.0000\",\"rate\":\"5000.0000\",\"discount_amount\":\"0.00\",\"amount\":\"5000.00\",\"tax_amount\":\"600.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(44,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',1,NULL,'cust','cust.invoices','create','transaction',39,'Invoice INV-00012','36247.68',NULL,'{\"txn_type\":\"invoice\",\"txn_no\":\"INV-00012\",\"txn_date\":\"2026-10-15\",\"due_date\":\"2026-11-14\",\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":4,\"sales_rep_id\":2,\"memo\":\"Awaiting PO approval\",\"subtotal\":\"32364.00\",\"tax_total\":\"3883.68\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"36247.68\",\"status\":\"pending\",\"is_pending\":1,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"Cebu Tech Hub\",\"vendor\":null,\"account\":\"Accounts Receivable\",\"class\":\"Head Office\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"MON-024\",\"account\":null,\"description\":\"Monitor 24-inch IPS\",\"qty\":\"4.0000\",\"rate\":\"8091.0000\",\"discount_amount\":\"0.00\",\"amount\":\"32364.00\",\"tax_amount\":\"3883.68\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(45,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',1,NULL,'cust','cust.sales_receipts','create','transaction',40,'Sales Receipt SR-00001','46466.56',NULL,'{\"txn_type\":\"sales_receipt\",\"txn_no\":\"SR-00001\",\"txn_date\":\"2026-09-07\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Phone order\",\"subtotal\":\"41488.00\",\"tax_total\":\"4978.56\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"46466.56\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"Juan Dela Cruz\",\"vendor\":null,\"account\":\"Undeposited Funds\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"LAP-001\",\"account\":null,\"description\":\"Laptop 14-inch i5 16GB\",\"qty\":\"1.0000\",\"rate\":\"39990.0000\",\"discount_amount\":\"0.00\",\"amount\":\"39990.00\",\"tax_amount\":\"4798.80\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"BAG-001\",\"account\":null,\"description\":\"Laptop Backpack\",\"qty\":\"1.0000\",\"rate\":\"899.0000\",\"discount_amount\":\"0.00\",\"amount\":\"899.00\",\"tax_amount\":\"107.88\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"MOU-001\",\"account\":null,\"description\":\"Wireless Mouse\",\"qty\":\"1.0000\",\"rate\":\"599.0000\",\"discount_amount\":\"0.00\",\"amount\":\"599.00\",\"tax_amount\":\"71.88\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(46,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',1,NULL,'cust','cust.invoices','create','transaction',41,'Invoice INV-00013','35280.00',NULL,'{\"txn_type\":\"invoice\",\"txn_no\":\"INV-00013\",\"txn_date\":\"2026-09-27\",\"due_date\":\"2026-10-12\",\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":2,\"sales_rep_id\":2,\"memo\":\"3 dozen keyboards, 1,500.00 off\",\"subtotal\":\"31500.00\",\"tax_total\":\"3780.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"35280.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"Metro School Supplies\",\"vendor\":null,\"account\":\"Accounts Receivable\",\"class\":\"Head Office\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"KEY-001\",\"account\":null,\"description\":\"Keyboard USB (sold by the dozen)\",\"qty\":\"36.0000\",\"rate\":\"916.6667\",\"discount_amount\":\"1500.00\",\"amount\":\"31500.00\",\"tax_amount\":\"3780.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(47,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',NULL,NULL,'cust','cust.payments','create','transaction',42,'Customer Payment PMT-00001','100000.00',NULL,'{\"txn_type\":\"payment\",\"txn_no\":\"PMT-00001\",\"txn_date\":\"2026-09-22\",\"due_date\":null,\"ref_no\":\"BDO-004412\",\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":null,\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"1500.00\",\"total\":\"100000.00\",\"status\":\"closed\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"ABC Trading Corp.\",\"vendor\":null,\"account\":\"Undeposited Funds\",\"class\":null,\"other_name\":null,\"lines\":[],\"applied_to\":[{\"txn_type\":\"invoice\",\"txn_no\":\"INV-00001\",\"amount\":\"100000.00\",\"discount\":\"0.00\",\"withholding\":\"1500.00\"}]}',NULL,NULL),
(48,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',NULL,NULL,'cust','cust.payments','create','transaction',43,'Customer Payment PMT-00002','94784.35',NULL,'{\"txn_type\":\"payment\",\"txn_no\":\"PMT-00002\",\"txn_date\":\"2026-09-25\",\"due_date\":null,\"ref_no\":\"IB-88123\",\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":null,\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"1934.37\",\"withholding_amount\":\"0.00\",\"total\":\"94784.35\",\"status\":\"closed\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"Cebu Tech Hub\",\"vendor\":null,\"account\":\"Cash in Bank - BDO Checking\",\"class\":null,\"other_name\":null,\"lines\":[],\"applied_to\":[{\"txn_type\":\"invoice\",\"txn_no\":\"INV-00006\",\"amount\":\"94784.35\",\"discount\":\"1934.37\",\"withholding\":\"0.00\"}]}',NULL,NULL),
(49,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',NULL,NULL,'cust','cust.payments','create','transaction',44,'Customer Payment PMT-00003','39944.07',NULL,'{\"txn_type\":\"payment\",\"txn_no\":\"PMT-00003\",\"txn_date\":\"2026-09-19\",\"due_date\":null,\"ref_no\":\"MBTC-1120\",\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":null,\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"39944.07\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"Metro School Supplies\",\"vendor\":null,\"account\":\"Undeposited Funds\",\"class\":null,\"other_name\":null,\"lines\":[],\"applied_to\":[{\"txn_type\":\"invoice\",\"txn_no\":\"INV-00004\",\"amount\":\"39444.07\",\"discount\":\"0.00\",\"withholding\":\"0.00\"}]}',NULL,NULL),
(50,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',NULL,NULL,'cust','cust.payments','create','transaction',45,'Customer Payment PMT-00004','6384.00',NULL,'{\"txn_type\":\"payment\",\"txn_no\":\"PMT-00004\",\"txn_date\":\"2026-08-18\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":null,\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"6384.00\",\"status\":\"closed\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"Green Valley Clinic\",\"vendor\":null,\"account\":\"Undeposited Funds\",\"class\":null,\"other_name\":null,\"lines\":[],\"applied_to\":[{\"txn_type\":\"invoice\",\"txn_no\":\"INV-00007\",\"amount\":\"6384.00\",\"discount\":\"0.00\",\"withholding\":\"0.00\"}]}',NULL,NULL),
(51,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',1,NULL,'cust','cust.invoices','create','transaction',46,'Invoice INV-00014','100688.00',NULL,'{\"txn_type\":\"invoice\",\"txn_no\":\"INV-00014\",\"txn_date\":\"2026-09-13\",\"due_date\":\"2026-10-13\",\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":3,\"sales_rep_id\":null,\"memo\":\"Monitors for the city hall offices\",\"subtotal\":\"89900.00\",\"tax_total\":\"10788.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"100688.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"City Government of Makati\",\"vendor\":null,\"account\":\"Accounts Receivable\",\"class\":\"Head Office\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"MON-024\",\"account\":null,\"description\":\"Monitor 24-inch IPS\",\"qty\":\"10.0000\",\"rate\":\"8990.0000\",\"discount_amount\":\"0.00\",\"amount\":\"89900.00\",\"tax_amount\":\"10788.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(52,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',NULL,NULL,'cust','cust.payments','create','transaction',47,'Customer Payment PMT-00005','95294.00',NULL,'{\"txn_type\":\"payment\",\"txn_no\":\"PMT-00005\",\"txn_date\":\"2026-10-05\",\"due_date\":null,\"ref_no\":\"LBP-205511\",\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"5% VAT and 1% withheld; BIR Form 2307 to follow\",\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"5394.00\",\"total\":\"95294.00\",\"status\":\"closed\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"City Government of Makati\",\"vendor\":null,\"account\":\"Undeposited Funds\",\"class\":null,\"other_name\":null,\"lines\":[],\"applied_to\":[{\"txn_type\":\"invoice\",\"txn_no\":\"INV-00014\",\"amount\":\"95294.00\",\"discount\":\"0.00\",\"withholding\":\"5394.00\"}]}',NULL,NULL),
(53,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',1,NULL,'cust','cust.credit_memos','create','transaction',48,'Credit Memo CM-00001','2125.87',NULL,'{\"txn_type\":\"credit_memo\",\"txn_no\":\"CM-00001\",\"txn_date\":\"2026-09-20\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Returned 2 defective keyboards\",\"subtotal\":\"1898.10\",\"tax_total\":\"227.77\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"2125.87\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"Metro School Supplies\",\"vendor\":null,\"account\":\"Accounts Receivable\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"KEY-001\",\"account\":null,\"description\":\"Keyboard USB\",\"qty\":\"2.0000\",\"rate\":\"949.0500\",\"discount_amount\":\"0.00\",\"amount\":\"1898.10\",\"tax_amount\":\"227.77\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(54,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',NULL,NULL,'cust','cust.statement_charges','create','transaction',49,'Statement Charge SC-00001','200.00',NULL,'{\"txn_type\":\"statement_charge\",\"txn_no\":\"SC-00001\",\"txn_date\":\"2026-10-02\",\"due_date\":\"2026-10-02\",\"ref_no\":null,\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Late payment fee\",\"subtotal\":\"200.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"200.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"Green Valley Clinic\",\"vendor\":null,\"account\":\"Accounts Receivable\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"LATE-FEE\",\"account\":null,\"description\":\"Late Payment Fee\",\"qty\":\"1.0000\",\"rate\":\"200.0000\",\"discount_amount\":\"0.00\",\"amount\":\"200.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(55,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',NULL,NULL,'cust','cust.finance_charges','create','transaction',50,'Finance Charge FC-00001','120.50',NULL,'{\"txn_type\":\"finance_charge\",\"txn_no\":\"FC-00001\",\"txn_date\":\"2026-10-16\",\"due_date\":\"2026-10-16\",\"ref_no\":null,\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Finance charge on overdue balance\",\"subtotal\":\"120.50\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"120.50\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"Green Valley Clinic\",\"vendor\":null,\"account\":\"Accounts Receivable\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":null,\"account\":\"4100\",\"description\":\"Finance charge (12% p.a.)\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"120.50\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(56,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',NULL,NULL,'bank','bank.write_checks','create','transaction',51,'Check 1004','85000.00',NULL,'{\"txn_type\":\"check\",\"txn_no\":\"1004\",\"txn_date\":\"2026-08-04\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Office and warehouse rent\",\"subtotal\":\"85000.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"85000.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":\"Metro Property Leasing\",\"account\":\"Cash in Bank - BDO Checking\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":null,\"account\":\"6010\",\"description\":\"Monthly rent\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"85000.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(57,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',NULL,NULL,'bank','bank.write_checks','create','transaction',52,'Check 1005','85000.00',NULL,'{\"txn_type\":\"check\",\"txn_no\":\"1005\",\"txn_date\":\"2026-09-03\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Office and warehouse rent\",\"subtotal\":\"85000.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"85000.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":\"Metro Property Leasing\",\"account\":\"Cash in Bank - BDO Checking\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":null,\"account\":\"6010\",\"description\":\"Monthly rent\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"85000.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(58,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',NULL,NULL,'bank','bank.write_checks','create','transaction',53,'Check 1006','85000.00',NULL,'{\"txn_type\":\"check\",\"txn_no\":\"1006\",\"txn_date\":\"2026-10-03\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Office and warehouse rent\",\"subtotal\":\"85000.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"85000.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":\"Metro Property Leasing\",\"account\":\"Cash in Bank - BDO Checking\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":null,\"account\":\"6010\",\"description\":\"Monthly rent\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"85000.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(59,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',NULL,NULL,'vend','vend.bills','create','transaction',54,'Bill BILL-00010','20664.84',NULL,'{\"txn_type\":\"bill\",\"txn_no\":\"BILL-00010\",\"txn_date\":\"2026-08-18\",\"due_date\":\"2026-08-28\",\"ref_no\":\"MER-202608\",\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":1,\"sales_rep_id\":null,\"memo\":null,\"subtotal\":\"18450.75\",\"tax_total\":\"2214.09\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"20664.84\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":\"Meralco\",\"account\":\"Accounts Payable\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"expense\",\"item\":null,\"account\":\"6020\",\"description\":\"Electricity\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"18450.75\",\"tax_amount\":\"2214.09\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(60,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',NULL,NULL,'vend','vend.bills','create','transaction',55,'Bill BILL-00011','23778.05',NULL,'{\"txn_type\":\"bill\",\"txn_no\":\"BILL-00011\",\"txn_date\":\"2026-09-17\",\"due_date\":\"2026-09-27\",\"ref_no\":\"MER-202609\",\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":1,\"sales_rep_id\":null,\"memo\":null,\"subtotal\":\"21230.40\",\"tax_total\":\"2547.65\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"23778.05\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":\"Meralco\",\"account\":\"Accounts Payable\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"expense\",\"item\":null,\"account\":\"6020\",\"description\":\"Electricity\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"21230.40\",\"tax_amount\":\"2547.65\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(61,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',NULL,NULL,'vend','vend.bills','create','transaction',56,'Bill BILL-00012','50400.00',NULL,'{\"txn_type\":\"bill\",\"txn_no\":\"BILL-00012\",\"txn_date\":\"2026-08-23\",\"due_date\":\"2026-09-22\",\"ref_no\":\"APC-2231\",\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":3,\"sales_rep_id\":null,\"memo\":\"Quarterly bookkeeping review\",\"subtotal\":\"45000.00\",\"tax_total\":\"5400.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"50400.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":\"Accounting Partners & Co.\",\"account\":\"Accounts Payable\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"expense\",\"item\":null,\"account\":\"6070\",\"description\":\"Professional fees\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"45000.00\",\"tax_amount\":\"5400.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(62,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',NULL,NULL,'bank','bank.write_checks','create','transaction',57,'Check 1007','3920.00',NULL,'{\"txn_type\":\"check\",\"txn_no\":\"1007\",\"txn_date\":\"2026-09-14\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Fuel for delivery van\",\"subtotal\":\"3500.00\",\"tax_total\":\"420.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"3920.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":\"Petron Service Station\",\"account\":\"Petty Cash Fund\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"expense\",\"item\":null,\"account\":\"6050\",\"description\":\"Diesel\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"3500.00\",\"tax_amount\":\"420.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(63,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',1,NULL,'vend','vend.debit_memos','create','transaction',58,'Supplier Debit Memo DM-00001','784.00',NULL,'{\"txn_type\":\"vendor_credit\",\"txn_no\":\"DM-00001\",\"txn_date\":\"2026-09-01\",\"due_date\":null,\"ref_no\":\"TD-CM-331\",\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Returned damaged mice\",\"subtotal\":\"700.00\",\"tax_total\":\"84.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"784.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":\"TechDistributors Inc.\",\"account\":\"Accounts Payable\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"MOU-001\",\"account\":null,\"description\":\"Wireless Mouse\",\"qty\":\"2.0000\",\"rate\":\"350.0000\",\"discount_amount\":\"0.00\",\"amount\":\"700.00\",\"tax_amount\":\"84.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(64,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',NULL,NULL,'vend','vend.pay_bills','create','transaction',59,'Bill Payment 1008','1127280.00',NULL,'{\"txn_type\":\"bill_payment\",\"txn_no\":\"1008\",\"txn_date\":\"2026-09-07\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Payment of TD-INV-10231\",\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"1127280.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":\"TechDistributors Inc.\",\"account\":\"Cash in Bank - BDO Checking\",\"class\":null,\"other_name\":null,\"lines\":[],\"applied_to\":[{\"txn_type\":\"bill\",\"txn_no\":\"BILL-00004\",\"amount\":\"1127280.00\",\"discount\":\"0.00\",\"withholding\":\"0.00\"}]}',NULL,NULL),
(65,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',NULL,NULL,'vend','vend.pay_bills','create','transaction',60,'Bill Payment 1009','20664.84',NULL,'{\"txn_type\":\"bill_payment\",\"txn_no\":\"1009\",\"txn_date\":\"2026-08-26\",\"due_date\":null,\"ref_no\":\"IB-77100\",\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Electricity\",\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"20664.84\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":\"Meralco\",\"account\":\"Cash in Bank - BDO Checking\",\"class\":null,\"other_name\":null,\"lines\":[],\"applied_to\":[{\"txn_type\":\"bill\",\"txn_no\":\"BILL-00010\",\"amount\":\"20664.84\",\"discount\":\"0.00\",\"withholding\":\"0.00\"}]}',NULL,NULL),
(66,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',NULL,NULL,'vend','vend.pay_bills','create','transaction',61,'Bill Payment 1010','49500.00',NULL,'{\"txn_type\":\"bill_payment\",\"txn_no\":\"1010\",\"txn_date\":\"2026-09-27\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Payment of APC-2231, 2% withheld\",\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"900.00\",\"total\":\"49500.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":\"Accounting Partners & Co.\",\"account\":\"Cash in Bank - BDO Checking\",\"class\":null,\"other_name\":null,\"lines\":[],\"applied_to\":[{\"txn_type\":\"bill\",\"txn_no\":\"BILL-00012\",\"amount\":\"49500.00\",\"discount\":\"0.00\",\"withholding\":\"900.00\"}]}',NULL,NULL),
(67,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',NULL,NULL,'vend','vend.advances','create','transaction',62,'Advance to Supplier ADV-00001','150000.00',NULL,'{\"txn_type\":\"vendor_advance\",\"txn_no\":\"ADV-00001\",\"txn_date\":\"2026-10-03\",\"due_date\":\"2026-11-06\",\"ref_no\":\"1188\",\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"30% down payment on the packaging machine\",\"subtotal\":\"150000.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"150000.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":\"Industrial Machines Corp.\",\"account\":\"Cash in Bank - BDO Checking\",\"class\":null,\"other_name\":null,\"lines\":[]}',NULL,NULL),
(68,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',NULL,NULL,'bank','bank.write_checks','create','transaction',63,'Check 1011','2500.00',NULL,'{\"txn_type\":\"check\",\"txn_no\":\"1011\",\"txn_date\":\"2026-10-07\",\"due_date\":null,\"ref_no\":null,\"payee_name\":\"Office Snacks Co.\",\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Pantry supplies\",\"subtotal\":\"2500.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"2500.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":\"Cash in Bank - BDO Checking\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"expense\",\"item\":null,\"account\":\"6900\",\"description\":\"Pantry supplies\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"2500.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(69,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',NULL,NULL,'bank','bank.write_checks','void','transaction',63,'Check 1011','2500.00','[{\"field\":\"status\",\"old\":\"open\",\"new\":\"void\"}]','{\"txn_type\":\"check\",\"txn_no\":\"1011\",\"txn_date\":\"2026-10-07\",\"due_date\":null,\"ref_no\":null,\"payee_name\":\"Office Snacks Co.\",\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Pantry supplies\",\"subtotal\":\"2500.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"2500.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":\"Cash in Bank - BDO Checking\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"expense\",\"item\":null,\"account\":\"6900\",\"description\":\"Pantry supplies\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"2500.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}','Check printed with wrong payee',NULL),
(70,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',NULL,NULL,'cust','cust.estimates','create','transaction',64,'Estimate EST-00002','100688.00',NULL,'{\"txn_type\":\"estimate\",\"txn_no\":\"EST-00002\",\"txn_date\":\"2026-10-08\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Duplicate quote\",\"subtotal\":\"89900.00\",\"tax_total\":\"10788.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"100688.00\",\"status\":\"pending\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"Cebu Tech Hub\",\"vendor\":null,\"account\":null,\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"MON-024\",\"account\":null,\"description\":\"Monitor 24-inch IPS\",\"qty\":\"10.0000\",\"rate\":\"8990.0000\",\"discount_amount\":\"0.00\",\"amount\":\"89900.00\",\"tax_amount\":\"10788.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(71,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',NULL,NULL,'cust','cust.estimates','delete','transaction',64,'Estimate EST-00002','100688.00',NULL,'{\"txn_type\":\"estimate\",\"txn_no\":\"EST-00002\",\"txn_date\":\"2026-10-08\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Duplicate quote\",\"subtotal\":\"89900.00\",\"tax_total\":\"10788.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"100688.00\",\"status\":\"pending\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"Cebu Tech Hub\",\"vendor\":null,\"account\":null,\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"MON-024\",\"account\":null,\"description\":\"Monitor 24-inch IPS\",\"qty\":\"10.0000\",\"rate\":\"8990.0000\",\"discount_amount\":\"0.00\",\"amount\":\"89900.00\",\"tax_amount\":\"10788.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}','Duplicate of an existing quotation',NULL),
(72,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',1,NULL,'inv','inv.adjust','create','transaction',65,'Inventory Adjustment ADJ-00001','0.00',NULL,'{\"txn_type\":\"inventory_adjustment\",\"txn_no\":\"ADJ-00001\",\"txn_date\":\"2026-09-23\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Damage - water leak\",\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"0.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":\"Inventory Adjustments and Shrinkage\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"BAG-001\",\"account\":null,\"description\":\"Damage\",\"qty\":\"-2.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}','Damage',NULL),
(73,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',2,NULL,'inv','inv.adjust','create','transaction',66,'Inventory Adjustment ADJ-00002','0.00',NULL,'{\"txn_type\":\"inventory_adjustment\",\"txn_no\":\"ADJ-00002\",\"txn_date\":\"2026-10-09\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":2,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Physical count by D. Villanueva\",\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"0.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":\"Inventory Adjustments and Shrinkage\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"USB-032\",\"account\":null,\"description\":\"Count difference (counted 29, system 30)\",\"qty\":\"-1.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"CAB-HDMI\",\"account\":null,\"description\":\"Count difference (counted 16, system 15)\",\"qty\":\"1.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}','Physical inventory count',NULL),
(74,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',NULL,NULL,'bank','bank.transfers','create','transaction',67,'Transfer TRF-00001','10000.00',NULL,'{\"txn_type\":\"transfer\",\"txn_no\":\"TRF-00001\",\"txn_date\":\"2026-09-02\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Replenish petty cash\",\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"10000.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":\"Cash in Bank - BDO Checking\",\"class\":null,\"other_name\":null,\"lines\":[]}',NULL,NULL),
(75,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',NULL,NULL,'bank','bank.cash_voucher','create','transaction',68,'Cash Voucher CAV-00001','1250.00',NULL,'{\"txn_type\":\"cash_voucher\",\"txn_no\":\"CAV-00001\",\"txn_date\":\"2026-09-17\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Packing tape and markers for the warehouse\",\"subtotal\":\"1250.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"1250.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":\"Petty Cash Fund\",\"class\":\"Head Office\",\"other_name\":\"Dan Villanueva\",\"lines\":[{\"line_kind\":\"journal\",\"item\":null,\"account\":\"6040\",\"description\":\"Packing supplies\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"1250.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(76,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',NULL,NULL,'bank','bank.cash_voucher','create','transaction',69,'Cash Voucher CAV-00002','480.00',NULL,'{\"txn_type\":\"cash_voucher\",\"txn_no\":\"CAV-00002\",\"txn_date\":\"2026-10-05\",\"due_date\":null,\"ref_no\":null,\"payee_name\":\"Jeepney and tricycle fares\",\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Delivery fares, Makati store\",\"subtotal\":\"480.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"480.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":\"Petty Cash Fund\",\"class\":\"Makati Store\",\"other_name\":null,\"lines\":[{\"line_kind\":\"journal\",\"item\":null,\"account\":\"6100\",\"description\":\"Fares for small deliveries\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"480.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(77,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',NULL,NULL,'bank','bank.deposits','create','transaction',70,'Deposit DEP-00001','194044.63',NULL,'{\"txn_type\":\"deposit\",\"txn_no\":\"DEP-00001\",\"txn_date\":\"2026-09-23\",\"due_date\":null,\"ref_no\":\"DS-1001\",\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Deposit\",\"subtotal\":\"194044.63\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"194044.63\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":\"Cash in Bank - BDO Checking\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"deposit\",\"item\":null,\"account\":\"1050\",\"description\":\"Customer Payment PMT-00004\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"6384.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"deposit\",\"item\":null,\"account\":\"1050\",\"description\":\"Customer Payment PMT-00003\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"39944.07\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"deposit\",\"item\":null,\"account\":\"1050\",\"description\":\"Customer Payment PMT-00001\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"100000.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"deposit\",\"item\":null,\"account\":\"1050\",\"description\":\"Sales Receipt SR-00001\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"46466.56\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"deposit\",\"item\":null,\"account\":\"4200\",\"description\":\"Interest on time deposit\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"1250.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(78,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',NULL,NULL,'fa','fa.depreciation','create','transaction',71,'Depreciation JE-00001','56300.00',NULL,'{\"txn_type\":\"depreciation\",\"txn_no\":\"JE-00001\",\"txn_date\":\"2026-08-31\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Depreciation for August 2026\",\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"56300.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"journal\",\"item\":null,\"account\":\"6090\",\"description\":\"Depreciation - Computer and POS Equipment\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"2500.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"journal\",\"item\":null,\"account\":\"1555\",\"description\":\"Accumulated depreciation - Computer and POS Equipment\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"-2500.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"journal\",\"item\":null,\"account\":\"6090\",\"description\":\"Depreciation - Production Machinery (usage-based)\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"13800.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"journal\",\"item\":null,\"account\":\"1525\",\"description\":\"Accumulated depreciation - Production Machinery (usage-based)\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"-13800.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"journal\",\"item\":null,\"account\":\"6090\",\"description\":\"Depreciation - Transportation Equipment\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"40000.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"journal\",\"item\":null,\"account\":\"1535\",\"description\":\"Accumulated depreciation - Transportation Equipment\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"-40000.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(79,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',NULL,NULL,'fa','fa.depreciation','create','transaction',72,'Depreciation JE-00002','57650.00',NULL,'{\"txn_type\":\"depreciation\",\"txn_no\":\"JE-00002\",\"txn_date\":\"2026-09-30\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Depreciation for September 2026\",\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"57650.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"journal\",\"item\":null,\"account\":\"6090\",\"description\":\"Depreciation - Computer and POS Equipment\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"2500.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"journal\",\"item\":null,\"account\":\"1555\",\"description\":\"Accumulated depreciation - Computer and POS Equipment\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"-2500.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"journal\",\"item\":null,\"account\":\"6090\",\"description\":\"Depreciation - Production Machinery (usage-based)\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"15150.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"journal\",\"item\":null,\"account\":\"1525\",\"description\":\"Accumulated depreciation - Production Machinery (usage-based)\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"-15150.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"journal\",\"item\":null,\"account\":\"6090\",\"description\":\"Depreciation - Transportation Equipment\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"40000.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"journal\",\"item\":null,\"account\":\"1535\",\"description\":\"Accumulated depreciation - Transportation Equipment\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"-40000.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(80,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',NULL,NULL,'bank','bank.reconcile','create','transaction',73,'Service Charge JE-00003','150.00',NULL,'{\"txn_type\":\"bank_charge\",\"txn_no\":\"JE-00003\",\"txn_date\":\"2026-08-31\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Bank service charge\",\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"150.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":\"Cash in Bank - BDO Checking\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"journal\",\"item\":null,\"account\":\"6080\",\"description\":\"Service charge\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"150.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"journal\",\"item\":null,\"account\":\"1010\",\"description\":\"Service charge\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"-150.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(81,'2026-10-17 00:06:39',1,'admin','Administrator','cli','CLI',NULL,NULL,'bank','bank.reconcile','reconcile','reconciliation',1,'BDO Checking, 08/31/2026','1834185.16',NULL,NULL,NULL,NULL),
(82,'2026-10-17 00:06:39',7,'cashier1','Cashier','cli','CLI',NULL,1,'pos',NULL,'shift_open','shift',1,'Makati Counter 1','2000.00',NULL,NULL,NULL,NULL),
(83,'2026-10-17 00:06:39',7,'cashier1','Cashier','cli','CLI',2,1,'pos','pos.receipts','start','transaction',74,'POS Sale POS-000001','2517.76',NULL,'{\"txn_type\":\"pos_sale\",\"txn_no\":\"POS-000001\",\"txn_date\":\"2026-10-16\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":2,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":null,\"subtotal\":\"2248.00\",\"tax_total\":\"269.76\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"2517.76\",\"status\":\"suspended\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":\"MK1-00000001\",\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":\"Makati Store\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"MOU-001\",\"account\":null,\"description\":\"Wireless Mouse\",\"qty\":\"2.0000\",\"rate\":\"599.0000\",\"discount_amount\":\"0.00\",\"amount\":\"1198.00\",\"tax_amount\":\"143.76\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"USB-032\",\"account\":null,\"description\":\"USB Flash Drive 32GB\",\"qty\":\"3.0000\",\"rate\":\"350.0000\",\"discount_amount\":\"0.00\",\"amount\":\"1050.00\",\"tax_amount\":\"126.00\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(84,'2026-10-17 00:06:40',7,'cashier1','Cashier','cli','CLI',2,1,'pos','pos.receipts','sale','transaction',74,'POS Sale POS-000001','2517.76','[{\"field\":\"status\",\"old\":\"suspended\",\"new\":\"completed\"}]','{\"txn_type\":\"pos_sale\",\"txn_no\":\"POS-000001\",\"txn_date\":\"2026-10-16\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":2,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":null,\"subtotal\":\"2248.00\",\"tax_total\":\"269.76\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"2517.76\",\"status\":\"completed\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":\"MK1-00000001\",\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":\"Makati Store\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"MOU-001\",\"account\":null,\"description\":\"Wireless Mouse\",\"qty\":\"2.0000\",\"rate\":\"599.0000\",\"discount_amount\":\"0.00\",\"amount\":\"1198.00\",\"tax_amount\":\"143.76\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"USB-032\",\"account\":null,\"description\":\"USB Flash Drive 32GB\",\"qty\":\"3.0000\",\"rate\":\"350.0000\",\"discount_amount\":\"0.00\",\"amount\":\"1050.00\",\"tax_amount\":\"126.00\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(85,'2026-10-17 00:06:40',7,'cashier1','Cashier','cli','CLI',2,1,'pos','pos.receipts','start','transaction',75,'POS Sale POS-000002','43556.24',NULL,'{\"txn_type\":\"pos_sale\",\"txn_no\":\"POS-000002\",\"txn_date\":\"2026-10-16\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":2,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":null,\"subtotal\":\"38889.50\",\"tax_total\":\"4666.74\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"43556.24\",\"status\":\"suspended\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":\"MK1-00000002\",\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":\"Makati Store\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"LAP-001\",\"account\":null,\"description\":\"Laptop 14-inch i5 16GB\",\"qty\":\"1.0000\",\"rate\":\"39990.0000\",\"discount_amount\":\"1999.50\",\"amount\":\"37990.50\",\"tax_amount\":\"4558.86\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"BAG-001\",\"account\":null,\"description\":\"Laptop Backpack\",\"qty\":\"1.0000\",\"rate\":\"899.0000\",\"discount_amount\":\"0.00\",\"amount\":\"899.00\",\"tax_amount\":\"107.88\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(86,'2026-10-17 00:06:40',7,'cashier1','Cashier','cli','CLI',2,1,'pos','pos.receipts','sale','transaction',75,'POS Sale POS-000002','43556.24','[{\"field\":\"status\",\"old\":\"suspended\",\"new\":\"completed\"}]','{\"txn_type\":\"pos_sale\",\"txn_no\":\"POS-000002\",\"txn_date\":\"2026-10-16\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":2,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":null,\"subtotal\":\"38889.50\",\"tax_total\":\"4666.74\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"43556.24\",\"status\":\"completed\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":\"MK1-00000002\",\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":\"Makati Store\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"LAP-001\",\"account\":null,\"description\":\"Laptop 14-inch i5 16GB\",\"qty\":\"1.0000\",\"rate\":\"39990.0000\",\"discount_amount\":\"1999.50\",\"amount\":\"37990.50\",\"tax_amount\":\"4558.86\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"BAG-001\",\"account\":null,\"description\":\"Laptop Backpack\",\"qty\":\"1.0000\",\"rate\":\"899.0000\",\"discount_amount\":\"0.00\",\"amount\":\"899.00\",\"tax_amount\":\"107.88\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(87,'2026-10-17 00:06:40',7,'cashier1','Cashier','cli','CLI',2,1,'pos','pos.receipts','start','transaction',76,'POS Sale POS-000003','1564.64',NULL,'{\"txn_type\":\"pos_sale\",\"txn_no\":\"POS-000003\",\"txn_date\":\"2026-10-16\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":2,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":null,\"subtotal\":\"1397.00\",\"tax_total\":\"167.64\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"1564.64\",\"status\":\"suspended\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":\"MK1-00000003\",\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":\"Makati Store\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"KEY-001\",\"account\":null,\"description\":\"Keyboard USB\",\"qty\":\"1.0000\",\"rate\":\"999.0000\",\"discount_amount\":\"0.00\",\"amount\":\"999.00\",\"tax_amount\":\"119.88\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"CAB-HDMI\",\"account\":null,\"description\":\"HDMI Cable 1.5m\",\"qty\":\"2.0000\",\"rate\":\"199.0000\",\"discount_amount\":\"0.00\",\"amount\":\"398.00\",\"tax_amount\":\"47.76\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(88,'2026-10-17 00:06:40',7,'cashier1','Cashier','cli','CLI',2,1,'pos','pos.receipts','sale','transaction',76,'POS Sale POS-000003','1564.64','[{\"field\":\"status\",\"old\":\"suspended\",\"new\":\"completed\"}]','{\"txn_type\":\"pos_sale\",\"txn_no\":\"POS-000003\",\"txn_date\":\"2026-10-16\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":2,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":null,\"subtotal\":\"1397.00\",\"tax_total\":\"167.64\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"1564.64\",\"status\":\"completed\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":\"MK1-00000003\",\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":\"Makati Store\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"KEY-001\",\"account\":null,\"description\":\"Keyboard USB\",\"qty\":\"1.0000\",\"rate\":\"999.0000\",\"discount_amount\":\"0.00\",\"amount\":\"999.00\",\"tax_amount\":\"119.88\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"CAB-HDMI\",\"account\":null,\"description\":\"HDMI Cable 1.5m\",\"qty\":\"2.0000\",\"rate\":\"199.0000\",\"discount_amount\":\"0.00\",\"amount\":\"398.00\",\"tax_amount\":\"47.76\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(89,'2026-10-17 00:06:40',7,'cashier1','Cashier','cli','CLI',2,1,'pos','pos.receipts','start','transaction',77,'POS Sale POS-000004','10068.80',NULL,'{\"txn_type\":\"pos_sale\",\"txn_no\":\"POS-000004\",\"txn_date\":\"2026-10-16\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":2,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":null,\"subtotal\":\"8990.00\",\"tax_total\":\"1078.80\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"10068.80\",\"status\":\"suspended\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":\"MK1-00000004\",\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":\"Makati Store\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"MON-024\",\"account\":null,\"description\":\"Monitor 24-inch IPS\",\"qty\":\"1.0000\",\"rate\":\"8990.0000\",\"discount_amount\":\"0.00\",\"amount\":\"8990.00\",\"tax_amount\":\"1078.80\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(90,'2026-10-17 00:06:40',7,'cashier1','Cashier','cli','CLI',2,1,'pos','pos.receipts','sale','transaction',77,'POS Sale POS-000004','10068.80','[{\"field\":\"status\",\"old\":\"suspended\",\"new\":\"completed\"}]','{\"txn_type\":\"pos_sale\",\"txn_no\":\"POS-000004\",\"txn_date\":\"2026-10-16\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":2,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":null,\"subtotal\":\"8990.00\",\"tax_total\":\"1078.80\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"10068.80\",\"status\":\"completed\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":\"MK1-00000004\",\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":\"Makati Store\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"MON-024\",\"account\":null,\"description\":\"Monitor 24-inch IPS\",\"qty\":\"1.0000\",\"rate\":\"8990.0000\",\"discount_amount\":\"0.00\",\"amount\":\"8990.00\",\"tax_amount\":\"1078.80\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(91,'2026-10-17 00:06:40',7,'cashier1','Cashier','cli','CLI',2,1,'pos','pos.receipts','start','transaction',78,'POS Sale POS-000005','784.00',NULL,'{\"txn_type\":\"pos_sale\",\"txn_no\":\"POS-000005\",\"txn_date\":\"2026-10-16\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":2,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":null,\"subtotal\":\"700.00\",\"tax_total\":\"84.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"784.00\",\"status\":\"suspended\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":\"MK1-00000005\",\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":\"Makati Store\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"USB-032\",\"account\":null,\"description\":\"USB Flash Drive 32GB\",\"qty\":\"2.0000\",\"rate\":\"350.0000\",\"discount_amount\":\"0.00\",\"amount\":\"700.00\",\"tax_amount\":\"84.00\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(92,'2026-10-17 00:06:40',7,'cashier1','Cashier','cli','CLI',2,1,'pos','pos.receipts','sale','transaction',78,'POS Sale POS-000005','784.00','[{\"field\":\"status\",\"old\":\"suspended\",\"new\":\"completed\"}]','{\"txn_type\":\"pos_sale\",\"txn_no\":\"POS-000005\",\"txn_date\":\"2026-10-16\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":2,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":null,\"subtotal\":\"700.00\",\"tax_total\":\"84.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"784.00\",\"status\":\"completed\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":\"MK1-00000005\",\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":\"Makati Store\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"USB-032\",\"account\":null,\"description\":\"USB Flash Drive 32GB\",\"qty\":\"2.0000\",\"rate\":\"350.0000\",\"discount_amount\":\"0.00\",\"amount\":\"700.00\",\"tax_amount\":\"84.00\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(93,'2026-10-17 00:06:40',7,'cashier1','Cashier','cli','CLI',NULL,1,'pos',NULL,'cash_drop','shift',1,'Cash drop','2000.00',NULL,NULL,NULL,NULL),
(94,'2026-10-17 00:06:40',8,'supervisor','POS Supervisor','cli','CLI',2,1,'pos','pos.receipts','void','transaction',77,'POS Sale POS-000004','10068.80','[{\"field\":\"status\",\"old\":\"completed\",\"new\":\"void\"}]','{\"txn_type\":\"pos_sale\",\"txn_no\":\"POS-000004\",\"txn_date\":\"2026-10-16\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":2,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":null,\"subtotal\":\"8990.00\",\"tax_total\":\"1078.80\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"10068.80\",\"status\":\"completed\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":\"MK1-00000004\",\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":\"Makati Store\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"MON-024\",\"account\":null,\"description\":\"Monitor 24-inch IPS\",\"qty\":\"1.0000\",\"rate\":\"8990.0000\",\"discount_amount\":\"0.00\",\"amount\":\"8990.00\",\"tax_amount\":\"1078.80\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}','Customer changed mind before leaving the counter','supervisor'),
(95,'2026-10-17 00:06:40',8,'supervisor','POS Supervisor','cli','CLI',2,1,'pos','pos.receipts','start','transaction',79,'POS Return POS-000006','670.88',NULL,'{\"txn_type\":\"pos_return\",\"txn_no\":\"POS-000006\",\"txn_date\":\"2026-10-16\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":2,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Return: defective mouse\",\"subtotal\":\"599.00\",\"tax_total\":\"71.88\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"670.88\",\"status\":\"suspended\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":\"MK1-00000006\",\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"MOU-001\",\"account\":null,\"description\":\"Wireless Mouse\",\"qty\":\"1.0000\",\"rate\":\"599.0000\",\"discount_amount\":\"0.00\",\"amount\":\"599.00\",\"tax_amount\":\"71.88\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}','Defective mouse',NULL),
(96,'2026-10-17 00:06:40',8,'supervisor','POS Supervisor','cli','CLI',2,1,'pos','pos.receipts','refund','transaction',79,'POS Return POS-000006','670.88','[{\"field\":\"status\",\"old\":\"suspended\",\"new\":\"completed\"}]','{\"txn_type\":\"pos_return\",\"txn_no\":\"POS-000006\",\"txn_date\":\"2026-10-16\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":2,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Return: defective mouse\",\"subtotal\":\"599.00\",\"tax_total\":\"71.88\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"670.88\",\"status\":\"completed\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":\"MK1-00000006\",\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"MOU-001\",\"account\":null,\"description\":\"Wireless Mouse\",\"qty\":\"1.0000\",\"rate\":\"599.0000\",\"discount_amount\":\"0.00\",\"amount\":\"599.00\",\"tax_amount\":\"71.88\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}','Defective mouse','supervisor'),
(97,'2026-10-17 00:06:40',8,'supervisor','POS Supervisor','cli','CLI',2,1,'pos','pos.shifts','create','transaction',80,'Cash Over/Short JE-00004','20.00',NULL,'{\"txn_type\":\"pos_over_short\",\"txn_no\":\"JE-00004\",\"txn_date\":\"2026-10-16\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":2,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Cash short - Makati Counter 1\",\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"20.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"journal\",\"item\":null,\"account\":\"1001\",\"description\":\"Drawer count difference\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"-20.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"journal\",\"item\":null,\"account\":\"6200\",\"description\":\"Cash over and short\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"20.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(98,'2026-10-17 00:06:40',8,'supervisor','POS Supervisor','cli','CLI',NULL,1,'pos',NULL,'shift_close','shift',1,'Z-reading','2610.88',NULL,NULL,'Short by 20.00','supervisor'),
(99,'2026-10-17 00:06:40',7,'cashier1','Cashier','cli','CLI',NULL,1,'pos',NULL,'shift_open','shift',2,'Makati Counter 1','2000.00',NULL,NULL,NULL,NULL),
(100,'2026-10-17 00:06:40',7,'cashier1','Cashier','cli','CLI',2,1,'pos','pos.receipts','start','transaction',81,'POS Sale POS-000007','614.88',NULL,'{\"txn_type\":\"pos_sale\",\"txn_no\":\"POS-000007\",\"txn_date\":\"2026-10-17\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":2,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":null,\"subtotal\":\"549.00\",\"tax_total\":\"65.88\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"614.88\",\"status\":\"suspended\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":\"MK1-00000007\",\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":\"Makati Store\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"USB-032\",\"account\":null,\"description\":\"USB Flash Drive 32GB\",\"qty\":\"1.0000\",\"rate\":\"350.0000\",\"discount_amount\":\"0.00\",\"amount\":\"350.00\",\"tax_amount\":\"42.00\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"CAB-HDMI\",\"account\":null,\"description\":\"HDMI Cable 1.5m\",\"qty\":\"1.0000\",\"rate\":\"199.0000\",\"discount_amount\":\"0.00\",\"amount\":\"199.00\",\"tax_amount\":\"23.88\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL);
INSERT INTO `audit_trail` (`id`,`created_at`,`user_id`,`username`,`user_roles`,`ip_address`,`workstation`,`site_id`,`terminal_id`,`module`,`page_key`,`action`,`record_type`,`record_id`,`record_ref`,`amount`,`changes`,`snapshot`,`reason`,`approved_by`) VALUES
(101,'2026-10-17 00:06:40',7,'cashier1','Cashier','cli','CLI',2,1,'pos','pos.receipts','sale','transaction',81,'POS Sale POS-000007','614.88','[{\"field\":\"status\",\"old\":\"suspended\",\"new\":\"completed\"}]','{\"txn_type\":\"pos_sale\",\"txn_no\":\"POS-000007\",\"txn_date\":\"2026-10-17\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":2,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":null,\"subtotal\":\"549.00\",\"tax_total\":\"65.88\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"614.88\",\"status\":\"completed\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":\"MK1-00000007\",\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":\"Makati Store\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"USB-032\",\"account\":null,\"description\":\"USB Flash Drive 32GB\",\"qty\":\"1.0000\",\"rate\":\"350.0000\",\"discount_amount\":\"0.00\",\"amount\":\"350.00\",\"tax_amount\":\"42.00\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"CAB-HDMI\",\"account\":null,\"description\":\"HDMI Cable 1.5m\",\"qty\":\"1.0000\",\"rate\":\"199.0000\",\"discount_amount\":\"0.00\",\"amount\":\"199.00\",\"tax_amount\":\"23.88\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(102,'2026-10-17 00:06:40',7,'cashier1','Cashier','cli','CLI',2,1,'pos','pos.receipts','start','transaction',82,'POS Sale POS-000008','14548.80',NULL,'{\"txn_type\":\"pos_sale\",\"txn_no\":\"POS-000008\",\"txn_date\":\"2026-10-17\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":2,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":null,\"subtotal\":\"12990.00\",\"tax_total\":\"1558.80\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"14548.80\",\"status\":\"suspended\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":\"MK1-00000008\",\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":\"Makati Store\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"SET-OFFICE\",\"account\":null,\"description\":\"Office Monitor Set\",\"qty\":\"1.0000\",\"rate\":\"12990.0000\",\"discount_amount\":\"0.00\",\"amount\":\"12990.00\",\"tax_amount\":\"1558.80\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(103,'2026-10-17 00:06:40',7,'cashier1','Cashier','cli','CLI',2,1,'pos','pos.receipts','sale','transaction',82,'POS Sale POS-000008','14548.80','[{\"field\":\"status\",\"old\":\"suspended\",\"new\":\"completed\"}]','{\"txn_type\":\"pos_sale\",\"txn_no\":\"POS-000008\",\"txn_date\":\"2026-10-17\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":2,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":null,\"subtotal\":\"12990.00\",\"tax_total\":\"1558.80\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"14548.80\",\"status\":\"completed\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":\"MK1-00000008\",\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":\"Makati Store\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"SET-OFFICE\",\"account\":null,\"description\":\"Office Monitor Set\",\"qty\":\"1.0000\",\"rate\":\"12990.0000\",\"discount_amount\":\"0.00\",\"amount\":\"12990.00\",\"tax_amount\":\"1558.80\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(104,'2026-10-17 00:06:40',7,'cashier1','Cashier','cli','CLI',NULL,1,'security','admin.roles','access_denied','page',NULL,'User Role Configuration (open)',NULL,NULL,NULL,NULL,NULL),
(105,'2026-10-17 00:06:40',1,'admin','Administrator','cli','CLI',NULL,NULL,'admin',NULL,'page_access_override','user',6,'User: salesrep',NULL,'[{\"field\":\"Customer Balance Summary\",\"old\":\"Inherit from role\",\"new\":\"Override: allowed [P]\"}]',NULL,'Needs balances for account visits',NULL),
(106,'2026-10-17 00:06:40',1,'admin','Administrator','cli','CLI',NULL,NULL,'admin',NULL,'page_access_override','user',3,'User: arclerk',NULL,'[{\"field\":\"Assess Finance Charges\",\"old\":\"Inherit from role\",\"new\":\"Override: denied\"}]',NULL,'Finance charges are assessed by the accountant',NULL),
(107,'2026-10-17 00:06:40',4,'apclerk','','cli','CLI',NULL,NULL,'security',NULL,'login_failed','user',4,'apclerk',NULL,NULL,NULL,'Wrong password (attempt 1 of 5)',NULL),
(108,'2026-10-17 00:06:40',4,'apclerk','','cli','CLI',NULL,NULL,'security',NULL,'login_failed','user',4,'apclerk',NULL,NULL,NULL,'Wrong password (attempt 2 of 5)',NULL),
(109,'2026-10-17 00:06:40',1,'admin','Administrator','cli','CLI',NULL,NULL,'admin',NULL,'closing_date_change','settings',NULL,'Closing date',NULL,'[{\"field\":\"closing_date\",\"old\":\"\",\"new\":\"2026-07-29\"}]',NULL,'Opening balances finalized',NULL);

-- sequences (26 rows)
INSERT INTO `sequences` (`seq_key`,`prefix`,`next_no`,`pad`) VALUES
('adjustment','ADJ-',3,5),
('advance_apply','AAP-',1,5),
('asset','FA-',5,5),
('bill','BILL-',13,5),
('build','BLD-',3,5),
('cash_voucher','CAV-',3,5),
('check','',1012,4),
('credit_memo','CM-',2,5),
('debit_memo','DM-',2,5),
('deposit','DEP-',2,5),
('estimate','EST-',3,5),
('finance_charge','FC-',2,5),
('inv_transfer','IT-',4,5),
('invoice','INV-',15,5),
('item_receipt','IR-',2,5),
('journal','JE-',5,5),
('maintenance','MNT-',2,5),
('payment','PMT-',6,5),
('pos','POS-',9,6),
('processing','PRC-',6,5),
('purchase_order','PO-',3,5),
('sales_order','SO-',2,5),
('sales_receipt','SR-',2,5),
('statement_charge','SC-',2,5),
('transfer','TRF-',2,5),
('vendor_advance','ADV-',2,5);

-- accounts (72 rows)
INSERT INTO `accounts` (`id`,`code`,`name`,`account_type`,`category`,`normal_balance`,`parent_id`,`description`,`bank_account_no`,`with_sl`,`is_active`,`is_system`,`created_at`,`updated_at`) VALUES
(1,'1000','Cash','Bank','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(2,'1001','Cash on Hand - Store Registers','Bank','Asset','Debit',1,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(3,'1005','Petty Cash Fund','Bank','Asset','Debit',1,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(4,'1006','Revolving Fund','Bank','Asset','Debit',1,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(5,'1010','Cash in Bank - BDO Checking','Bank','Asset','Debit',1,NULL,'0012-3456-7890',0,1,0,'2026-10-17 00:06:36',NULL),
(6,'1020','Cash in Bank - BPI Savings','Bank','Asset','Debit',1,NULL,'1234-5678-90',0,1,0,'2026-10-17 00:06:36',NULL),
(7,'1050','Undeposited Funds','Other Current Asset','Asset','Debit',NULL,NULL,NULL,0,1,1,'2026-10-17 00:06:36',NULL),
(8,'1060','Card Clearing','Other Current Asset','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(9,'1065','E-wallet Clearing','Other Current Asset','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(10,'1070','P.O. Card Clearing','Other Current Asset','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(11,'1100','Accounts Receivable','Accounts Receivable','Asset','Debit',NULL,NULL,NULL,0,1,1,'2026-10-17 00:06:36',NULL),
(12,'1150','Allowance for Doubtful Accounts','Other Current Asset','Asset','Credit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(13,'1200','Inventory','Other Current Asset','Asset','Debit',NULL,NULL,NULL,0,1,1,'2026-10-17 00:06:36',NULL),
(14,'1300','Input Tax','Other Current Asset','Asset','Debit',NULL,NULL,NULL,0,1,1,'2026-10-17 00:06:36',NULL),
(15,'1310','Creditable Withholding Tax','Other Current Asset','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(16,'1315','Creditable VAT Withheld','Other Current Asset','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(17,'1400','Prepaid Expenses','Other Current Asset','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(18,'1410','Advances to Suppliers','Other Current Asset','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(19,'1500','Land','Fixed Asset','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(20,'1510','Building','Fixed Asset','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(21,'1515','Accumulated Depreciation - Building','Fixed Asset','Asset','Credit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(22,'1520','Machinery and Equipment','Fixed Asset','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(23,'1525','Accumulated Depreciation - Machinery','Fixed Asset','Asset','Credit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(24,'1530','Transportation Equipment','Fixed Asset','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(25,'1535','Accumulated Depreciation - Transportation','Fixed Asset','Asset','Credit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(26,'1540','Furniture and Fixtures','Fixed Asset','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(27,'1545','Accumulated Depreciation - Furniture','Fixed Asset','Asset','Credit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(28,'1550','Computer and POS Equipment','Fixed Asset','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(29,'1555','Accumulated Depreciation - Computer and POS','Fixed Asset','Asset','Credit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(30,'1600','Security Deposits','Other Asset','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(31,'2000','Accounts Payable','Accounts Payable','Liability','Credit',NULL,NULL,NULL,0,1,1,'2026-10-17 00:06:36',NULL),
(32,'2050','Company Credit Card','Credit Card','Liability','Credit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(33,'2100','Output Tax','Other Current Liability','Liability','Credit',NULL,NULL,NULL,0,1,1,'2026-10-17 00:06:36',NULL),
(34,'2110','Withholding Tax Payable','Other Current Liability','Liability','Credit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(35,'2115','VAT Withheld Payable','Other Current Liability','Liability','Credit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(36,'2120','Gift Vouchers Outstanding','Other Current Liability','Liability','Credit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(37,'2130','Customer Deposits','Other Current Liability','Liability','Credit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(38,'2200','Accrued Expenses','Other Current Liability','Liability','Credit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(39,'2500','Loans Payable','Long Term Liability','Liability','Credit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(40,'3000','Owner\'s Capital','Equity','Equity','Credit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(41,'3100','Owner\'s Drawings','Equity','Equity','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(42,'3200','Retained Earnings','Equity','Equity','Credit',NULL,NULL,NULL,0,1,1,'2026-10-17 00:06:36',NULL),
(43,'3900','Opening Balance Equity','Equity','Equity','Credit',NULL,NULL,NULL,0,1,1,'2026-10-17 00:06:36',NULL),
(44,'4000','Sales','Income','Income','Credit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(45,'4010','Service Income','Income','Income','Credit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(46,'4020','Delivery Income','Income','Income','Credit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(47,'4050','Sales Returns and Allowances','Income','Income','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(48,'4060','Sales Discounts','Income','Income','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(49,'4070','Item Group Price Variance','Income','Income','Credit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(50,'4110','Reimbursable Expense Income','Income','Income','Credit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(51,'4100','Finance Charge Income','Other Income','Income','Credit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(52,'4200','Interest Income','Other Income','Income','Credit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(53,'4300','Gain (Loss) on Disposal of Assets','Other Income','Income','Credit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(54,'5000','Cost of Goods Sold','Cost of Goods Sold','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(55,'5050','Purchase Discounts','Cost of Goods Sold','Expense','Credit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(56,'5100','Inventory Adjustments and Shrinkage','Cost of Goods Sold','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(57,'5200','Direct Labor Absorbed','Cost of Goods Sold','Expense','Credit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(58,'6000','Salaries and Wages','Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(59,'6010','Rent Expense','Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(60,'6020','Utilities Expense','Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(61,'6030','Repairs and Maintenance','Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(62,'6040','Office Supplies Expense','Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(63,'6050','Fuel and Oil','Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(64,'6060','Meals and Representation','Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(65,'6070','Professional Fees','Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(66,'6080','Bank and Merchant Charges','Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(67,'6090','Depreciation Expense','Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(68,'6100','Freight and Delivery','Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(69,'6110','Purchases - Non-inventory','Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(70,'6200','Cash Over and Short','Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(71,'6900','Miscellaneous Expense','Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL),
(72,'7000','Interest Expense','Other Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-10-17 00:06:36',NULL);

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

-- classes (3 rows)
INSERT INTO `classes` (`id`,`name`,`description`,`is_active`,`sort_order`,`created_by`,`created_at`,`updated_at`) VALUES
(1,'Head Office','Wholesale, projects and administration',1,1,1,'2026-10-17 00:06:39',NULL),
(2,'Makati Store','Retail counter in Makati',1,2,1,'2026-10-17 00:06:39',NULL),
(3,'Cebu Store','Retail counter in Cebu',1,3,1,'2026-10-17 00:06:39',NULL);

-- other_names (3 rows)
INSERT INTO `other_names` (`id`,`name_type`,`name`,`employee_no`,`position`,`phone`,`address`,`tin`,`notes`,`is_active`,`created_at`,`updated_at`) VALUES
(1,'employee','Ella Ramos','EMP-007','Cashier',NULL,NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL),
(2,'employee','Dan Villanueva','EMP-005','Inventory clerk',NULL,NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL),
(3,'other','Barangay Treasurer',NULL,'Permits and clearances',NULL,NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL);

-- customers (9 rows)
INSERT INTO `customers` (`id`,`parent_id`,`name`,`company_name`,`contact_person`,`phone`,`mobile`,`email`,`billing_address`,`shipping_address`,`tin`,`wht_ids`,`terms_id`,`credit_limit`,`price_level_id`,`tax_code_id`,`payment_method_id`,`customer_type_id`,`sales_rep_id`,`billing_group_id`,`allow_pos_charge`,`notes`,`is_active`,`created_at`,`updated_at`) VALUES
(1,NULL,'ABC Trading Corp.','ABC Trading Corporation','Mr. Albert Co','(02) 8777-1001',NULL,'ap@abctrading.test','45 Buendia Ave., Makati City','45 Buendia Ave., Makati City','111-222-333-000',NULL,3,'250000.00',NULL,1,2,1,1,NULL,1,NULL,1,'2026-10-17 00:06:39',NULL),
(2,1,'Office Renovation Project',NULL,NULL,NULL,NULL,NULL,'45 Buendia Ave., Makati City',NULL,NULL,NULL,3,'0.00',NULL,1,NULL,1,1,NULL,0,NULL,1,'2026-10-17 00:06:39',NULL),
(3,NULL,'Metro School Supplies','Metro School Supplies Inc.','Ms. Bea Lim','(02) 8777-2002',NULL,'purchasing@metroschool.test','88 España Blvd., Manila',NULL,NULL,NULL,2,'100000.00',1,1,NULL,2,2,NULL,0,NULL,1,'2026-10-17 00:06:39',NULL),
(4,NULL,'Cebu Tech Hub','Cebu Tech Hub Co.','Mr. Carlo Sy','(032) 255-3003',NULL,'finance@cebutech.test','IT Park, Lahug, Cebu City',NULL,NULL,NULL,4,'150000.00',2,1,NULL,1,2,NULL,0,NULL,1,'2026-10-17 00:06:39',NULL),
(5,NULL,'Bright Minds Academy','Bright Minds Academy','Dr. Dina Reyes','(02) 8777-4004',NULL,'admin@brightminds.test','12 Katipunan Ave., Quezon City',NULL,NULL,NULL,2,'60000.00',NULL,1,NULL,3,1,1,0,NULL,1,'2026-10-17 00:06:39',NULL),
(6,NULL,'Green Valley Clinic','Green Valley Clinic','Dr. Eric Tan','(02) 8777-5005',NULL,NULL,'5 Shaw Blvd., Mandaluyong',NULL,NULL,NULL,2,'40000.00',NULL,1,NULL,1,1,1,0,NULL,1,'2026-10-17 00:06:39',NULL),
(7,NULL,'City Government of Makati','City Government of Makati','Procurement Office','(02) 8870-1000',NULL,'procurement@makati.test','Makati City Hall, J.P. Rizal St., Makati City',NULL,'000-456-789-000','3,1',3,'0.00',NULL,1,2,4,NULL,NULL,0,NULL,1,'2026-10-17 00:06:39',NULL),
(8,NULL,'Juan Dela Cruz',NULL,'Juan Dela Cruz',NULL,'0917-555-0000',NULL,NULL,NULL,NULL,NULL,1,'0.00',NULL,1,1,2,NULL,NULL,0,NULL,1,'2026-10-17 00:06:39',NULL),
(9,NULL,'Walk-in Customer',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'0.00',NULL,1,1,2,NULL,NULL,0,NULL,1,'2026-10-17 00:06:39',NULL);

-- vendors (8 rows)
INSERT INTO `vendors` (`id`,`name`,`company_name`,`contact_person`,`phone`,`fax`,`email`,`address`,`tin`,`terms_id`,`credit_limit`,`default_expense_account_id`,`tax_code_id`,`account_no`,`wht_ids`,`notes`,`is_active`,`created_at`,`updated_at`) VALUES
(1,'TechDistributors Inc.','TechDistributors Inc.','Rico Lopez','(02) 8555-0101',NULL,'sales@techdist.test','Pasig City','689-713-592-000',3,'0.00',NULL,1,'TD-88012','1',NULL,1,'2026-10-17 00:06:39',NULL),
(2,'Office Depot PH','Office Depot PH','Liza Go','(02) 8555-0202',NULL,'orders@officedepot.test','Quezon City','790-966-120-000',2,'0.00',62,1,'OD-4410',NULL,NULL,1,'2026-10-17 00:06:39',NULL),
(3,'Meralco','Meralco','Customer Service','16211',NULL,'billing@meralco.test','Pasig City','382-901-218-000',1,'0.00',60,1,'1234-5678-9012',NULL,NULL,1,'2026-10-17 00:06:39',NULL),
(4,'Metro Property Leasing','Metro Property Leasing','Tony Chua','(02) 8555-0303',NULL,'leasing@metroprop.test','Makati City','143-884-232-000',1,'0.00',59,1,'L-2291',NULL,NULL,1,'2026-10-17 00:06:39',NULL),
(5,'Petron Service Station','Petron Service Station',NULL,'(02) 8555-0404',NULL,NULL,'Makati City','881-269-669-000',1,'0.00',63,1,NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL),
(6,'JRS Express','JRS Express','Operations','(02) 8555-0505',NULL,'ops@jrs.test','Manila','274-987-980-000',2,'0.00',68,1,'JRS-7781','2',NULL,1,'2026-10-17 00:06:39',NULL),
(7,'Accounting Partners & Co.','Accounting Partners & Co.','Atty. Reyes','(02) 8555-0606',NULL,'hello@apco.test','Taguig City','867-979-538-000',3,'0.00',65,1,NULL,'2',NULL,1,'2026-10-17 00:06:39',NULL),
(8,'Industrial Machines Corp.','Industrial Machines Corp.','Sales','(02) 8555-0707',NULL,'sales@imc.test','Laguna','238-783-773-000',3,'0.00',NULL,1,'IMC-100','1',NULL,1,'2026-10-17 00:06:39',NULL);

-- entity_notes (2 rows)
INSERT INTO `entity_notes` (`id`,`entity_type`,`entity_id`,`note`,`is_todo`,`due_date`,`is_done`,`created_by`,`created_at`) VALUES
(1,'customer',6,'Call Dr. Tan about the overdue balance',1,'2026-10-19',0,1,'2026-10-17 00:06:40'),
(2,'vendor',1,'Negotiate volume discount on laptops',1,'2026-10-27',0,1,'2026-10-17 00:06:40');

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
(1,'Piece','count','pc',1,'2026-10-17 00:06:36',NULL),
(2,'Weight (kg)','weight','kg',1,'2026-10-17 00:06:36',NULL),
(3,'Volume (L)','volume','L',1,'2026-10-17 00:06:36',NULL),
(4,'Length (m)','length','m',1,'2026-10-17 00:06:36',NULL),
(5,'Time (hour)','time','hr',1,'2026-10-17 00:06:36',NULL);

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
(1,'inventory','LAP-001','4800000000011','Laptop 14-inch i5 16GB','Laptop 14-inch i5 16GB','Laptop 14-inch i5 16GB',1,'pc',1,NULL,NULL,'32000.0000','32000.0000','39990.0000','0.00',44,54,13,NULL,1,NULL,1,'5.0000','20.0000','0.0000',1,'2026-10-17 00:06:39',NULL),
(2,'inventory','MON-024','4800000000028','Monitor 24-inch IPS','Monitor 24-inch IPS','Monitor 24-inch IPS',1,'pc',1,NULL,NULL,'6500.0000','6500.0000','8990.0000','0.00',44,54,13,NULL,1,NULL,1,'5.0000','30.0000','0.0000',1,'2026-10-17 00:06:39',NULL),
(3,'inventory','KEY-001','4800000000035','Keyboard USB','Keyboard USB','Keyboard USB',2,'pc',1,NULL,NULL,'650.0000','616.6667','999.0000','0.00',44,54,13,NULL,1,NULL,1,'10.0000','50.0000','0.0000',1,'2026-10-17 00:06:39',NULL),
(4,'inventory','MOU-001','4800000000042','Wireless Mouse','Wireless Mouse','Wireless Mouse',2,'pc',1,NULL,NULL,'350.0000','350.0000','599.0000','0.00',44,54,13,NULL,1,NULL,1,'15.0000','80.0000','0.0000',1,'2026-10-17 00:06:39',NULL),
(5,'inventory','USB-032','4800000000059','USB Flash Drive 32GB','USB Flash Drive 32GB','USB Flash Drive 32GB',2,'pc',1,NULL,NULL,'180.0000','175.0000','350.0000','0.00',44,54,13,NULL,1,NULL,1,'20.0000','100.0000','0.0000',1,'2026-10-17 00:06:39',NULL),
(6,'inventory','BAG-001','4800000000066','Laptop Backpack','Laptop Backpack','Laptop Backpack',2,'pc',1,NULL,NULL,'500.0000','500.0000','899.0000','0.00',44,54,13,NULL,1,NULL,1,'10.0000','40.0000','0.0000',1,'2026-10-17 00:06:39',NULL),
(7,'inventory','CAB-HDMI','4800000000073','HDMI Cable 1.5m','HDMI Cable 1.5m','HDMI Cable 1.5m',2,'pc',1,NULL,NULL,'90.0000','90.0000','199.0000','0.00',44,54,13,NULL,1,NULL,1,'20.0000','100.0000','0.0000',1,'2026-10-17 00:06:39',NULL),
(8,'inventory','RAM-8GB','4800000000080','RAM 8GB DDR4','RAM 8GB DDR4','RAM 8GB DDR4',2,'pc',1,NULL,NULL,'1100.0000','963.4764','1690.0000','0.00',44,54,13,NULL,1,NULL,1,'10.0000','40.0000','0.0000',1,'2026-10-17 00:06:39',NULL),
(9,'inventory','SSD-512','4800000000097','SSD 512GB NVMe','SSD 512GB NVMe','SSD 512GB NVMe',2,'pc',1,NULL,NULL,'2200.0000','2173.3126','3290.0000','0.00',44,54,13,NULL,1,NULL,1,'10.0000','40.0000','0.0000',1,'2026-10-17 00:06:39',NULL),
(10,'service','LAB-ASM',NULL,'Assembly Labor (per set)','Assembly labor',NULL,3,'hr',5,NULL,NULL,'150.0000','0.0000','0.0000','0.00',45,57,NULL,57,4,NULL,NULL,'0.0000','0.0000','0.0000',1,'2026-10-17 00:06:39',NULL),
(11,'assembly','SET-OFFICE','4800000000103','Office Monitor Set','Monitor + keyboard + mouse + HDMI cable, assembled',NULL,4,'pc',1,NULL,NULL,'0.0000','7706.6600','12990.0000','0.00',44,54,13,NULL,1,NULL,NULL,'3.0000','15.0000','3.0000',1,'2026-10-17 00:06:39',NULL),
(12,'service','SRV-INSTALL',NULL,'Installation and Setup','On-site installation and setup',NULL,3,'hr',5,NULL,NULL,'0.0000','0.0000','1500.0000','0.00',45,54,NULL,NULL,1,NULL,NULL,'0.0000','0.0000','0.0000',1,'2026-10-17 00:06:39',NULL),
(13,'service','SRV-REPAIR',NULL,'Repair Service (per hour)','Repair service',NULL,3,'hr',5,NULL,NULL,'0.0000','0.0000','800.0000','0.00',45,54,NULL,NULL,1,NULL,NULL,'0.0000','0.0000','0.0000',1,'2026-10-17 00:06:39',NULL),
(14,'service','SRV-MAINT',NULL,'Monthly IT Maintenance','Monthly IT maintenance contract',NULL,3,'hr',5,NULL,NULL,'0.0000','0.0000','5000.0000','0.00',45,54,NULL,NULL,1,NULL,NULL,'0.0000','0.0000','0.0000',1,'2026-10-17 00:06:39',NULL),
(15,'non_inventory','NI-TONER',NULL,'Toner Cartridge (special order)','Toner cartridge - special order',NULL,5,'pc',1,NULL,NULL,'2500.0000','0.0000','3200.0000','0.00',44,54,NULL,54,1,NULL,2,'0.0000','0.0000','0.0000',1,'2026-10-17 00:06:39',NULL),
(16,'other_charge','DEL-FEE',NULL,'Delivery Fee','Delivery fee',NULL,6,'pc',1,NULL,NULL,'0.0000','0.0000','250.0000','0.00',46,54,NULL,68,1,NULL,NULL,'0.0000','0.0000','0.0000',1,'2026-10-17 00:06:39',NULL),
(17,'other_charge','REIMB',NULL,'Reimbursable Expense','Reimbursable expense',NULL,6,'pc',1,NULL,NULL,'0.0000','0.0000','0.0000','0.00',50,54,NULL,71,4,NULL,NULL,'0.0000','0.0000','0.0000',1,'2026-10-17 00:06:39',NULL),
(18,'other_charge','LATE-FEE',NULL,'Late Payment Fee','Late payment fee',NULL,6,'pc',1,NULL,NULL,'0.0000','0.0000','200.0000','0.00',51,54,NULL,NULL,4,NULL,NULL,'0.0000','0.0000','0.0000',1,'2026-10-17 00:06:39',NULL),
(19,'discount','DISC-10',NULL,'10% Discount','10% discount',NULL,6,'pc',1,NULL,NULL,'0.0000','0.0000','0.0000','10.00',48,54,NULL,NULL,1,NULL,NULL,'0.0000','0.0000','0.0000',1,'2026-10-17 00:06:39',NULL),
(20,'discount','DISC-AMT',NULL,'Fixed Discount','Discount',NULL,6,'pc',1,NULL,NULL,'0.0000','0.0000','100.0000','0.00',48,54,NULL,NULL,1,NULL,NULL,'0.0000','0.0000','0.0000',1,'2026-10-17 00:06:39',NULL),
(21,'subtotal','SUBTOTAL',NULL,'Subtotal','Subtotal',NULL,NULL,'pc',1,NULL,NULL,'0.0000','0.0000','0.0000','0.00',44,54,NULL,NULL,NULL,NULL,NULL,'0.0000','0.0000','0.0000',1,'2026-10-17 00:06:39',NULL),
(22,'group','GRP-WFH',NULL,'Work-from-Home Bundle','Laptop + mouse + backpack',NULL,4,'pc',1,NULL,NULL,'0.0000','0.0000','40000.0000','0.00',44,54,NULL,NULL,NULL,NULL,NULL,'0.0000','0.0000','0.0000',1,'2026-10-17 00:06:39',NULL),
(23,'payment','DOWNPMT',NULL,'Down Payment Received','Less: down payment received',NULL,NULL,'pc',1,NULL,NULL,'0.0000','0.0000','0.0000','0.00',44,54,NULL,NULL,NULL,NULL,NULL,'0.0000','0.0000','0.0000',1,'2026-10-17 00:06:39',NULL),
(24,'inventory','USB-032-BX50','4800000000110','USB Flash Drive 32GB (Box of 50)','USB Flash Drive 32GB, box of 50','USB Flash Drive 32GB, box of 50',2,'box',NULL,NULL,NULL,'8500.0000','8500.0000','16500.0000','0.00',44,54,13,NULL,1,NULL,1,'1.0000','5.0000','0.0000',1,'2026-10-17 00:06:39',NULL),
(25,'inventory','TRD-PC',NULL,'Trade-in Desktop PC (used)','Used desktop PC taken in for parts / refurbishing','Trade-in desktop PC',1,'pc',1,NULL,NULL,'3000.0000','3000.0000','0.0000','0.00',44,54,13,NULL,1,NULL,NULL,'0.0000','0.0000','0.0000',1,'2026-10-17 00:06:39',NULL),
(26,'inventory','REF-PC',NULL,'Refurbished Desktop PC','Refurbished desktop PC with new SSD, 90-day warranty',NULL,1,'pc',1,NULL,NULL,'0.0000','4737.3150','14990.0000','0.00',44,54,13,NULL,1,NULL,NULL,'0.0000','0.0000','0.0000',1,'2026-10-17 00:06:39',NULL),
(27,'inventory','SCRAP-KG',NULL,'Scrap Metal and Plastic','Scrap metal and plastic (sold by the kilo)',NULL,5,'kg',2,NULL,NULL,'15.0000','13.0000','25.0000','0.00',44,54,13,NULL,3,NULL,NULL,'0.0000','0.0000','0.0000',1,'2026-10-17 00:06:39',NULL);

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
(1,'BRK-USB50','Break bulk: USB 32GB box of 50','dekit','quantity',NULL,'Open a box of 50 and sell the drives one by one.',1,NULL,'2026-10-17 00:06:39',NULL),
(2,'TD-PC','Trade-in PC teardown','disassembly','sales_value',NULL,'Strip a trade-in PC for resaleable parts; the chassis is sold as scrap by the kilo.',1,NULL,'2026-10-17 00:06:39',NULL),
(3,'RFB-PC','Refurbish trade-in PC (new SSD)','co_product','percent',NULL,'Trade-in PC plus a new SSD become a refurbished PC; the old RAM is recovered for resale.',1,NULL,'2026-10-17 00:06:39',NULL);

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

-- item_site_stock (29 rows)
INSERT INTO `item_site_stock` (`item_id`,`site_id`,`qty_on_hand`) VALUES
(1,1,'4.0000'),
(1,2,'3.0000'),
(1,3,'4.0000'),
(2,1,'13.0000'),
(2,2,'7.0000'),
(2,3,'6.0000'),
(3,1,'106.0000'),
(3,2,'10.0000'),
(3,3,'10.0000'),
(4,1,'17.0000'),
(4,2,'20.0000'),
(4,3,'20.0000'),
(5,1,'100.0000'),
(5,2,'23.0000'),
(5,3,'30.0000'),
(6,1,'1.0000'),
(6,2,'7.0000'),
(6,3,'8.0000'),
(7,1,'25.0000'),
(7,2,'14.0000'),
(7,3,'15.0000'),
(8,1,'25.0000'),
(9,1,'19.0000'),
(11,1,'0.0000'),
(11,2,'0.0000'),
(24,1,'1.0000'),
(25,1,'1.0000'),
(26,1,'2.0000'),
(27,1,'15.0000');

-- transactions (81 rows)
INSERT INTO `transactions` (`id`,`txn_type`,`txn_no`,`txn_date`,`due_date`,`ship_date`,`ref_no`,`customer_id`,`vendor_id`,`payee_name`,`account_id`,`account2_id`,`site_id`,`site2_id`,`terms_id`,`sales_rep_id`,`payment_method_id`,`billing_address`,`shipping_address`,`memo`,`customer_message`,`subtotal`,`tax_total`,`discount_amount`,`withholding_amount`,`cash_back_amount`,`total`,`status`,`is_pending`,`is_voided`,`void_reason`,`voided_by`,`voided_at`,`to_be_printed`,`is_printed`,`restock`,`credit_disposition`,`progress_pct`,`source_txn_id`,`terminal_id`,`pos_shift_id`,`receipt_no`,`amount_tendered`,`change_given`,`approved_by`,`batch_ref`,`process_type`,`alloc_method`,`process_formula_id`,`process_batches`,`class_id`,`other_name_id`,`received_via`,`created_by`,`created_at`,`updated_by`,`updated_at`) VALUES
(1,'opening_balance','OB-0001','2026-07-29',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'Opening balances',NULL,'0.00','0.00','0.00','0.00','0.00','3320000.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL,NULL),
(2,'check','1001','2026-08-01',NULL,NULL,NULL,NULL,8,NULL,5,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'Purchase of Packaging Machine PM-500',NULL,'500000.00','0.00','0.00','0.00','0.00','500000.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL,NULL),
(3,'bill','BILL-00001','2026-08-01','2026-08-31',NULL,'IMC-5521',NULL,8,NULL,31,NULL,NULL,NULL,3,NULL,NULL,NULL,NULL,'Purchase of Delivery Van (L300)',NULL,'1200000.00','0.00','0.00','0.00','0.00','1200000.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL,NULL),
(4,'check','1002','2026-08-01',NULL,NULL,NULL,NULL,1,NULL,5,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'Purchase of POS Terminal Set (Makati)',NULL,'60000.00','0.00','0.00','0.00','0.00','60000.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL,NULL),
(5,'bill','BILL-00002','2026-08-01','2026-08-31',NULL,'IMC-5530',NULL,8,NULL,31,NULL,NULL,NULL,3,NULL,NULL,NULL,NULL,'Purchase of Printing Machine PR-300',NULL,'500000.00','0.00','0.00','0.00','0.00','500000.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL,NULL),
(6,'bill','BILL-00003','2026-09-27','2026-10-27',NULL,'IMC-SV-0192',NULL,8,NULL,31,NULL,NULL,NULL,3,NULL,NULL,NULL,NULL,'Repair of FA-00002 Delivery Van (L300) (MNT-00001)',NULL,'12500.00','0.00','0.00','0.00','0.00','12500.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL,NULL),
(7,'purchase_order','PO-00001','2026-08-03','2026-08-08',NULL,NULL,NULL,1,NULL,NULL,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,'Initial stock',NULL,'1073200.00','128784.00','0.00','0.00','0.00','1201984.00','closed',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL,'2026-10-17 00:06:39'),
(8,'bill','BILL-00004','2026-08-06','2026-09-05',NULL,'TD-INV-10231',NULL,1,NULL,31,NULL,1,NULL,3,NULL,NULL,NULL,NULL,'Received against Purchase Order PO-00001',NULL,'1007200.00','120864.00','0.00','0.00','0.00','1128064.00','paid',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL,'2026-10-17 00:06:39'),
(9,'bill','BILL-00005','2026-08-12','2026-09-11',NULL,'TD-INV-10288',NULL,1,NULL,31,NULL,1,NULL,3,NULL,NULL,NULL,NULL,'Bill for received items',NULL,'67000.00','8040.00','0.00','0.00','0.00','75040.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-10-17 00:06:39',1,'2026-10-17 00:06:39'),
(10,'purchase_order','PO-00002','2026-10-12','2026-10-24',NULL,NULL,NULL,1,NULL,NULL,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,'Restock laptops and RAM',NULL,'336500.00','40380.00','0.00','0.00','0.00','376880.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL,NULL),
(11,'bill','BILL-00006','2026-09-07','2026-09-22',NULL,'OD-99812',NULL,2,NULL,31,NULL,NULL,NULL,2,NULL,NULL,NULL,NULL,NULL,NULL,'10000.00','1200.00','0.00','0.00','0.00','11200.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL,NULL),
(12,'bill','BILL-00007','2026-09-09','2026-10-09',NULL,'TD-INV-10344',NULL,1,NULL,31,NULL,1,NULL,3,NULL,NULL,NULL,NULL,'Keyboards bought by the box',NULL,'72000.00','8640.00','0.00','0.00','0.00','80640.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL,NULL),
(13,'inventory_transfer','IT-00001','2026-08-14',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,2,NULL,NULL,NULL,NULL,NULL,'Stock for store',NULL,'0.00','0.00','0.00','0.00','0.00','0.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL,NULL),
(14,'inventory_transfer','IT-00002','2026-08-15',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,3,NULL,NULL,NULL,NULL,NULL,'Stock for store',NULL,'0.00','0.00','0.00','0.00','0.00','0.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL,NULL),
(15,'build_assembly','BLD-00001','2026-08-18',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,'Weekly build',NULL,'0.00','0.00','0.00','0.00','0.00','0.00','completed',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL,NULL),
(16,'inventory_transfer','IT-00003','2026-08-19',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,2,NULL,NULL,NULL,NULL,NULL,'Display set for Makati store',NULL,'0.00','0.00','0.00','0.00','0.00','0.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL,NULL),
(17,'build_assembly','BLD-00002','2026-10-14',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,'Waiting for monitors',NULL,'0.00','0.00','0.00','0.00','0.00','0.00','pending',1,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL,NULL),
(18,'bill','BILL-00008','2026-09-01','2026-10-01',NULL,'TD-INV-10390',NULL,1,NULL,31,NULL,1,NULL,3,NULL,NULL,NULL,NULL,'Bulk USB boxes and trade-in PCs',NULL,'43500.00','5220.00','0.00','0.00','0.00','48720.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL,NULL),
(19,'item_processing','PRC-00001','2026-09-07',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,'Opened two boxes for single-unit sales',NULL,'17000.00','0.00','0.00','0.00','0.00','17000.00','completed',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,'dekit','quantity',1,'2.0000',NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL,NULL),
(20,'item_processing','PRC-00002','2026-09-12',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,'Teardown of trade-ins; one RAM stick failed testing',NULL,'9000.00','0.00','0.00','0.00','0.00','9450.00','completed',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,'disassembly','sales_value',2,'3.0000',NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL,NULL),
(21,'item_processing','PRC-00003','2026-09-22',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,'Refurbished units for the Makati store',NULL,'10346.62','0.00','0.00','0.00','0.00','11146.62','completed',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,'co_product','percent',3,'2.0000',NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL,NULL),
(22,'item_processing','PRC-00004','2026-10-02',NULL,NULL,NULL,NULL,NULL,NULL,56,NULL,2,NULL,NULL,NULL,NULL,NULL,NULL,'Display set taken apart; parts back to stock',NULL,'7706.67','0.00','0.00','0.00','0.00','7706.67','completed',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,'disassembly','average_cost',NULL,'1.0000',NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL,NULL),
(23,'item_processing','PRC-00005','2026-10-15',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,'Waiting for more trade-in units',NULL,'6000.00','0.00','0.00','0.00','0.00','6300.00','pending',1,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,'disassembly','sales_value',2,'2.0000',NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL,NULL),
(24,'estimate','EST-00001','2026-08-20','2026-09-19',NULL,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,NULL,NULL,'Office equipment for 5 workstations',NULL,'272650.00','32718.00','0.00','0.00','0.00','305368.00','accepted',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL,'2026-10-17 00:06:39'),
(25,'sales_order','SO-00001','2026-08-22',NULL,'2026-08-28','ABC-PO-7781',1,NULL,NULL,NULL,NULL,1,NULL,NULL,1,NULL,'45 Buendia Ave., Makati City',NULL,NULL,NULL,'272650.00','32718.00','0.00','0.00','0.00','305368.00','partial',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL,'2026-10-17 00:06:39'),
(26,'invoice','INV-00001','2026-08-28','2026-09-27',NULL,'ABC-PO-7781',1,NULL,NULL,11,NULL,1,NULL,3,1,NULL,'45 Buendia Ave., Makati City',NULL,NULL,'Thank you for your business.','163690.00','19642.80','0.00','0.00','0.00','183332.80','partial',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,NULL,1,'2026-10-17 00:06:39',NULL,'2026-10-17 00:06:39'),
(27,'bill','BILL-00009','2026-09-02','2026-09-17',NULL,'JRS-55012',NULL,6,NULL,31,NULL,NULL,NULL,2,NULL,NULL,NULL,NULL,NULL,NULL,'1800.00','216.00','0.00','0.00','0.00','2016.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL,NULL),
(28,'check','1003','2026-09-03',NULL,NULL,NULL,NULL,NULL,'Hardware Depot',3,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'Cables and conduits for job',NULL,'950.00','0.00','0.00','0.00','0.00','950.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL,NULL),
(29,'invoice','INV-00002','2026-09-27','2026-10-27',NULL,NULL,2,NULL,NULL,11,NULL,1,NULL,3,1,NULL,'45 Buendia Ave., Makati City',NULL,NULL,'Thank you for your business.','6200.00','744.00','0.00','0.00','0.00','6944.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,NULL,1,'2026-10-17 00:06:39',NULL,NULL),
(30,'invoice','INV-00003','2026-10-05','2026-11-04',NULL,'ABC-PO-7781',1,NULL,NULL,11,NULL,1,NULL,3,1,NULL,'45 Buendia Ave., Makati City',NULL,NULL,'Thank you for your business.','79980.00','9597.60','0.00','0.00','0.00','89577.60','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,NULL,1,'2026-10-17 00:06:39',NULL,NULL),
(31,'invoice','INV-00004','2026-08-30','2026-09-14',NULL,NULL,3,NULL,NULL,11,NULL,1,NULL,2,2,NULL,'88 España Blvd., Manila',NULL,NULL,'Thank you for your business.','35217.92','4226.15','0.00','0.00','0.00','39444.07','paid',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,NULL,1,'2026-10-17 00:06:39',NULL,'2026-10-17 00:06:39'),
(32,'invoice','INV-00005','2026-09-12','2026-09-27',NULL,NULL,3,NULL,NULL,11,NULL,1,NULL,2,2,NULL,'88 España Blvd., Manila',NULL,NULL,'Thank you for your business.','12321.50','1478.58','0.00','0.00','0.00','13800.08','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,NULL,1,'2026-10-17 00:06:39',NULL,NULL),
(33,'invoice','INV-00006','2026-09-17','2026-10-17',NULL,NULL,4,NULL,NULL,11,NULL,1,NULL,4,2,NULL,'IT Park, Lahug, Cebu City',NULL,NULL,'Thank you for your business.','86356.00','10362.72','0.00','0.00','0.00','96718.72','paid',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,NULL,1,'2026-10-17 00:06:39',NULL,'2026-10-17 00:06:39'),
(34,'invoice','INV-00007','2026-08-03','2026-08-18',NULL,NULL,6,NULL,NULL,11,NULL,1,NULL,2,1,NULL,'5 Shaw Blvd., Mandaluyong',NULL,NULL,'Thank you for your business.','11400.00','1368.00','0.00','0.00','0.00','12768.00','partial',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,NULL,1,'2026-10-17 00:06:39',NULL,'2026-10-17 00:06:39'),
(35,'invoice','INV-00008','2026-08-16','2026-08-31',NULL,NULL,5,NULL,NULL,11,NULL,1,NULL,2,1,NULL,'12 Katipunan Ave., Quezon City',NULL,'Monthly IT maintenance','Thank you for your business.','5000.00','600.00','0.00','0.00','0.00','5600.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,'B202608160900',NULL,NULL,NULL,NULL,1,NULL,NULL,1,'2026-10-17 00:06:39',NULL,NULL),
(36,'invoice','INV-00009','2026-08-16','2026-08-31',NULL,NULL,6,NULL,NULL,11,NULL,1,NULL,2,1,NULL,'5 Shaw Blvd., Mandaluyong',NULL,'Monthly IT maintenance','Thank you for your business.','5000.00','600.00','0.00','0.00','0.00','5600.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,'B202608160900',NULL,NULL,NULL,NULL,1,NULL,NULL,1,'2026-10-17 00:06:39',NULL,NULL),
(37,'invoice','INV-00010','2026-09-16','2026-10-01',NULL,NULL,5,NULL,NULL,11,NULL,1,NULL,2,1,NULL,'12 Katipunan Ave., Quezon City',NULL,'Monthly IT maintenance','Thank you for your business.','5000.00','600.00','0.00','0.00','0.00','5600.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,'B202609160900',NULL,NULL,NULL,NULL,1,NULL,NULL,1,'2026-10-17 00:06:39',NULL,NULL),
(38,'invoice','INV-00011','2026-09-16','2026-10-01',NULL,NULL,6,NULL,NULL,11,NULL,1,NULL,2,1,NULL,'5 Shaw Blvd., Mandaluyong',NULL,'Monthly IT maintenance','Thank you for your business.','5000.00','600.00','0.00','0.00','0.00','5600.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,'B202609160900',NULL,NULL,NULL,NULL,1,NULL,NULL,1,'2026-10-17 00:06:39',NULL,NULL),
(39,'invoice','INV-00012','2026-10-15','2026-11-14',NULL,NULL,4,NULL,NULL,11,NULL,1,NULL,4,2,NULL,'IT Park, Lahug, Cebu City',NULL,'Awaiting PO approval','Thank you for your business.','32364.00','3883.68','0.00','0.00','0.00','36247.68','pending',1,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,NULL,1,'2026-10-17 00:06:39',NULL,'2026-10-17 00:06:39'),
(40,'sales_receipt','SR-00001','2026-09-07',NULL,NULL,NULL,8,NULL,NULL,7,NULL,1,NULL,NULL,NULL,1,NULL,NULL,'Phone order',NULL,'41488.00','4978.56','0.00','0.00','0.00','46466.56','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL,NULL),
(41,'invoice','INV-00013','2026-09-27','2026-10-12',NULL,NULL,3,NULL,NULL,11,NULL,1,NULL,2,2,NULL,'88 España Blvd., Manila',NULL,'3 dozen keyboards, 1,500.00 off','Thank you for your business.','31500.00','3780.00','0.00','0.00','0.00','35280.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,NULL,1,'2026-10-17 00:06:39',NULL,NULL),
(42,'payment','PMT-00001','2026-09-22',NULL,NULL,'BDO-004412',1,NULL,NULL,7,11,NULL,NULL,NULL,NULL,2,NULL,NULL,NULL,NULL,'0.00','0.00','0.00','1500.00','0.00','100000.00','closed',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL,'2026-10-17 00:06:39'),
(43,'payment','PMT-00002','2026-09-25',NULL,NULL,'IB-88123',4,NULL,NULL,5,11,NULL,NULL,NULL,NULL,6,NULL,NULL,NULL,NULL,'0.00','0.00','1934.37','0.00','0.00','94784.35','closed',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL,'2026-10-17 00:06:39'),
(44,'payment','PMT-00003','2026-09-19',NULL,NULL,'MBTC-1120',3,NULL,NULL,7,11,NULL,NULL,NULL,NULL,2,NULL,NULL,NULL,NULL,'0.00','0.00','0.00','0.00','0.00','39944.07','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL,NULL),
(45,'payment','PMT-00004','2026-08-18',NULL,NULL,NULL,6,NULL,NULL,7,11,NULL,NULL,NULL,NULL,4,NULL,NULL,NULL,NULL,'0.00','0.00','0.00','0.00','0.00','6384.00','closed',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL,'2026-10-17 00:06:39'),
(46,'invoice','INV-00014','2026-09-13','2026-10-13',NULL,NULL,7,NULL,NULL,11,NULL,1,NULL,3,NULL,NULL,'Makati City Hall, J.P. Rizal St., Makati City',NULL,'Monitors for the city hall offices','Thank you for your business.','89900.00','10788.00','0.00','0.00','0.00','100688.00','paid',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,NULL,1,'2026-10-17 00:06:39',NULL,'2026-10-17 00:06:39'),
(47,'payment','PMT-00005','2026-10-05',NULL,NULL,'LBP-205511',7,NULL,NULL,7,11,NULL,NULL,NULL,NULL,2,NULL,NULL,'5% VAT and 1% withheld; BIR Form 2307 to follow',NULL,'0.00','0.00','0.00','5394.00','0.00','95294.00','closed',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL,'2026-10-17 00:06:39'),
(48,'credit_memo','CM-00001','2026-09-20',NULL,NULL,NULL,3,NULL,NULL,11,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,'Returned 2 defective keyboards',NULL,'1898.10','227.77','0.00','0.00','0.00','2125.87','open',0,0,NULL,NULL,NULL,0,0,1,'keep',NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL,NULL),
(49,'statement_charge','SC-00001','2026-10-02','2026-10-02',NULL,NULL,6,NULL,NULL,11,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'Late payment fee',NULL,'200.00','0.00','0.00','0.00','0.00','200.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL,NULL),
(50,'finance_charge','FC-00001','2026-10-16','2026-10-16',NULL,NULL,6,NULL,NULL,11,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'Finance charge on overdue balance',NULL,'120.50','0.00','0.00','0.00','0.00','120.50','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL,NULL),
(51,'check','1004','2026-08-04',NULL,NULL,NULL,NULL,4,NULL,5,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'Office and warehouse rent',NULL,'85000.00','0.00','0.00','0.00','0.00','85000.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL,NULL),
(52,'check','1005','2026-09-03',NULL,NULL,NULL,NULL,4,NULL,5,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'Office and warehouse rent',NULL,'85000.00','0.00','0.00','0.00','0.00','85000.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL,NULL),
(53,'check','1006','2026-10-03',NULL,NULL,NULL,NULL,4,NULL,5,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'Office and warehouse rent',NULL,'85000.00','0.00','0.00','0.00','0.00','85000.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL,NULL),
(54,'bill','BILL-00010','2026-08-18','2026-08-28',NULL,'MER-202608',NULL,3,NULL,31,NULL,NULL,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,'18450.75','2214.09','0.00','0.00','0.00','20664.84','paid',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL,'2026-10-17 00:06:39'),
(55,'bill','BILL-00011','2026-09-17','2026-09-27',NULL,'MER-202609',NULL,3,NULL,31,NULL,NULL,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,'21230.40','2547.65','0.00','0.00','0.00','23778.05','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL,NULL),
(56,'bill','BILL-00012','2026-08-23','2026-09-22',NULL,'APC-2231',NULL,7,NULL,31,NULL,NULL,NULL,3,NULL,NULL,NULL,NULL,'Quarterly bookkeeping review',NULL,'45000.00','5400.00','0.00','0.00','0.00','50400.00','paid',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL,'2026-10-17 00:06:39'),
(57,'check','1007','2026-09-14',NULL,NULL,NULL,NULL,5,NULL,3,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'Fuel for delivery van',NULL,'3500.00','420.00','0.00','0.00','0.00','3920.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL,NULL),
(58,'vendor_credit','DM-00001','2026-09-01',NULL,NULL,'TD-CM-331',NULL,1,NULL,31,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,'Returned damaged mice',NULL,'700.00','84.00','0.00','0.00','0.00','784.00','closed',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL,'2026-10-17 00:06:39'),
(59,'bill_payment','1008','2026-09-07',NULL,NULL,NULL,NULL,1,NULL,5,31,NULL,NULL,NULL,NULL,2,NULL,NULL,'Payment of TD-INV-10231',NULL,'0.00','0.00','0.00','0.00','0.00','1127280.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL,NULL),
(60,'bill_payment','1009','2026-08-26',NULL,NULL,'IB-77100',NULL,3,NULL,5,31,NULL,NULL,NULL,NULL,6,NULL,NULL,'Electricity',NULL,'0.00','0.00','0.00','0.00','0.00','20664.84','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL,NULL),
(61,'bill_payment','1010','2026-09-27',NULL,NULL,NULL,NULL,7,NULL,5,31,NULL,NULL,NULL,NULL,2,NULL,NULL,'Payment of APC-2231, 2% withheld',NULL,'0.00','0.00','0.00','900.00','0.00','49500.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL,NULL),
(62,'vendor_advance','ADV-00001','2026-10-03','2026-11-06',NULL,'1188',NULL,8,NULL,5,18,NULL,NULL,NULL,NULL,2,NULL,NULL,'30% down payment on the packaging machine',NULL,'150000.00','0.00','0.00','0.00','0.00','150000.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL,NULL),
(63,'check','1011','2026-10-07',NULL,NULL,NULL,NULL,NULL,'Office Snacks Co.',5,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'Pantry supplies',NULL,'2500.00','0.00','0.00','0.00','0.00','2500.00','void',0,1,'Check printed with wrong payee',1,'2026-10-17 00:06:39',0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL,'2026-10-17 00:06:39'),
(65,'inventory_adjustment','ADJ-00001','2026-09-23',NULL,NULL,NULL,NULL,NULL,NULL,56,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,'Damage - water leak',NULL,'0.00','0.00','0.00','0.00','0.00','0.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL,NULL),
(66,'inventory_adjustment','ADJ-00002','2026-10-09',NULL,NULL,NULL,NULL,NULL,NULL,56,NULL,2,NULL,NULL,NULL,NULL,NULL,NULL,'Physical count by D. Villanueva',NULL,'0.00','0.00','0.00','0.00','0.00','0.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL,NULL),
(67,'transfer','TRF-00001','2026-09-02',NULL,NULL,NULL,NULL,NULL,NULL,5,3,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'Replenish petty cash',NULL,'0.00','0.00','0.00','0.00','0.00','10000.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL,NULL),
(68,'cash_voucher','CAV-00001','2026-09-17',NULL,NULL,NULL,NULL,NULL,NULL,3,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'Packing tape and markers for the warehouse',NULL,'1250.00','0.00','0.00','0.00','0.00','1250.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,1,2,NULL,1,'2026-10-17 00:06:39',NULL,NULL),
(69,'cash_voucher','CAV-00002','2026-10-05',NULL,NULL,NULL,NULL,NULL,'Jeepney and tricycle fares',3,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'Delivery fares, Makati store',NULL,'480.00','0.00','0.00','0.00','0.00','480.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,2,NULL,NULL,1,'2026-10-17 00:06:39',NULL,NULL),
(70,'deposit','DEP-00001','2026-09-23',NULL,NULL,'DS-1001',NULL,NULL,NULL,5,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'Deposit',NULL,'194044.63','0.00','0.00','0.00','0.00','194044.63','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL,NULL),
(71,'depreciation','JE-00001','2026-08-31',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'Depreciation for August 2026',NULL,'0.00','0.00','0.00','0.00','0.00','56300.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL,NULL),
(72,'depreciation','JE-00002','2026-09-30',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'Depreciation for September 2026',NULL,'0.00','0.00','0.00','0.00','0.00','57650.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL,NULL),
(73,'bank_charge','JE-00003','2026-08-31',NULL,NULL,NULL,NULL,NULL,NULL,5,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'Bank service charge',NULL,'0.00','0.00','0.00','0.00','0.00','150.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL,NULL),
(74,'pos_sale','POS-000001','2026-10-16',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,2,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2248.00','269.76','0.00','0.00','0.00','2517.76','completed',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,1,1,'MK1-00000001','3000.00','482.24',NULL,NULL,NULL,NULL,NULL,NULL,2,NULL,NULL,7,'2026-10-16 09:12:00',7,'2026-10-17 00:06:39'),
(75,'pos_sale','POS-000002','2026-10-16',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,2,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'38889.50','4666.74','0.00','0.00','0.00','43556.24','completed',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,1,1,'MK1-00000002','43556.24','0.00',NULL,NULL,NULL,NULL,NULL,NULL,2,NULL,NULL,7,'2026-10-16 10:49:00',7,'2026-10-17 00:06:40'),
(76,'pos_sale','POS-000003','2026-10-16',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,2,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'1397.00','167.64','0.00','0.00','0.00','1564.64','completed',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,1,1,'MK1-00000003','1564.64','0.00',NULL,NULL,NULL,NULL,NULL,NULL,2,NULL,NULL,7,'2026-10-16 12:26:00',7,'2026-10-17 00:06:40'),
(77,'pos_sale','POS-000004','2026-10-16',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,2,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'8990.00','1078.80','0.00','0.00','0.00','10068.80','void',0,1,'Customer changed mind before leaving the counter',8,'2026-10-17 00:06:40',0,0,1,NULL,NULL,NULL,1,1,'MK1-00000004','10100.00','31.20',8,NULL,NULL,NULL,NULL,NULL,2,NULL,NULL,7,'2026-10-16 14:03:00',7,'2026-10-17 00:06:40'),
(78,'pos_sale','POS-000005','2026-10-16',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,2,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'700.00','84.00','0.00','0.00','0.00','784.00','completed',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,1,1,'MK1-00000005','1000.00','216.00',NULL,NULL,NULL,NULL,NULL,NULL,2,NULL,NULL,7,'2026-10-16 15:40:00',7,'2026-10-17 00:06:40'),
(79,'pos_return','POS-000006','2026-10-16',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,2,NULL,NULL,NULL,NULL,NULL,NULL,'Return: defective mouse',NULL,'599.00','71.88','0.00','0.00','0.00','670.88','completed',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,74,1,1,'MK1-00000006','0.00','0.00',8,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,8,'2026-10-16 17:17:00',8,'2026-10-17 00:06:40'),
(80,'pos_over_short','JE-00004','2026-10-16',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,2,NULL,NULL,NULL,NULL,NULL,NULL,'Cash short - Makati Counter 1',NULL,'0.00','0.00','0.00','0.00','0.00','20.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,1,1,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,8,'2026-10-16 18:54:00',NULL,NULL),
(81,'pos_sale','POS-000007','2026-10-17',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,2,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'549.00','65.88','0.00','0.00','0.00','614.88','completed',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,1,2,'MK1-00000007','1000.00','385.12',NULL,NULL,NULL,NULL,NULL,NULL,2,NULL,NULL,7,'2026-10-17 00:06:40',7,'2026-10-17 00:06:40'),
(82,'pos_sale','POS-000008','2026-10-17',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,2,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'12990.00','1558.80','0.00','0.00','0.00','14548.80','completed',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,1,2,'MK1-00000008','14548.80','0.00',NULL,NULL,NULL,NULL,NULL,NULL,2,NULL,NULL,7,'2026-10-17 00:06:40',7,'2026-10-17 00:06:40');

-- transaction_lines (175 rows)
INSERT INTO `transaction_lines` (`id`,`txn_id`,`line_no`,`line_kind`,`item_id`,`account_id`,`description`,`qty`,`unit`,`uom_id`,`uom_factor`,`uom_qty`,`uom_rate`,`rate`,`discount_kind`,`discount_pct`,`discount_amount`,`amount`,`tax_code_id`,`tax_amount`,`site_id`,`customer_id`,`vendor_id`,`is_billable`,`billed_txn_id`,`ref_txn_id`,`pos_shift_id`,`source_line_id`,`qty_fulfilled`,`amount_fulfilled`,`is_closed`,`cost_amount`,`value_change`,`output_role`,`alloc_basis`,`alloc_pct`,`planned_qty`,`class_id`,`other_name_id`,`group_item_id`,`group_ref`,`group_qty`,`group_rate`,`group_role`) VALUES
(1,1,1,'journal',NULL,5,'BDO checking opening balance','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','2500000.00',NULL,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(2,1,2,'journal',NULL,6,'BPI savings opening balance','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','800000.00',NULL,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(3,1,3,'journal',NULL,3,'Petty cash fund','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','10000.00',NULL,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(4,1,4,'journal',NULL,2,'Register cash funds','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','10000.00',NULL,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(5,1,5,'journal',NULL,40,'Owner\'s capital','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','-3320000.00',NULL,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(6,2,1,'expense',NULL,22,'Packaging Machine PM-500','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','500000.00',NULL,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(7,3,1,'expense',NULL,24,'Delivery Van (L300)','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','1200000.00',NULL,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(8,4,1,'expense',NULL,28,'POS Terminal Set (Makati)','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','60000.00',NULL,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(9,5,1,'expense',NULL,22,'Printing Machine PR-300','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','500000.00',NULL,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(10,6,1,'expense',NULL,61,'Parts - MNT-00001 FA-00002 Delivery Van (L300)','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','11000.00',NULL,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(11,6,2,'expense',NULL,61,'Labor - MNT-00001 FA-00002 Delivery Van (L300)','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','1500.00',NULL,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(12,7,1,'item',1,NULL,'Laptop 14-inch i5 16GB','20.0000','pc',NULL,'1.000000','20.0000','32000.0000','32000.0000','pct','0.00','0.00','640000.00',1,'76800.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'20.0000','640000.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(13,7,2,'item',2,NULL,'Monitor 24-inch IPS','40.0000','pc',NULL,'1.000000','40.0000','6500.0000','6500.0000','pct','0.00','0.00','260000.00',1,'31200.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'40.0000','260000.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(14,7,3,'item',3,NULL,'Keyboard USB','60.0000','pc',NULL,'1.000000','60.0000','650.0000','650.0000','pct','0.00','0.00','39000.00',1,'4680.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'60.0000','39000.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(15,7,4,'item',4,NULL,'Wireless Mouse','80.0000','pc',NULL,'1.000000','80.0000','350.0000','350.0000','pct','0.00','0.00','28000.00',1,'3360.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'80.0000','28000.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(16,7,5,'item',5,NULL,'USB Flash Drive 32GB','100.0000','pc',NULL,'1.000000','100.0000','180.0000','180.0000','pct','0.00','0.00','18000.00',1,'2160.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'100.0000','18000.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(17,7,6,'item',6,NULL,'Laptop Backpack','30.0000','pc',NULL,'1.000000','30.0000','500.0000','500.0000','pct','0.00','0.00','15000.00',1,'1800.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'30.0000','15000.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(18,7,7,'item',7,NULL,'HDMI Cable 1.5m','80.0000','pc',NULL,'1.000000','80.0000','90.0000','90.0000','pct','0.00','0.00','7200.00',1,'864.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'80.0000','7200.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(19,7,8,'item',8,NULL,'RAM 8GB DDR4','20.0000','pc',NULL,'1.000000','20.0000','1100.0000','1100.0000','pct','0.00','0.00','22000.00',1,'2640.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'20.0000','22000.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(20,7,9,'item',9,NULL,'SSD 512GB NVMe','20.0000','pc',NULL,'1.000000','20.0000','2200.0000','2200.0000','pct','0.00','0.00','44000.00',1,'5280.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'20.0000','45000.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(21,8,1,'item',1,NULL,'Laptop 14-inch i5 16GB','20.0000','pc',NULL,'1.000000','20.0000','32000.0000','32000.0000','pct','0.00','0.00','640000.00',1,'76800.00',1,NULL,NULL,0,NULL,NULL,NULL,12,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(22,8,2,'item',2,NULL,'Monitor 24-inch IPS','40.0000','pc',NULL,'1.000000','40.0000','6500.0000','6500.0000','pct','0.00','0.00','260000.00',1,'31200.00',1,NULL,NULL,0,NULL,NULL,NULL,13,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(23,8,3,'item',3,NULL,'Keyboard USB','60.0000','pc',NULL,'1.000000','60.0000','650.0000','650.0000','pct','0.00','0.00','39000.00',1,'4680.00',1,NULL,NULL,0,NULL,NULL,NULL,14,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(24,8,4,'item',4,NULL,'Wireless Mouse','80.0000','pc',NULL,'1.000000','80.0000','350.0000','350.0000','pct','0.00','0.00','28000.00',1,'3360.00',1,NULL,NULL,0,NULL,NULL,NULL,15,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(25,8,5,'item',5,NULL,'USB Flash Drive 32GB','100.0000','pc',NULL,'1.000000','100.0000','180.0000','180.0000','pct','0.00','0.00','18000.00',1,'2160.00',1,NULL,NULL,0,NULL,NULL,NULL,16,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(26,8,6,'item',6,NULL,'Laptop Backpack','30.0000','pc',NULL,'1.000000','30.0000','500.0000','500.0000','pct','0.00','0.00','15000.00',1,'1800.00',1,NULL,NULL,0,NULL,NULL,NULL,17,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(27,8,7,'item',7,NULL,'HDMI Cable 1.5m','80.0000','pc',NULL,'1.000000','80.0000','90.0000','90.0000','pct','0.00','0.00','7200.00',1,'864.00',1,NULL,NULL,0,NULL,NULL,NULL,18,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(28,9,1,'item',8,NULL,'RAM 8GB DDR4','20.0000','pc',NULL,'1.000000','20.0000','1100.0000','1100.0000','pct','0.00','0.00','22000.00',1,'2640.00',1,NULL,NULL,0,NULL,NULL,NULL,19,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(29,9,2,'item',9,NULL,'SSD 512GB NVMe','20.0000','pc',NULL,'1.000000','20.0000','2250.0000','2250.0000','pct','0.00','0.00','45000.00',1,'5400.00',1,NULL,NULL,0,NULL,NULL,NULL,20,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(30,10,1,'item',1,NULL,'Laptop 14-inch i5 16GB','10.0000','pc',NULL,'1.000000','10.0000','32000.0000','32000.0000','pct','0.00','0.00','320000.00',1,'38400.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(31,10,2,'item',8,NULL,'RAM 8GB DDR4','15.0000','pc',NULL,'1.000000','15.0000','1100.0000','1100.0000','pct','0.00','0.00','16500.00',1,'1980.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(32,11,1,'item',15,NULL,'Toner Cartridge (special order)','4.0000','pc',NULL,'1.000000','4.0000','2500.0000','2500.0000','pct','0.00','0.00','10000.00',1,'1200.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(33,12,1,'item',3,NULL,'Keyboard USB (box of 24)','120.0000','box',3,'24.000000','5.0000','14400.0000','600.0000','pct','0.00','0.00','72000.00',1,'8640.00',1,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(34,13,1,'item',1,NULL,'Store stock','4.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'128000.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(35,13,2,'item',2,NULL,'Store stock','6.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'39000.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(36,13,3,'item',3,NULL,'Store stock','10.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'6166.67','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(37,13,4,'item',4,NULL,'Store stock','20.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'7000.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(38,13,5,'item',5,NULL,'Store stock','30.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'5400.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(39,13,6,'item',6,NULL,'Store stock','8.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'4000.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(40,13,7,'item',7,NULL,'Store stock','15.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'1350.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(41,14,1,'item',1,NULL,'Store stock','4.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'128000.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(42,14,2,'item',2,NULL,'Store stock','6.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'39000.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(43,14,3,'item',3,NULL,'Store stock','10.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'6166.67','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(44,14,4,'item',4,NULL,'Store stock','20.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'7000.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(45,14,5,'item',5,NULL,'Store stock','30.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'5400.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(46,14,6,'item',6,NULL,'Store stock','8.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'4000.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(47,14,7,'item',7,NULL,'Store stock','15.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'1350.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(48,15,1,'item',11,NULL,'Office Monitor Set','5.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'38533.33','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(49,15,2,'component',2,NULL,'Component','5.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'32500.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(50,15,3,'component',3,NULL,'Component','5.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'3083.33','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(51,15,4,'component',4,NULL,'Component','5.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'1750.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(52,15,5,'component',7,NULL,'Component','5.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'450.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(53,15,6,'component',10,NULL,'Component','5.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'750.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(54,16,1,'item',11,NULL,'Office Monitor Set','2.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'15413.33','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(55,17,1,'item',11,NULL,'Office Monitor Set','30.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(56,17,2,'component',2,NULL,'Component','30.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(57,17,3,'component',3,NULL,'Component','30.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(58,17,4,'component',4,NULL,'Component','30.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(59,17,5,'component',7,NULL,'Component','30.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(60,17,6,'component',10,NULL,'Component','30.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(61,18,1,'item',24,NULL,'USB Flash Drive 32GB (Box of 50)','3.0000','box',NULL,'1.000000','3.0000','8500.0000','8500.0000','pct','0.00','0.00','25500.00',1,'3060.00',1,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(62,18,2,'item',25,NULL,'Trade-in Desktop PC (used)','6.0000','pc',NULL,'1.000000','6.0000','3000.0000','3000.0000','pct','0.00','0.00','18000.00',1,'2160.00',1,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(63,19,1,'input',24,NULL,'USB Flash Drive 32GB (Box of 50)','2.0000','box',NULL,'1.000000','0.0000','0.0000','8500.0000','pct','0.00','0.00','17000.00',NULL,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'17000.00','0.00',NULL,'0.0000','0.0000','2.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(64,19,2,'output',5,NULL,'USB Flash Drive 32GB','100.0000','pc',NULL,'1.000000','0.0000','0.0000','170.0000','pct','0.00','0.00','17000.00',NULL,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'17000.00','0.00','co_product','0.0000','100.0000','100.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(65,20,1,'input',25,NULL,'Trade-in Desktop PC (used)','3.0000','pc',NULL,'1.000000','0.0000','0.0000','3000.0000','pct','0.00','0.00','9000.00',NULL,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'9000.00','0.00',NULL,'0.0000','0.0000','3.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(66,20,2,'cost',NULL,57,'Technician labor (1 hour)','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','450.00',NULL,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'450.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(67,20,3,'output',8,NULL,'RAM 8GB DDR4','5.0000','pc',NULL,'1.000000','0.0000','0.0000','853.7640','pct','0.00','0.00','4268.82',NULL,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'4268.82','0.00','co_product','0.0000','45.1727','6.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(68,20,4,'output',9,NULL,'SSD 512GB NVMe','3.0000','pc',NULL,'1.000000','0.0000','0.0000','1662.0600','pct','0.00','0.00','4986.18',NULL,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'4986.18','0.00','co_product','0.0000','52.7638','3.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(69,20,5,'output',27,NULL,'Scrap Metal and Plastic','13.0000','kg',NULL,'1.000000','0.0000','0.0000','15.0000','pct','0.00','0.00','195.00',NULL,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'195.00','0.00','by_product','15.0000','2.0635','12.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(70,21,1,'input',25,NULL,'Trade-in Desktop PC (used)','2.0000','pc',NULL,'1.000000','0.0000','0.0000','3000.0000','pct','0.00','0.00','6000.00',NULL,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'6000.00','0.00',NULL,'0.0000','0.0000','2.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(71,21,2,'input',9,NULL,'SSD 512GB NVMe','2.0000','pc',NULL,'1.000000','0.0000','0.0000','2173.3100','pct','0.00','0.00','4346.62',NULL,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'4346.62','0.00',NULL,'0.0000','0.0000','2.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(72,21,3,'cost',NULL,57,'Refurbishing labor and testing','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','800.00',NULL,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'800.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(73,21,4,'output',26,NULL,'Refurbished Desktop PC','2.0000','pc',NULL,'1.000000','0.0000','0.0000','4737.3150','pct','0.00','0.00','9474.63',NULL,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'9474.63','0.00','co_product','85.0000','85.0000','2.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(74,21,5,'output',8,NULL,'RAM 8GB DDR4','4.0000','pc',NULL,'1.000000','0.0000','0.0000','417.9975','pct','0.00','0.00','1671.99',NULL,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'1671.99','0.00','co_product','15.0000','15.0000','4.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(75,21,6,'output',27,NULL,'Scrap Metal and Plastic','2.0000','kg',NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00','scrap','0.0000','0.0000','2.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(76,22,1,'input',11,NULL,'Office Monitor Set','1.0000','pc',NULL,'1.000000','0.0000','0.0000','7706.6700','pct','0.00','0.00','7706.67',NULL,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'7706.67','0.00',NULL,'0.0000','0.0000','1.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(77,22,2,'output',7,NULL,'HDMI Cable 1.5m','1.0000','pc',NULL,'1.000000','0.0000','0.0000','90.0000','pct','0.00','0.00','90.00',NULL,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'90.00','0.00','co_product','0.0000','1.1678','1.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(78,22,3,'output',3,NULL,'Keyboard USB','1.0000','pc',NULL,'1.000000','0.0000','0.0000','616.6700','pct','0.00','0.00','616.67',NULL,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'616.67','0.00','co_product','0.0000','8.0018','1.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(79,22,4,'output',2,NULL,'Monitor 24-inch IPS','1.0000','pc',NULL,'1.000000','0.0000','0.0000','6500.0000','pct','0.00','0.00','6500.00',NULL,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'6500.00','0.00','co_product','0.0000','84.3425','1.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(80,22,5,'output',4,NULL,'Wireless Mouse','1.0000','pc',NULL,'1.000000','0.0000','0.0000','350.0000','pct','0.00','0.00','350.00',NULL,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'350.00','0.00','co_product','0.0000','4.5415','1.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(81,23,1,'input',25,NULL,'Trade-in Desktop PC (used)','2.0000','pc',NULL,'1.000000','0.0000','0.0000','3000.0000','pct','0.00','0.00','6000.00',NULL,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000','2.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(82,23,2,'cost',NULL,57,'Technician labor (1 hour)','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','300.00',NULL,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(83,23,3,'output',8,NULL,'RAM 8GB DDR4','4.0000','pc',NULL,'1.000000','0.0000','0.0000','782.9225','pct','0.00','0.00','3131.69',NULL,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00','co_product','0.0000','49.7094','4.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(84,23,4,'output',9,NULL,'SSD 512GB NVMe','2.0000','pc',NULL,'1.000000','0.0000','0.0000','1524.1550','pct','0.00','0.00','3048.31',NULL,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00','co_product','0.0000','48.3859','2.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(85,23,5,'output',27,NULL,'Scrap Metal and Plastic','8.0000','kg',NULL,'1.000000','0.0000','0.0000','15.0000','pct','0.00','0.00','120.00',NULL,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00','by_product','15.0000','1.9048','8.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(86,24,1,'item',1,NULL,'Laptop 14-inch i5 16GB','5.0000','pc',NULL,'1.000000','5.0000','39990.0000','39990.0000','pct','0.00','0.00','199950.00',1,'23994.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(87,24,2,'item',11,NULL,'Office Monitor Set','5.0000','pc',NULL,'1.000000','5.0000','12990.0000','12990.0000','pct','0.00','0.00','64950.00',1,'7794.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(88,24,3,'item',12,NULL,'Installation and Setup','5.0000','hr',NULL,'1.000000','5.0000','1500.0000','1500.0000','pct','0.00','0.00','7500.00',1,'900.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(89,24,4,'item',16,NULL,'Delivery Fee','1.0000','pc',NULL,'1.000000','1.0000','250.0000','250.0000','pct','0.00','0.00','250.00',1,'30.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(90,25,1,'item',1,NULL,'Laptop 14-inch i5 16GB','5.0000','pc',NULL,'1.000000','5.0000','39990.0000','39990.0000','pct','0.00','0.00','199950.00',1,'23994.00',NULL,NULL,NULL,0,NULL,NULL,NULL,86,'5.0000','199950.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(91,25,2,'item',11,NULL,'Office Monitor Set','5.0000','pc',NULL,'1.000000','5.0000','12990.0000','12990.0000','pct','0.00','0.00','64950.00',1,'7794.00',NULL,NULL,NULL,0,NULL,NULL,NULL,87,'3.0000','38970.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(92,25,3,'item',12,NULL,'Installation and Setup','5.0000','hr',NULL,'1.000000','5.0000','1500.0000','1500.0000','pct','0.00','0.00','7500.00',1,'900.00',NULL,NULL,NULL,0,NULL,NULL,NULL,88,'3.0000','4500.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(93,25,4,'item',16,NULL,'Delivery Fee','1.0000','pc',NULL,'1.000000','1.0000','250.0000','250.0000','pct','0.00','0.00','250.00',1,'30.00',NULL,NULL,NULL,0,NULL,NULL,NULL,89,'1.0000','250.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(94,26,1,'item',1,NULL,'Laptop 14-inch i5 16GB','3.0000','pc',NULL,'1.000000','3.0000','39990.0000','39990.0000','pct','0.00','0.00','119970.00',1,'14396.40',NULL,NULL,NULL,0,NULL,NULL,NULL,90,'0.0000','0.00',0,'96000.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(95,26,2,'item',11,NULL,'Office Monitor Set','3.0000','pc',NULL,'1.000000','3.0000','12990.0000','12990.0000','pct','0.00','0.00','38970.00',1,'4676.40',NULL,NULL,NULL,0,NULL,NULL,NULL,91,'0.0000','0.00',0,'23120.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(96,26,3,'item',12,NULL,'Installation and Setup','3.0000','hr',NULL,'1.000000','3.0000','1500.0000','1500.0000','pct','0.00','0.00','4500.00',1,'540.00',NULL,NULL,NULL,0,NULL,NULL,NULL,92,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(97,26,4,'item',16,NULL,'Delivery Fee','1.0000','pc',NULL,'1.000000','1.0000','250.0000','250.0000','pct','0.00','0.00','250.00',1,'30.00',NULL,NULL,NULL,0,NULL,NULL,NULL,93,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(98,27,1,'expense',NULL,68,'Freight - Office Renovation Project','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','1800.00',1,'216.00',NULL,2,NULL,1,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(99,28,1,'expense',NULL,71,'Conduits - Office Renovation Project','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','950.00',NULL,'0.00',NULL,2,NULL,1,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(100,29,1,'item',12,NULL,'Installation and Setup','2.0000','hr',NULL,'1.000000','2.0000','1500.0000','1500.0000','pct','0.00','0.00','3000.00',1,'360.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL);
INSERT INTO `transaction_lines` (`id`,`txn_id`,`line_no`,`line_kind`,`item_id`,`account_id`,`description`,`qty`,`unit`,`uom_id`,`uom_factor`,`uom_qty`,`uom_rate`,`rate`,`discount_kind`,`discount_pct`,`discount_amount`,`amount`,`tax_code_id`,`tax_amount`,`site_id`,`customer_id`,`vendor_id`,`is_billable`,`billed_txn_id`,`ref_txn_id`,`pos_shift_id`,`source_line_id`,`qty_fulfilled`,`amount_fulfilled`,`is_closed`,`cost_amount`,`value_change`,`output_role`,`alloc_basis`,`alloc_pct`,`planned_qty`,`class_id`,`other_name_id`,`group_item_id`,`group_ref`,`group_qty`,`group_rate`,`group_role`) VALUES
(101,29,2,'item',13,NULL,'Repair Service (per hour)','4.0000','hr',NULL,'1.000000','4.0000','800.0000','800.0000','pct','0.00','0.00','3200.00',1,'384.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(102,30,1,'item',1,NULL,'Laptop 14-inch i5 16GB','2.0000','pc',NULL,'1.000000','2.0000','39990.0000','39990.0000','pct','0.00','0.00','79980.00',1,'9597.60',NULL,NULL,NULL,0,NULL,NULL,NULL,90,'0.0000','0.00',0,'64000.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(103,31,1,'item',5,NULL,'USB Flash Drive 32GB','40.0000','pc',NULL,'1.000000','40.0000','332.5000','332.5000','pct','0.00','0.00','13300.00',1,'1596.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'7000.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(104,31,2,'item',3,NULL,'Keyboard USB','15.0000','pc',NULL,'1.000000','15.0000','949.0500','949.0500','pct','0.00','0.00','14235.75',1,'1708.29',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'9250.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(105,31,3,'item',4,NULL,'Wireless Mouse','15.0000','pc',NULL,'1.000000','15.0000','569.0500','569.0500','pct','0.00','0.00','8535.75',1,'1024.29',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'5250.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(106,31,4,'item',21,NULL,'Subtotal','0.0000','pc',NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(107,31,5,'item',19,NULL,'10% Discount','0.0000','pc',NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','-853.58',1,'-102.43',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(108,32,1,'item',6,NULL,'Laptop Backpack','10.0000','pc',NULL,'1.000000','10.0000','854.0500','854.0500','pct','0.00','0.00','8540.50',1,'1024.86',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'5000.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(109,32,2,'item',7,NULL,'HDMI Cable 1.5m','20.0000','pc',NULL,'1.000000','20.0000','189.0500','189.0500','pct','0.00','0.00','3781.00',1,'453.72',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'1800.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(110,33,1,'item',1,NULL,'Laptop 14-inch i5 16GB','2.0000','pc',NULL,'1.000000','2.0000','36500.0000','36500.0000','pct','0.00','0.00','73000.00',1,'8760.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'64000.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(111,33,2,'item',8,NULL,'RAM 8GB DDR4','4.0000','pc',NULL,'1.000000','4.0000','1521.0000','1521.0000','pct','0.00','0.00','6084.00',1,'730.08',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'3853.90','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(112,33,3,'item',9,NULL,'SSD 512GB NVMe','2.0000','pc',NULL,'1.000000','2.0000','2961.0000','2961.0000','pct','0.00','0.00','5922.00',1,'710.64',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'4346.62','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(113,33,4,'item',12,NULL,'Installation and Setup','1.0000','hr',NULL,'1.000000','1.0000','1350.0000','1350.0000','pct','0.00','0.00','1350.00',1,'162.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(114,34,1,'item',14,NULL,'Monthly IT Maintenance','1.0000','hr',NULL,'1.000000','1.0000','5000.0000','5000.0000','pct','0.00','0.00','5000.00',1,'600.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(115,34,2,'item',15,NULL,'Toner Cartridge (special order)','2.0000','pc',NULL,'1.000000','2.0000','3200.0000','3200.0000','pct','0.00','0.00','6400.00',1,'768.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(116,35,1,'item',14,NULL,'Monthly IT Maintenance','1.0000','hr',NULL,'1.000000','1.0000','5000.0000','5000.0000','pct','0.00','0.00','5000.00',1,'600.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(117,36,1,'item',14,NULL,'Monthly IT Maintenance','1.0000','hr',NULL,'1.000000','1.0000','5000.0000','5000.0000','pct','0.00','0.00','5000.00',1,'600.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(118,37,1,'item',14,NULL,'Monthly IT Maintenance','1.0000','hr',NULL,'1.000000','1.0000','5000.0000','5000.0000','pct','0.00','0.00','5000.00',1,'600.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(119,38,1,'item',14,NULL,'Monthly IT Maintenance','1.0000','hr',NULL,'1.000000','1.0000','5000.0000','5000.0000','pct','0.00','0.00','5000.00',1,'600.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(120,39,1,'item',2,NULL,'Monitor 24-inch IPS','4.0000','pc',NULL,'1.000000','4.0000','8091.0000','8091.0000','pct','0.00','0.00','32364.00',1,'3883.68',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(121,40,1,'item',1,NULL,'Laptop 14-inch i5 16GB','1.0000','pc',NULL,'1.000000','1.0000','39990.0000','39990.0000','pct','0.00','0.00','39990.00',1,'4798.80',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'32000.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(122,40,2,'item',6,NULL,'Laptop Backpack','1.0000','pc',NULL,'1.000000','1.0000','899.0000','899.0000','pct','0.00','0.00','899.00',1,'107.88',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'500.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(123,40,3,'item',4,NULL,'Wireless Mouse','1.0000','pc',NULL,'1.000000','1.0000','599.0000','599.0000','pct','0.00','0.00','599.00',1,'71.88',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'350.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(124,41,1,'item',3,NULL,'Keyboard USB (sold by the dozen)','36.0000','dz',2,'12.000000','3.0000','11000.0000','916.6667','amt','4.55','1500.00','31500.00',1,'3780.00',1,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'22200.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(125,46,1,'item',2,NULL,'Monitor 24-inch IPS','10.0000','pc',NULL,'1.000000','10.0000','8990.0000','8990.0000','pct','0.00','0.00','89900.00',1,'10788.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'65000.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(126,48,1,'item',3,NULL,'Keyboard USB','2.0000','pc',NULL,'1.000000','2.0000','949.0500','949.0500','pct','0.00','0.00','1898.10',1,'227.77',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'1233.33','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(127,49,1,'item',18,NULL,'Late Payment Fee','1.0000','pc',NULL,'1.000000','1.0000','200.0000','200.0000','pct','0.00','0.00','200.00',4,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(128,50,1,'item',NULL,51,'Finance charge (12% p.a.)','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','120.50',NULL,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(129,51,1,'item',NULL,59,'Monthly rent','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','85000.00',1,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(130,52,1,'item',NULL,59,'Monthly rent','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','85000.00',1,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(131,53,1,'item',NULL,59,'Monthly rent','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','85000.00',1,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(132,54,1,'expense',NULL,60,'Electricity','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','18450.75',1,'2214.09',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(133,55,1,'expense',NULL,60,'Electricity','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','21230.40',1,'2547.65',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(134,56,1,'expense',NULL,65,'Professional fees','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','45000.00',1,'5400.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(135,57,1,'expense',NULL,63,'Diesel','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','3500.00',1,'420.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(136,58,1,'item',4,NULL,'Wireless Mouse','2.0000','pc',NULL,'1.000000','2.0000','350.0000','350.0000','pct','0.00','0.00','700.00',1,'84.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(137,63,1,'expense',NULL,71,'Pantry supplies','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','2500.00',NULL,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(139,65,1,'item',6,NULL,'Damage','-2.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'-1000.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(140,66,1,'item',5,NULL,'Count difference (counted 29, system 30)','-1.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',2,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'-175.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(141,66,2,'item',7,NULL,'Count difference (counted 16, system 15)','1.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',2,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'90.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(142,68,1,'journal',NULL,62,'Packing supplies','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','1250.00',NULL,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,2,NULL,NULL,NULL,NULL,NULL),
(143,69,1,'journal',NULL,68,'Fares for small deliveries','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','480.00',NULL,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(144,70,1,'deposit',NULL,7,'Customer Payment PMT-00004','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','6384.00',NULL,'0.00',NULL,6,NULL,0,NULL,45,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(145,70,2,'deposit',NULL,7,'Customer Payment PMT-00003','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','39944.07',NULL,'0.00',NULL,3,NULL,0,NULL,44,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(146,70,3,'deposit',NULL,7,'Customer Payment PMT-00001','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','100000.00',NULL,'0.00',NULL,1,NULL,0,NULL,42,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(147,70,4,'deposit',NULL,7,'Sales Receipt SR-00001','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','46466.56',NULL,'0.00',NULL,8,NULL,0,NULL,40,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(148,70,5,'deposit',NULL,52,'Interest on time deposit','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','1250.00',NULL,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(149,71,1,'journal',NULL,67,'Depreciation - Computer and POS Equipment','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','2500.00',NULL,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(150,71,2,'journal',NULL,29,'Accumulated depreciation - Computer and POS Equipment','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','-2500.00',NULL,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(151,71,3,'journal',NULL,67,'Depreciation - Production Machinery (usage-based)','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','13800.00',NULL,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(152,71,4,'journal',NULL,23,'Accumulated depreciation - Production Machinery (usage-based)','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','-13800.00',NULL,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(153,71,5,'journal',NULL,67,'Depreciation - Transportation Equipment','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','40000.00',NULL,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(154,71,6,'journal',NULL,25,'Accumulated depreciation - Transportation Equipment','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','-40000.00',NULL,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(155,72,1,'journal',NULL,67,'Depreciation - Computer and POS Equipment','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','2500.00',NULL,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(156,72,2,'journal',NULL,29,'Accumulated depreciation - Computer and POS Equipment','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','-2500.00',NULL,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(157,72,3,'journal',NULL,67,'Depreciation - Production Machinery (usage-based)','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','15150.00',NULL,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(158,72,4,'journal',NULL,23,'Accumulated depreciation - Production Machinery (usage-based)','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','-15150.00',NULL,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(159,72,5,'journal',NULL,67,'Depreciation - Transportation Equipment','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','40000.00',NULL,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(160,72,6,'journal',NULL,25,'Accumulated depreciation - Transportation Equipment','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','-40000.00',NULL,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(161,73,1,'journal',NULL,66,'Service charge','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','150.00',NULL,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(162,73,2,'journal',NULL,5,'Service charge','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','-150.00',NULL,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(165,74,1,'item',4,NULL,'Wireless Mouse','2.0000','pc',NULL,'1.000000','2.0000','599.0000','599.0000','pct','0.00','0.00','1198.00',1,'143.76',2,NULL,NULL,0,NULL,NULL,NULL,NULL,'1.0000','599.00',0,'700.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(166,74,2,'item',5,NULL,'USB Flash Drive 32GB','3.0000','pc',NULL,'1.000000','3.0000','350.0000','350.0000','pct','0.00','0.00','1050.00',1,'126.00',2,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'525.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(169,75,1,'item',1,NULL,'Laptop 14-inch i5 16GB','1.0000','pc',NULL,'1.000000','1.0000','39990.0000','39990.0000','pct','5.00','1999.50','37990.50',1,'4558.86',2,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'32000.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(170,75,2,'item',6,NULL,'Laptop Backpack','1.0000','pc',NULL,'1.000000','1.0000','899.0000','899.0000','pct','0.00','0.00','899.00',1,'107.88',2,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'500.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(173,76,1,'item',3,NULL,'Keyboard USB','1.0000','pc',NULL,'1.000000','1.0000','999.0000','999.0000','pct','0.00','0.00','999.00',1,'119.88',2,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'616.67','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(174,76,2,'item',7,NULL,'HDMI Cable 1.5m','2.0000','pc',NULL,'1.000000','2.0000','199.0000','199.0000','pct','0.00','0.00','398.00',1,'47.76',2,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'180.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(176,77,1,'item',2,NULL,'Monitor 24-inch IPS','1.0000','pc',NULL,'1.000000','1.0000','8990.0000','8990.0000','pct','0.00','0.00','8990.00',1,'1078.80',2,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'6500.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(178,78,1,'item',5,NULL,'USB Flash Drive 32GB','2.0000','pc',NULL,'1.000000','2.0000','350.0000','350.0000','pct','0.00','0.00','700.00',1,'84.00',2,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'350.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(179,79,1,'item',4,NULL,'Wireless Mouse','1.0000',NULL,NULL,'1.000000','0.0000','0.0000','599.0000','pct','0.00','0.00','599.00',1,'71.88',2,NULL,NULL,0,NULL,NULL,NULL,165,'0.0000','0.00',0,'350.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(180,80,1,'journal',NULL,2,'Drawer count difference','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','-20.00',NULL,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(181,80,2,'journal',NULL,70,'Cash over and short','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','20.00',NULL,'0.00',NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(184,81,1,'item',5,NULL,'USB Flash Drive 32GB','1.0000','pc',NULL,'1.000000','1.0000','350.0000','350.0000','pct','0.00','0.00','350.00',1,'42.00',2,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'175.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(185,81,2,'item',7,NULL,'HDMI Cable 1.5m','1.0000','pc',NULL,'1.000000','1.0000','199.0000','199.0000','pct','0.00','0.00','199.00',1,'23.88',2,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'90.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
(187,82,1,'item',11,NULL,'Office Monitor Set','1.0000','pc',NULL,'1.000000','1.0000','12990.0000','12990.0000','pct','0.00','0.00','12990.00',1,'1558.80',2,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'7706.66','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL);

-- payment_applications (9 rows)
INSERT INTO `payment_applications` (`id`,`payment_txn_id`,`target_txn_id`,`amount`,`discount`,`withholding`,`created_at`) VALUES
(1,42,26,'100000.00','0.00','1500.00','2026-10-17 00:06:39'),
(2,43,33,'94784.35','1934.37','0.00','2026-10-17 00:06:39'),
(3,44,31,'39444.07','0.00','0.00','2026-10-17 00:06:39'),
(4,45,34,'6384.00','0.00','0.00','2026-10-17 00:06:39'),
(5,47,46,'95294.00','0.00','5394.00','2026-10-17 00:06:39'),
(6,58,8,'784.00','0.00','0.00','2026-10-17 00:06:39'),
(7,59,8,'1127280.00','0.00','0.00','2026-10-17 00:06:39'),
(8,60,54,'20664.84','0.00','0.00','2026-10-17 00:06:39'),
(9,61,56,'49500.00','0.00','900.00','2026-10-17 00:06:39');

-- withholding_taxes (3 rows)
INSERT INTO `withholding_taxes` (`id`,`code`,`atc`,`name`,`tax_kind`,`rate`,`base_type`,`applies_to`,`payable_account_id`,`receivable_account_id`,`description`,`sort_order`,`is_active`,`created_at`,`updated_at`) VALUES
(1,'WT-GOODS','WC158','WT on Goods','income','1.0000','net_of_vat','both',NULL,NULL,'Goods bought from regular suppliers by government payors and top withholding agents (RR 11-2018)',10,1,'2026-10-17 00:06:36',NULL),
(2,'WT-SERVICES','WC160','WT on Services','income','2.0000','net_of_vat','both',NULL,NULL,'Services bought from regular suppliers by government payors and top withholding agents (RR 11-2018)',20,1,'2026-10-17 00:06:36',NULL),
(3,'WT-VAT','WV010','WT on VAT','vat','5.0000','net_of_vat','both',NULL,NULL,'Creditable VAT withheld by government buyers on VATable purchases (5% of the VAT-exclusive payment)',30,1,'2026-10-17 00:06:36',NULL);

-- payment_withholdings (3 rows)
INSERT INTO `payment_withholdings` (`id`,`payment_txn_id`,`target_txn_id`,`wht_id`,`tax_kind`,`atc`,`rate`,`base`,`amount`,`account_id`,`created_at`) VALUES
(1,47,46,3,'vat','WV010','5.0000','89900.00','4495.00',16,'2026-10-17 00:06:39'),
(2,47,46,1,'income','WC158','1.0000','89900.00','899.00',15,'2026-10-17 00:06:39'),
(3,61,56,2,'income','WC160','2.0000','45000.00','900.00',34,'2026-10-17 00:06:39');

-- journal_lines (316 rows)
INSERT INTO `journal_lines` (`id`,`txn_id`,`txn_date`,`account_id`,`debit`,`credit`,`customer_id`,`vendor_id`,`item_id`,`site_id`,`class_id`,`other_name_id`,`memo`,`cleared`,`reconciliation_id`,`created_at`) VALUES
(1,1,'2026-07-29',5,'2500000.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,'BDO checking opening balance',1,1,'2026-10-17 00:06:39'),
(2,1,'2026-07-29',6,'800000.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,'BPI savings opening balance',0,NULL,'2026-10-17 00:06:39'),
(3,1,'2026-07-29',3,'10000.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,'Petty cash fund',0,NULL,'2026-10-17 00:06:39'),
(4,1,'2026-07-29',2,'10000.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,'Register cash funds',0,NULL,'2026-10-17 00:06:39'),
(5,1,'2026-07-29',40,'0.00','3320000.00',NULL,NULL,NULL,NULL,NULL,NULL,'Owner\'s capital',0,NULL,'2026-10-17 00:06:39'),
(6,2,'2026-08-01',22,'500000.00','0.00',NULL,8,NULL,NULL,NULL,NULL,'Packaging Machine PM-500',0,NULL,'2026-10-17 00:06:39'),
(7,2,'2026-08-01',5,'0.00','500000.00',NULL,8,NULL,NULL,NULL,NULL,'Purchase of Packaging Machine PM-500',1,1,'2026-10-17 00:06:39'),
(8,3,'2026-08-01',24,'1200000.00','0.00',NULL,8,NULL,NULL,NULL,NULL,'Delivery Van (L300)',0,NULL,'2026-10-17 00:06:39'),
(9,3,'2026-08-01',31,'0.00','1200000.00',NULL,8,NULL,NULL,NULL,NULL,'Purchase of Delivery Van (L300)',0,NULL,'2026-10-17 00:06:39'),
(10,4,'2026-08-01',28,'60000.00','0.00',NULL,1,NULL,NULL,NULL,NULL,'POS Terminal Set (Makati)',0,NULL,'2026-10-17 00:06:39'),
(11,4,'2026-08-01',5,'0.00','60000.00',NULL,1,NULL,NULL,NULL,NULL,'Purchase of POS Terminal Set (Makati)',1,1,'2026-10-17 00:06:39'),
(12,5,'2026-08-01',22,'500000.00','0.00',NULL,8,NULL,NULL,NULL,NULL,'Printing Machine PR-300',0,NULL,'2026-10-17 00:06:39'),
(13,5,'2026-08-01',31,'0.00','500000.00',NULL,8,NULL,NULL,NULL,NULL,'Purchase of Printing Machine PR-300',0,NULL,'2026-10-17 00:06:39'),
(14,6,'2026-09-27',61,'11000.00','0.00',NULL,8,NULL,NULL,NULL,NULL,'Parts - MNT-00001 FA-00002 Delivery Van (L300)',0,NULL,'2026-10-17 00:06:39'),
(15,6,'2026-09-27',61,'1500.00','0.00',NULL,8,NULL,NULL,NULL,NULL,'Labor - MNT-00001 FA-00002 Delivery Van (L300)',0,NULL,'2026-10-17 00:06:39'),
(16,6,'2026-09-27',31,'0.00','12500.00',NULL,8,NULL,NULL,NULL,NULL,'Repair of FA-00002 Delivery Van (L300) (MNT-00001)',0,NULL,'2026-10-17 00:06:39'),
(17,8,'2026-08-06',13,'640000.00','0.00',NULL,1,1,1,NULL,NULL,'Laptop 14-inch i5 16GB',0,NULL,'2026-10-17 00:06:39'),
(18,8,'2026-08-06',14,'76800.00','0.00',NULL,1,1,1,NULL,NULL,'Laptop 14-inch i5 16GB',0,NULL,'2026-10-17 00:06:39'),
(19,8,'2026-08-06',13,'260000.00','0.00',NULL,1,2,1,NULL,NULL,'Monitor 24-inch IPS',0,NULL,'2026-10-17 00:06:39'),
(20,8,'2026-08-06',14,'31200.00','0.00',NULL,1,2,1,NULL,NULL,'Monitor 24-inch IPS',0,NULL,'2026-10-17 00:06:39'),
(21,8,'2026-08-06',13,'39000.00','0.00',NULL,1,3,1,NULL,NULL,'Keyboard USB',0,NULL,'2026-10-17 00:06:39'),
(22,8,'2026-08-06',14,'4680.00','0.00',NULL,1,3,1,NULL,NULL,'Keyboard USB',0,NULL,'2026-10-17 00:06:39'),
(23,8,'2026-08-06',13,'28000.00','0.00',NULL,1,4,1,NULL,NULL,'Wireless Mouse',0,NULL,'2026-10-17 00:06:39'),
(24,8,'2026-08-06',14,'3360.00','0.00',NULL,1,4,1,NULL,NULL,'Wireless Mouse',0,NULL,'2026-10-17 00:06:39'),
(25,8,'2026-08-06',13,'18000.00','0.00',NULL,1,5,1,NULL,NULL,'USB Flash Drive 32GB',0,NULL,'2026-10-17 00:06:39'),
(26,8,'2026-08-06',14,'2160.00','0.00',NULL,1,5,1,NULL,NULL,'USB Flash Drive 32GB',0,NULL,'2026-10-17 00:06:39'),
(27,8,'2026-08-06',13,'15000.00','0.00',NULL,1,6,1,NULL,NULL,'Laptop Backpack',0,NULL,'2026-10-17 00:06:39'),
(28,8,'2026-08-06',14,'1800.00','0.00',NULL,1,6,1,NULL,NULL,'Laptop Backpack',0,NULL,'2026-10-17 00:06:39'),
(29,8,'2026-08-06',13,'7200.00','0.00',NULL,1,7,1,NULL,NULL,'HDMI Cable 1.5m',0,NULL,'2026-10-17 00:06:39'),
(30,8,'2026-08-06',14,'864.00','0.00',NULL,1,7,1,NULL,NULL,'HDMI Cable 1.5m',0,NULL,'2026-10-17 00:06:39'),
(31,8,'2026-08-06',31,'0.00','1128064.00',NULL,1,NULL,1,NULL,NULL,'Received against Purchase Order PO-00001',0,NULL,'2026-10-17 00:06:39'),
(35,9,'2026-08-12',13,'22000.00','0.00',NULL,1,8,1,NULL,NULL,'RAM 8GB DDR4',0,NULL,'2026-10-17 00:06:39'),
(36,9,'2026-08-12',14,'2640.00','0.00',NULL,1,8,1,NULL,NULL,'RAM 8GB DDR4',0,NULL,'2026-10-17 00:06:39'),
(37,9,'2026-08-12',13,'45000.00','0.00',NULL,1,9,1,NULL,NULL,'SSD 512GB NVMe',0,NULL,'2026-10-17 00:06:39'),
(38,9,'2026-08-12',14,'5400.00','0.00',NULL,1,9,1,NULL,NULL,'SSD 512GB NVMe',0,NULL,'2026-10-17 00:06:39'),
(39,9,'2026-08-12',31,'0.00','75040.00',NULL,1,NULL,1,NULL,NULL,'Bill for received items',0,NULL,'2026-10-17 00:06:39'),
(40,11,'2026-09-07',54,'10000.00','0.00',NULL,2,15,NULL,NULL,NULL,'Toner Cartridge (special order)',0,NULL,'2026-10-17 00:06:39'),
(41,11,'2026-09-07',14,'1200.00','0.00',NULL,2,15,NULL,NULL,NULL,'Toner Cartridge (special order)',0,NULL,'2026-10-17 00:06:39'),
(42,11,'2026-09-07',31,'0.00','11200.00',NULL,2,NULL,NULL,NULL,NULL,NULL,0,NULL,'2026-10-17 00:06:39'),
(43,12,'2026-09-09',13,'72000.00','0.00',NULL,1,3,1,NULL,NULL,'Keyboard USB (box of 24)',0,NULL,'2026-10-17 00:06:39'),
(44,12,'2026-09-09',14,'8640.00','0.00',NULL,1,3,1,NULL,NULL,'Keyboard USB (box of 24)',0,NULL,'2026-10-17 00:06:39'),
(45,12,'2026-09-09',31,'0.00','80640.00',NULL,1,NULL,1,NULL,NULL,'Keyboards bought by the box',0,NULL,'2026-10-17 00:06:39'),
(46,15,'2026-08-18',13,'0.00','32500.00',NULL,NULL,2,1,NULL,NULL,'Weekly build',0,NULL,'2026-10-17 00:06:39'),
(47,15,'2026-08-18',13,'0.00','3083.33',NULL,NULL,3,1,NULL,NULL,'Weekly build',0,NULL,'2026-10-17 00:06:39'),
(48,15,'2026-08-18',13,'0.00','1750.00',NULL,NULL,4,1,NULL,NULL,'Weekly build',0,NULL,'2026-10-17 00:06:39'),
(49,15,'2026-08-18',13,'0.00','450.00',NULL,NULL,7,1,NULL,NULL,'Weekly build',0,NULL,'2026-10-17 00:06:39'),
(50,15,'2026-08-18',57,'0.00','750.00',NULL,NULL,10,1,NULL,NULL,'Weekly build',0,NULL,'2026-10-17 00:06:39'),
(51,15,'2026-08-18',13,'38533.33','0.00',NULL,NULL,11,1,NULL,NULL,'Weekly build',0,NULL,'2026-10-17 00:06:39'),
(52,18,'2026-09-01',13,'25500.00','0.00',NULL,1,24,1,NULL,NULL,'USB Flash Drive 32GB (Box of 50)',0,NULL,'2026-10-17 00:06:39'),
(53,18,'2026-09-01',14,'3060.00','0.00',NULL,1,24,1,NULL,NULL,'USB Flash Drive 32GB (Box of 50)',0,NULL,'2026-10-17 00:06:39'),
(54,18,'2026-09-01',13,'18000.00','0.00',NULL,1,25,1,NULL,NULL,'Trade-in Desktop PC (used)',0,NULL,'2026-10-17 00:06:39'),
(55,18,'2026-09-01',14,'2160.00','0.00',NULL,1,25,1,NULL,NULL,'Trade-in Desktop PC (used)',0,NULL,'2026-10-17 00:06:39'),
(56,18,'2026-09-01',31,'0.00','48720.00',NULL,1,NULL,1,NULL,NULL,'Bulk USB boxes and trade-in PCs',0,NULL,'2026-10-17 00:06:39'),
(57,19,'2026-09-07',13,'0.00','17000.00',NULL,NULL,24,1,NULL,NULL,'USB Flash Drive 32GB (Box of 50)',0,NULL,'2026-10-17 00:06:39'),
(58,19,'2026-09-07',13,'17000.00','0.00',NULL,NULL,5,1,NULL,NULL,'USB Flash Drive 32GB',0,NULL,'2026-10-17 00:06:39'),
(59,20,'2026-09-12',13,'0.00','9000.00',NULL,NULL,25,1,NULL,NULL,'Trade-in Desktop PC (used)',0,NULL,'2026-10-17 00:06:39'),
(60,20,'2026-09-12',57,'0.00','450.00',NULL,NULL,NULL,1,NULL,NULL,'Technician labor (1 hour)',0,NULL,'2026-10-17 00:06:39'),
(61,20,'2026-09-12',13,'4268.82','0.00',NULL,NULL,8,1,NULL,NULL,'RAM 8GB DDR4',0,NULL,'2026-10-17 00:06:39'),
(62,20,'2026-09-12',13,'4986.18','0.00',NULL,NULL,9,1,NULL,NULL,'SSD 512GB NVMe',0,NULL,'2026-10-17 00:06:39'),
(63,20,'2026-09-12',13,'195.00','0.00',NULL,NULL,27,1,NULL,NULL,'Scrap Metal and Plastic',0,NULL,'2026-10-17 00:06:39'),
(64,21,'2026-09-22',13,'0.00','6000.00',NULL,NULL,25,1,NULL,NULL,'Trade-in Desktop PC (used)',0,NULL,'2026-10-17 00:06:39'),
(65,21,'2026-09-22',13,'0.00','4346.62',NULL,NULL,9,1,NULL,NULL,'SSD 512GB NVMe',0,NULL,'2026-10-17 00:06:39'),
(66,21,'2026-09-22',57,'0.00','800.00',NULL,NULL,NULL,1,NULL,NULL,'Refurbishing labor and testing',0,NULL,'2026-10-17 00:06:39'),
(67,21,'2026-09-22',13,'9474.63','0.00',NULL,NULL,26,1,NULL,NULL,'Refurbished Desktop PC',0,NULL,'2026-10-17 00:06:39'),
(68,21,'2026-09-22',13,'1671.99','0.00',NULL,NULL,8,1,NULL,NULL,'RAM 8GB DDR4',0,NULL,'2026-10-17 00:06:39'),
(69,22,'2026-10-02',13,'0.00','7706.67',NULL,NULL,11,2,NULL,NULL,'Office Monitor Set',0,NULL,'2026-10-17 00:06:39'),
(70,22,'2026-10-02',13,'90.00','0.00',NULL,NULL,7,2,NULL,NULL,'HDMI Cable 1.5m',0,NULL,'2026-10-17 00:06:39'),
(71,22,'2026-10-02',13,'616.67','0.00',NULL,NULL,3,2,NULL,NULL,'Keyboard USB',0,NULL,'2026-10-17 00:06:39'),
(72,22,'2026-10-02',13,'6500.00','0.00',NULL,NULL,2,2,NULL,NULL,'Monitor 24-inch IPS',0,NULL,'2026-10-17 00:06:39'),
(73,22,'2026-10-02',13,'350.00','0.00',NULL,NULL,4,2,NULL,NULL,'Wireless Mouse',0,NULL,'2026-10-17 00:06:39'),
(74,22,'2026-10-02',56,'150.00','0.00',NULL,NULL,NULL,2,NULL,NULL,'Processing variance PRC-00004',0,NULL,'2026-10-17 00:06:39'),
(75,26,'2026-08-28',44,'0.00','119970.00',1,NULL,1,1,1,NULL,'Laptop 14-inch i5 16GB',0,NULL,'2026-10-17 00:06:39'),
(76,26,'2026-08-28',33,'0.00','14396.40',1,NULL,1,1,1,NULL,'Laptop 14-inch i5 16GB',0,NULL,'2026-10-17 00:06:39'),
(77,26,'2026-08-28',54,'96000.00','0.00',1,NULL,1,1,1,NULL,'Laptop 14-inch i5 16GB',0,NULL,'2026-10-17 00:06:39'),
(78,26,'2026-08-28',13,'0.00','96000.00',1,NULL,1,1,1,NULL,'Laptop 14-inch i5 16GB',0,NULL,'2026-10-17 00:06:39'),
(79,26,'2026-08-28',44,'0.00','38970.00',1,NULL,11,1,1,NULL,'Office Monitor Set',0,NULL,'2026-10-17 00:06:39'),
(80,26,'2026-08-28',33,'0.00','4676.40',1,NULL,11,1,1,NULL,'Office Monitor Set',0,NULL,'2026-10-17 00:06:39'),
(81,26,'2026-08-28',54,'23120.00','0.00',1,NULL,11,1,1,NULL,'Office Monitor Set',0,NULL,'2026-10-17 00:06:39'),
(82,26,'2026-08-28',13,'0.00','23120.00',1,NULL,11,1,1,NULL,'Office Monitor Set',0,NULL,'2026-10-17 00:06:39'),
(83,26,'2026-08-28',45,'0.00','4500.00',1,NULL,12,1,1,NULL,'Installation and Setup',0,NULL,'2026-10-17 00:06:39'),
(84,26,'2026-08-28',33,'0.00','540.00',1,NULL,12,1,1,NULL,'Installation and Setup',0,NULL,'2026-10-17 00:06:39'),
(85,26,'2026-08-28',46,'0.00','250.00',1,NULL,16,1,1,NULL,'Delivery Fee',0,NULL,'2026-10-17 00:06:39'),
(86,26,'2026-08-28',33,'0.00','30.00',1,NULL,16,1,1,NULL,'Delivery Fee',0,NULL,'2026-10-17 00:06:39'),
(87,26,'2026-08-28',11,'183332.80','0.00',1,NULL,NULL,1,1,NULL,NULL,0,NULL,'2026-10-17 00:06:39'),
(88,27,'2026-09-02',68,'1800.00','0.00',2,6,NULL,NULL,NULL,NULL,'Freight - Office Renovation Project',0,NULL,'2026-10-17 00:06:39'),
(89,27,'2026-09-02',14,'216.00','0.00',2,6,NULL,NULL,NULL,NULL,'Freight - Office Renovation Project',0,NULL,'2026-10-17 00:06:39'),
(90,27,'2026-09-02',31,'0.00','2016.00',NULL,6,NULL,NULL,NULL,NULL,NULL,0,NULL,'2026-10-17 00:06:39'),
(91,28,'2026-09-03',71,'950.00','0.00',2,NULL,NULL,NULL,NULL,NULL,'Conduits - Office Renovation Project',0,NULL,'2026-10-17 00:06:39'),
(92,28,'2026-09-03',3,'0.00','950.00',NULL,NULL,NULL,NULL,NULL,NULL,'Cables and conduits for job',0,NULL,'2026-10-17 00:06:39'),
(93,29,'2026-09-27',45,'0.00','3000.00',2,NULL,12,1,1,NULL,'Installation and Setup',0,NULL,'2026-10-17 00:06:39'),
(94,29,'2026-09-27',33,'0.00','360.00',2,NULL,12,1,1,NULL,'Installation and Setup',0,NULL,'2026-10-17 00:06:39'),
(95,29,'2026-09-27',45,'0.00','3200.00',2,NULL,13,1,1,NULL,'Repair Service (per hour)',0,NULL,'2026-10-17 00:06:39'),
(96,29,'2026-09-27',33,'0.00','384.00',2,NULL,13,1,1,NULL,'Repair Service (per hour)',0,NULL,'2026-10-17 00:06:39'),
(97,29,'2026-09-27',11,'6944.00','0.00',2,NULL,NULL,1,1,NULL,NULL,0,NULL,'2026-10-17 00:06:39'),
(98,30,'2026-10-05',44,'0.00','79980.00',1,NULL,1,1,1,NULL,'Laptop 14-inch i5 16GB',0,NULL,'2026-10-17 00:06:39'),
(99,30,'2026-10-05',33,'0.00','9597.60',1,NULL,1,1,1,NULL,'Laptop 14-inch i5 16GB',0,NULL,'2026-10-17 00:06:39'),
(100,30,'2026-10-05',54,'64000.00','0.00',1,NULL,1,1,1,NULL,'Laptop 14-inch i5 16GB',0,NULL,'2026-10-17 00:06:39'),
(101,30,'2026-10-05',13,'0.00','64000.00',1,NULL,1,1,1,NULL,'Laptop 14-inch i5 16GB',0,NULL,'2026-10-17 00:06:39'),
(102,30,'2026-10-05',11,'89577.60','0.00',1,NULL,NULL,1,1,NULL,NULL,0,NULL,'2026-10-17 00:06:39'),
(103,31,'2026-08-30',44,'0.00','13300.00',3,NULL,5,1,1,NULL,'USB Flash Drive 32GB',0,NULL,'2026-10-17 00:06:39');
INSERT INTO `journal_lines` (`id`,`txn_id`,`txn_date`,`account_id`,`debit`,`credit`,`customer_id`,`vendor_id`,`item_id`,`site_id`,`class_id`,`other_name_id`,`memo`,`cleared`,`reconciliation_id`,`created_at`) VALUES
(104,31,'2026-08-30',33,'0.00','1596.00',3,NULL,5,1,1,NULL,'USB Flash Drive 32GB',0,NULL,'2026-10-17 00:06:39'),
(105,31,'2026-08-30',54,'7000.00','0.00',3,NULL,5,1,1,NULL,'USB Flash Drive 32GB',0,NULL,'2026-10-17 00:06:39'),
(106,31,'2026-08-30',13,'0.00','7000.00',3,NULL,5,1,1,NULL,'USB Flash Drive 32GB',0,NULL,'2026-10-17 00:06:39'),
(107,31,'2026-08-30',44,'0.00','14235.75',3,NULL,3,1,1,NULL,'Keyboard USB',0,NULL,'2026-10-17 00:06:39'),
(108,31,'2026-08-30',33,'0.00','1708.29',3,NULL,3,1,1,NULL,'Keyboard USB',0,NULL,'2026-10-17 00:06:39'),
(109,31,'2026-08-30',54,'9250.00','0.00',3,NULL,3,1,1,NULL,'Keyboard USB',0,NULL,'2026-10-17 00:06:39'),
(110,31,'2026-08-30',13,'0.00','9250.00',3,NULL,3,1,1,NULL,'Keyboard USB',0,NULL,'2026-10-17 00:06:39'),
(111,31,'2026-08-30',44,'0.00','8535.75',3,NULL,4,1,1,NULL,'Wireless Mouse',0,NULL,'2026-10-17 00:06:39'),
(112,31,'2026-08-30',33,'0.00','1024.29',3,NULL,4,1,1,NULL,'Wireless Mouse',0,NULL,'2026-10-17 00:06:39'),
(113,31,'2026-08-30',54,'5250.00','0.00',3,NULL,4,1,1,NULL,'Wireless Mouse',0,NULL,'2026-10-17 00:06:39'),
(114,31,'2026-08-30',13,'0.00','5250.00',3,NULL,4,1,1,NULL,'Wireless Mouse',0,NULL,'2026-10-17 00:06:39'),
(115,31,'2026-08-30',48,'853.58','0.00',3,NULL,19,1,1,NULL,'10% Discount',0,NULL,'2026-10-17 00:06:39'),
(116,31,'2026-08-30',33,'102.43','0.00',3,NULL,19,1,1,NULL,'10% Discount',0,NULL,'2026-10-17 00:06:39'),
(117,31,'2026-08-30',11,'39444.07','0.00',3,NULL,NULL,1,1,NULL,NULL,0,NULL,'2026-10-17 00:06:39'),
(118,32,'2026-09-12',44,'0.00','8540.50',3,NULL,6,1,1,NULL,'Laptop Backpack',0,NULL,'2026-10-17 00:06:39'),
(119,32,'2026-09-12',33,'0.00','1024.86',3,NULL,6,1,1,NULL,'Laptop Backpack',0,NULL,'2026-10-17 00:06:39'),
(120,32,'2026-09-12',54,'5000.00','0.00',3,NULL,6,1,1,NULL,'Laptop Backpack',0,NULL,'2026-10-17 00:06:39'),
(121,32,'2026-09-12',13,'0.00','5000.00',3,NULL,6,1,1,NULL,'Laptop Backpack',0,NULL,'2026-10-17 00:06:39'),
(122,32,'2026-09-12',44,'0.00','3781.00',3,NULL,7,1,1,NULL,'HDMI Cable 1.5m',0,NULL,'2026-10-17 00:06:39'),
(123,32,'2026-09-12',33,'0.00','453.72',3,NULL,7,1,1,NULL,'HDMI Cable 1.5m',0,NULL,'2026-10-17 00:06:39'),
(124,32,'2026-09-12',54,'1800.00','0.00',3,NULL,7,1,1,NULL,'HDMI Cable 1.5m',0,NULL,'2026-10-17 00:06:39'),
(125,32,'2026-09-12',13,'0.00','1800.00',3,NULL,7,1,1,NULL,'HDMI Cable 1.5m',0,NULL,'2026-10-17 00:06:39'),
(126,32,'2026-09-12',11,'13800.08','0.00',3,NULL,NULL,1,1,NULL,NULL,0,NULL,'2026-10-17 00:06:39'),
(127,33,'2026-09-17',44,'0.00','73000.00',4,NULL,1,1,1,NULL,'Laptop 14-inch i5 16GB',0,NULL,'2026-10-17 00:06:39'),
(128,33,'2026-09-17',33,'0.00','8760.00',4,NULL,1,1,1,NULL,'Laptop 14-inch i5 16GB',0,NULL,'2026-10-17 00:06:39'),
(129,33,'2026-09-17',54,'64000.00','0.00',4,NULL,1,1,1,NULL,'Laptop 14-inch i5 16GB',0,NULL,'2026-10-17 00:06:39'),
(130,33,'2026-09-17',13,'0.00','64000.00',4,NULL,1,1,1,NULL,'Laptop 14-inch i5 16GB',0,NULL,'2026-10-17 00:06:39'),
(131,33,'2026-09-17',44,'0.00','6084.00',4,NULL,8,1,1,NULL,'RAM 8GB DDR4',0,NULL,'2026-10-17 00:06:39'),
(132,33,'2026-09-17',33,'0.00','730.08',4,NULL,8,1,1,NULL,'RAM 8GB DDR4',0,NULL,'2026-10-17 00:06:39'),
(133,33,'2026-09-17',54,'3853.90','0.00',4,NULL,8,1,1,NULL,'RAM 8GB DDR4',0,NULL,'2026-10-17 00:06:39'),
(134,33,'2026-09-17',13,'0.00','3853.90',4,NULL,8,1,1,NULL,'RAM 8GB DDR4',0,NULL,'2026-10-17 00:06:39'),
(135,33,'2026-09-17',44,'0.00','5922.00',4,NULL,9,1,1,NULL,'SSD 512GB NVMe',0,NULL,'2026-10-17 00:06:39'),
(136,33,'2026-09-17',33,'0.00','710.64',4,NULL,9,1,1,NULL,'SSD 512GB NVMe',0,NULL,'2026-10-17 00:06:39'),
(137,33,'2026-09-17',54,'4346.62','0.00',4,NULL,9,1,1,NULL,'SSD 512GB NVMe',0,NULL,'2026-10-17 00:06:39'),
(138,33,'2026-09-17',13,'0.00','4346.62',4,NULL,9,1,1,NULL,'SSD 512GB NVMe',0,NULL,'2026-10-17 00:06:39'),
(139,33,'2026-09-17',45,'0.00','1350.00',4,NULL,12,1,1,NULL,'Installation and Setup',0,NULL,'2026-10-17 00:06:39'),
(140,33,'2026-09-17',33,'0.00','162.00',4,NULL,12,1,1,NULL,'Installation and Setup',0,NULL,'2026-10-17 00:06:39'),
(141,33,'2026-09-17',11,'96718.72','0.00',4,NULL,NULL,1,1,NULL,NULL,0,NULL,'2026-10-17 00:06:39'),
(142,34,'2026-08-03',45,'0.00','5000.00',6,NULL,14,1,1,NULL,'Monthly IT Maintenance',0,NULL,'2026-10-17 00:06:39'),
(143,34,'2026-08-03',33,'0.00','600.00',6,NULL,14,1,1,NULL,'Monthly IT Maintenance',0,NULL,'2026-10-17 00:06:39'),
(144,34,'2026-08-03',44,'0.00','6400.00',6,NULL,15,1,1,NULL,'Toner Cartridge (special order)',0,NULL,'2026-10-17 00:06:39'),
(145,34,'2026-08-03',33,'0.00','768.00',6,NULL,15,1,1,NULL,'Toner Cartridge (special order)',0,NULL,'2026-10-17 00:06:39'),
(146,34,'2026-08-03',11,'12768.00','0.00',6,NULL,NULL,1,1,NULL,NULL,0,NULL,'2026-10-17 00:06:39'),
(147,35,'2026-08-16',45,'0.00','5000.00',5,NULL,14,1,1,NULL,'Monthly IT Maintenance',0,NULL,'2026-10-17 00:06:39'),
(148,35,'2026-08-16',33,'0.00','600.00',5,NULL,14,1,1,NULL,'Monthly IT Maintenance',0,NULL,'2026-10-17 00:06:39'),
(149,35,'2026-08-16',11,'5600.00','0.00',5,NULL,NULL,1,1,NULL,'Monthly IT maintenance',0,NULL,'2026-10-17 00:06:39'),
(150,36,'2026-08-16',45,'0.00','5000.00',6,NULL,14,1,1,NULL,'Monthly IT Maintenance',0,NULL,'2026-10-17 00:06:39'),
(151,36,'2026-08-16',33,'0.00','600.00',6,NULL,14,1,1,NULL,'Monthly IT Maintenance',0,NULL,'2026-10-17 00:06:39'),
(152,36,'2026-08-16',11,'5600.00','0.00',6,NULL,NULL,1,1,NULL,'Monthly IT maintenance',0,NULL,'2026-10-17 00:06:39'),
(153,37,'2026-09-16',45,'0.00','5000.00',5,NULL,14,1,1,NULL,'Monthly IT Maintenance',0,NULL,'2026-10-17 00:06:39'),
(154,37,'2026-09-16',33,'0.00','600.00',5,NULL,14,1,1,NULL,'Monthly IT Maintenance',0,NULL,'2026-10-17 00:06:39'),
(155,37,'2026-09-16',11,'5600.00','0.00',5,NULL,NULL,1,1,NULL,'Monthly IT maintenance',0,NULL,'2026-10-17 00:06:39'),
(156,38,'2026-09-16',45,'0.00','5000.00',6,NULL,14,1,1,NULL,'Monthly IT Maintenance',0,NULL,'2026-10-17 00:06:39'),
(157,38,'2026-09-16',33,'0.00','600.00',6,NULL,14,1,1,NULL,'Monthly IT Maintenance',0,NULL,'2026-10-17 00:06:39'),
(158,38,'2026-09-16',11,'5600.00','0.00',6,NULL,NULL,1,1,NULL,'Monthly IT maintenance',0,NULL,'2026-10-17 00:06:39'),
(159,40,'2026-09-07',44,'0.00','39990.00',8,NULL,1,1,NULL,NULL,'Laptop 14-inch i5 16GB',0,NULL,'2026-10-17 00:06:39'),
(160,40,'2026-09-07',33,'0.00','4798.80',8,NULL,1,1,NULL,NULL,'Laptop 14-inch i5 16GB',0,NULL,'2026-10-17 00:06:39'),
(161,40,'2026-09-07',54,'32000.00','0.00',8,NULL,1,1,NULL,NULL,'Laptop 14-inch i5 16GB',0,NULL,'2026-10-17 00:06:39'),
(162,40,'2026-09-07',13,'0.00','32000.00',8,NULL,1,1,NULL,NULL,'Laptop 14-inch i5 16GB',0,NULL,'2026-10-17 00:06:39'),
(163,40,'2026-09-07',44,'0.00','899.00',8,NULL,6,1,NULL,NULL,'Laptop Backpack',0,NULL,'2026-10-17 00:06:39'),
(164,40,'2026-09-07',33,'0.00','107.88',8,NULL,6,1,NULL,NULL,'Laptop Backpack',0,NULL,'2026-10-17 00:06:39'),
(165,40,'2026-09-07',54,'500.00','0.00',8,NULL,6,1,NULL,NULL,'Laptop Backpack',0,NULL,'2026-10-17 00:06:39'),
(166,40,'2026-09-07',13,'0.00','500.00',8,NULL,6,1,NULL,NULL,'Laptop Backpack',0,NULL,'2026-10-17 00:06:39'),
(167,40,'2026-09-07',44,'0.00','599.00',8,NULL,4,1,NULL,NULL,'Wireless Mouse',0,NULL,'2026-10-17 00:06:39'),
(168,40,'2026-09-07',33,'0.00','71.88',8,NULL,4,1,NULL,NULL,'Wireless Mouse',0,NULL,'2026-10-17 00:06:39'),
(169,40,'2026-09-07',54,'350.00','0.00',8,NULL,4,1,NULL,NULL,'Wireless Mouse',0,NULL,'2026-10-17 00:06:39'),
(170,40,'2026-09-07',13,'0.00','350.00',8,NULL,4,1,NULL,NULL,'Wireless Mouse',0,NULL,'2026-10-17 00:06:39'),
(171,40,'2026-09-07',7,'46466.56','0.00',8,NULL,NULL,1,NULL,NULL,'Phone order',0,NULL,'2026-10-17 00:06:39'),
(172,41,'2026-09-27',44,'0.00','31500.00',3,NULL,3,1,1,NULL,'Keyboard USB (sold by the dozen)',0,NULL,'2026-10-17 00:06:39'),
(173,41,'2026-09-27',33,'0.00','3780.00',3,NULL,3,1,1,NULL,'Keyboard USB (sold by the dozen)',0,NULL,'2026-10-17 00:06:39'),
(174,41,'2026-09-27',54,'22200.00','0.00',3,NULL,3,1,1,NULL,'Keyboard USB (sold by the dozen)',0,NULL,'2026-10-17 00:06:39'),
(175,41,'2026-09-27',13,'0.00','22200.00',3,NULL,3,1,1,NULL,'Keyboard USB (sold by the dozen)',0,NULL,'2026-10-17 00:06:39'),
(176,41,'2026-09-27',11,'35280.00','0.00',3,NULL,NULL,1,1,NULL,'3 dozen keyboards, 1,500.00 off',0,NULL,'2026-10-17 00:06:39'),
(177,42,'2026-09-22',7,'100000.00','0.00',1,NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,'2026-10-17 00:06:39'),
(178,42,'2026-09-22',15,'1500.00','0.00',1,NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,'2026-10-17 00:06:39'),
(179,42,'2026-09-22',11,'0.00','101500.00',1,NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,'2026-10-17 00:06:39'),
(180,43,'2026-09-25',5,'94784.35','0.00',4,NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,'2026-10-17 00:06:39'),
(181,43,'2026-09-25',48,'1934.37','0.00',4,NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,'2026-10-17 00:06:39'),
(182,43,'2026-09-25',11,'0.00','96718.72',4,NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,'2026-10-17 00:06:39'),
(183,44,'2026-09-19',7,'39944.07','0.00',3,NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,'2026-10-17 00:06:39'),
(184,44,'2026-09-19',11,'0.00','39944.07',3,NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,'2026-10-17 00:06:39'),
(185,45,'2026-08-18',7,'6384.00','0.00',6,NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,'2026-10-17 00:06:39'),
(186,45,'2026-08-18',11,'0.00','6384.00',6,NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,'2026-10-17 00:06:39'),
(187,46,'2026-09-13',44,'0.00','89900.00',7,NULL,2,1,1,NULL,'Monitor 24-inch IPS',0,NULL,'2026-10-17 00:06:39'),
(188,46,'2026-09-13',33,'0.00','10788.00',7,NULL,2,1,1,NULL,'Monitor 24-inch IPS',0,NULL,'2026-10-17 00:06:39'),
(189,46,'2026-09-13',54,'65000.00','0.00',7,NULL,2,1,1,NULL,'Monitor 24-inch IPS',0,NULL,'2026-10-17 00:06:39'),
(190,46,'2026-09-13',13,'0.00','65000.00',7,NULL,2,1,1,NULL,'Monitor 24-inch IPS',0,NULL,'2026-10-17 00:06:39'),
(191,46,'2026-09-13',11,'100688.00','0.00',7,NULL,NULL,1,1,NULL,'Monitors for the city hall offices',0,NULL,'2026-10-17 00:06:39'),
(192,47,'2026-10-05',7,'95294.00','0.00',7,NULL,NULL,NULL,NULL,NULL,'5% VAT and 1% withheld; BIR Form 2307 to follow',0,NULL,'2026-10-17 00:06:39'),
(193,47,'2026-10-05',15,'899.00','0.00',7,NULL,NULL,NULL,NULL,NULL,'5% VAT and 1% withheld; BIR Form 2307 to follow',0,NULL,'2026-10-17 00:06:39'),
(194,47,'2026-10-05',16,'4495.00','0.00',7,NULL,NULL,NULL,NULL,NULL,'5% VAT and 1% withheld; BIR Form 2307 to follow',0,NULL,'2026-10-17 00:06:39'),
(195,47,'2026-10-05',11,'0.00','100688.00',7,NULL,NULL,NULL,NULL,NULL,'5% VAT and 1% withheld; BIR Form 2307 to follow',0,NULL,'2026-10-17 00:06:39'),
(196,48,'2026-09-20',47,'1898.10','0.00',3,NULL,3,1,NULL,NULL,'Keyboard USB',0,NULL,'2026-10-17 00:06:39'),
(197,48,'2026-09-20',33,'227.77','0.00',3,NULL,3,1,NULL,NULL,'Keyboard USB',0,NULL,'2026-10-17 00:06:39'),
(198,48,'2026-09-20',13,'1233.33','0.00',3,NULL,3,1,NULL,NULL,'Keyboard USB',0,NULL,'2026-10-17 00:06:39'),
(199,48,'2026-09-20',54,'0.00','1233.33',3,NULL,3,1,NULL,NULL,'Keyboard USB',0,NULL,'2026-10-17 00:06:39'),
(200,48,'2026-09-20',11,'0.00','2125.87',3,NULL,NULL,1,NULL,NULL,'Returned 2 defective keyboards',0,NULL,'2026-10-17 00:06:39'),
(201,49,'2026-10-02',51,'0.00','200.00',6,NULL,18,NULL,NULL,NULL,'Late Payment Fee',0,NULL,'2026-10-17 00:06:39'),
(202,49,'2026-10-02',11,'200.00','0.00',6,NULL,NULL,NULL,NULL,NULL,'Late payment fee',0,NULL,'2026-10-17 00:06:39'),
(203,50,'2026-10-16',51,'0.00','120.50',6,NULL,NULL,NULL,NULL,NULL,'Finance charge (12% p.a.)',0,NULL,'2026-10-17 00:06:39');
INSERT INTO `journal_lines` (`id`,`txn_id`,`txn_date`,`account_id`,`debit`,`credit`,`customer_id`,`vendor_id`,`item_id`,`site_id`,`class_id`,`other_name_id`,`memo`,`cleared`,`reconciliation_id`,`created_at`) VALUES
(204,50,'2026-10-16',11,'120.50','0.00',6,NULL,NULL,NULL,NULL,NULL,'Finance charge on overdue balance',0,NULL,'2026-10-17 00:06:39'),
(205,51,'2026-08-04',59,'85000.00','0.00',NULL,4,NULL,NULL,NULL,NULL,'Monthly rent',0,NULL,'2026-10-17 00:06:39'),
(206,51,'2026-08-04',5,'0.00','85000.00',NULL,4,NULL,NULL,NULL,NULL,'Office and warehouse rent',1,1,'2026-10-17 00:06:39'),
(207,52,'2026-09-03',59,'85000.00','0.00',NULL,4,NULL,NULL,NULL,NULL,'Monthly rent',0,NULL,'2026-10-17 00:06:39'),
(208,52,'2026-09-03',5,'0.00','85000.00',NULL,4,NULL,NULL,NULL,NULL,'Office and warehouse rent',0,NULL,'2026-10-17 00:06:39'),
(209,53,'2026-10-03',59,'85000.00','0.00',NULL,4,NULL,NULL,NULL,NULL,'Monthly rent',0,NULL,'2026-10-17 00:06:39'),
(210,53,'2026-10-03',5,'0.00','85000.00',NULL,4,NULL,NULL,NULL,NULL,'Office and warehouse rent',0,NULL,'2026-10-17 00:06:39'),
(211,54,'2026-08-18',60,'18450.75','0.00',NULL,3,NULL,NULL,NULL,NULL,'Electricity',0,NULL,'2026-10-17 00:06:39'),
(212,54,'2026-08-18',14,'2214.09','0.00',NULL,3,NULL,NULL,NULL,NULL,'Electricity',0,NULL,'2026-10-17 00:06:39'),
(213,54,'2026-08-18',31,'0.00','20664.84',NULL,3,NULL,NULL,NULL,NULL,NULL,0,NULL,'2026-10-17 00:06:39'),
(214,55,'2026-09-17',60,'21230.40','0.00',NULL,3,NULL,NULL,NULL,NULL,'Electricity',0,NULL,'2026-10-17 00:06:39'),
(215,55,'2026-09-17',14,'2547.65','0.00',NULL,3,NULL,NULL,NULL,NULL,'Electricity',0,NULL,'2026-10-17 00:06:39'),
(216,55,'2026-09-17',31,'0.00','23778.05',NULL,3,NULL,NULL,NULL,NULL,NULL,0,NULL,'2026-10-17 00:06:39'),
(217,56,'2026-08-23',65,'45000.00','0.00',NULL,7,NULL,NULL,NULL,NULL,'Professional fees',0,NULL,'2026-10-17 00:06:39'),
(218,56,'2026-08-23',14,'5400.00','0.00',NULL,7,NULL,NULL,NULL,NULL,'Professional fees',0,NULL,'2026-10-17 00:06:39'),
(219,56,'2026-08-23',31,'0.00','50400.00',NULL,7,NULL,NULL,NULL,NULL,'Quarterly bookkeeping review',0,NULL,'2026-10-17 00:06:39'),
(220,57,'2026-09-14',63,'3500.00','0.00',NULL,5,NULL,NULL,NULL,NULL,'Diesel',0,NULL,'2026-10-17 00:06:39'),
(221,57,'2026-09-14',14,'420.00','0.00',NULL,5,NULL,NULL,NULL,NULL,'Diesel',0,NULL,'2026-10-17 00:06:39'),
(222,57,'2026-09-14',3,'0.00','3920.00',NULL,5,NULL,NULL,NULL,NULL,'Fuel for delivery van',0,NULL,'2026-10-17 00:06:39'),
(223,58,'2026-09-01',13,'0.00','700.00',NULL,1,4,1,NULL,NULL,'Wireless Mouse',0,NULL,'2026-10-17 00:06:39'),
(224,58,'2026-09-01',14,'0.00','84.00',NULL,1,4,1,NULL,NULL,'Wireless Mouse',0,NULL,'2026-10-17 00:06:39'),
(225,58,'2026-09-01',31,'784.00','0.00',NULL,1,NULL,1,NULL,NULL,'Returned damaged mice',0,NULL,'2026-10-17 00:06:39'),
(226,59,'2026-09-07',31,'1127280.00','0.00',NULL,1,NULL,NULL,NULL,NULL,'Payment of TD-INV-10231',0,NULL,'2026-10-17 00:06:39'),
(227,59,'2026-09-07',5,'0.00','1127280.00',NULL,1,NULL,NULL,NULL,NULL,'Payment of TD-INV-10231',0,NULL,'2026-10-17 00:06:39'),
(228,60,'2026-08-26',31,'20664.84','0.00',NULL,3,NULL,NULL,NULL,NULL,'Electricity',0,NULL,'2026-10-17 00:06:39'),
(229,60,'2026-08-26',5,'0.00','20664.84',NULL,3,NULL,NULL,NULL,NULL,'Electricity',1,1,'2026-10-17 00:06:39'),
(230,61,'2026-09-27',31,'50400.00','0.00',NULL,7,NULL,NULL,NULL,NULL,'Payment of APC-2231, 2% withheld',0,NULL,'2026-10-17 00:06:39'),
(231,61,'2026-09-27',5,'0.00','49500.00',NULL,7,NULL,NULL,NULL,NULL,'Payment of APC-2231, 2% withheld',0,NULL,'2026-10-17 00:06:39'),
(232,61,'2026-09-27',34,'0.00','900.00',NULL,7,NULL,NULL,NULL,NULL,'Payment of APC-2231, 2% withheld',0,NULL,'2026-10-17 00:06:39'),
(233,62,'2026-10-03',18,'150000.00','0.00',NULL,8,NULL,NULL,NULL,NULL,'30% down payment on the packaging machine',0,NULL,'2026-10-17 00:06:39'),
(234,62,'2026-10-03',5,'0.00','150000.00',NULL,8,NULL,NULL,NULL,NULL,'30% down payment on the packaging machine',0,NULL,'2026-10-17 00:06:39'),
(237,65,'2026-09-23',13,'0.00','1000.00',NULL,NULL,6,1,NULL,NULL,'Damage',0,NULL,'2026-10-17 00:06:39'),
(238,65,'2026-09-23',56,'1000.00','0.00',NULL,NULL,6,1,NULL,NULL,'Damage',0,NULL,'2026-10-17 00:06:39'),
(239,66,'2026-10-09',13,'0.00','175.00',NULL,NULL,5,2,NULL,NULL,'Count difference (counted 29, system 30)',0,NULL,'2026-10-17 00:06:39'),
(240,66,'2026-10-09',56,'175.00','0.00',NULL,NULL,5,2,NULL,NULL,'Count difference (counted 29, system 30)',0,NULL,'2026-10-17 00:06:39'),
(241,66,'2026-10-09',13,'90.00','0.00',NULL,NULL,7,2,NULL,NULL,'Count difference (counted 16, system 15)',0,NULL,'2026-10-17 00:06:39'),
(242,66,'2026-10-09',56,'0.00','90.00',NULL,NULL,7,2,NULL,NULL,'Count difference (counted 16, system 15)',0,NULL,'2026-10-17 00:06:39'),
(243,67,'2026-09-02',3,'10000.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,'Replenish petty cash',0,NULL,'2026-10-17 00:06:39'),
(244,67,'2026-09-02',5,'0.00','10000.00',NULL,NULL,NULL,NULL,NULL,NULL,'Replenish petty cash',0,NULL,'2026-10-17 00:06:39'),
(245,68,'2026-09-17',62,'1250.00','0.00',NULL,NULL,NULL,NULL,1,2,'Packing supplies',0,NULL,'2026-10-17 00:06:39'),
(246,68,'2026-09-17',3,'0.00','1250.00',NULL,NULL,NULL,NULL,1,2,'Packing tape and markers for the warehouse',0,NULL,'2026-10-17 00:06:39'),
(247,69,'2026-10-05',68,'480.00','0.00',NULL,NULL,NULL,NULL,2,NULL,'Fares for small deliveries',0,NULL,'2026-10-17 00:06:39'),
(248,69,'2026-10-05',3,'0.00','480.00',NULL,NULL,NULL,NULL,2,NULL,'Delivery fares, Makati store',0,NULL,'2026-10-17 00:06:39'),
(249,70,'2026-09-23',7,'0.00','6384.00',6,NULL,NULL,NULL,NULL,NULL,'Customer Payment PMT-00004',0,NULL,'2026-10-17 00:06:39'),
(250,70,'2026-09-23',7,'0.00','39944.07',3,NULL,NULL,NULL,NULL,NULL,'Customer Payment PMT-00003',0,NULL,'2026-10-17 00:06:39'),
(251,70,'2026-09-23',7,'0.00','100000.00',1,NULL,NULL,NULL,NULL,NULL,'Customer Payment PMT-00001',0,NULL,'2026-10-17 00:06:39'),
(252,70,'2026-09-23',7,'0.00','46466.56',8,NULL,NULL,NULL,NULL,NULL,'Sales Receipt SR-00001',0,NULL,'2026-10-17 00:06:39'),
(253,70,'2026-09-23',52,'0.00','1250.00',NULL,NULL,NULL,NULL,NULL,NULL,'Interest on time deposit',0,NULL,'2026-10-17 00:06:39'),
(254,70,'2026-09-23',5,'194044.63','0.00',NULL,NULL,NULL,NULL,NULL,NULL,'Deposit',0,NULL,'2026-10-17 00:06:39'),
(255,71,'2026-08-31',67,'2500.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,'Depreciation - Computer and POS Equipment',0,NULL,'2026-10-17 00:06:39'),
(256,71,'2026-08-31',29,'0.00','2500.00',NULL,NULL,NULL,NULL,NULL,NULL,'Accumulated depreciation - Computer and POS Equipment',0,NULL,'2026-10-17 00:06:39'),
(257,71,'2026-08-31',67,'13800.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,'Depreciation - Production Machinery (usage-based)',0,NULL,'2026-10-17 00:06:39'),
(258,71,'2026-08-31',23,'0.00','13800.00',NULL,NULL,NULL,NULL,NULL,NULL,'Accumulated depreciation - Production Machinery (usage-based)',0,NULL,'2026-10-17 00:06:39'),
(259,71,'2026-08-31',67,'40000.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,'Depreciation - Transportation Equipment',0,NULL,'2026-10-17 00:06:39'),
(260,71,'2026-08-31',25,'0.00','40000.00',NULL,NULL,NULL,NULL,NULL,NULL,'Accumulated depreciation - Transportation Equipment',0,NULL,'2026-10-17 00:06:39'),
(261,72,'2026-09-30',67,'2500.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,'Depreciation - Computer and POS Equipment',0,NULL,'2026-10-17 00:06:39'),
(262,72,'2026-09-30',29,'0.00','2500.00',NULL,NULL,NULL,NULL,NULL,NULL,'Accumulated depreciation - Computer and POS Equipment',0,NULL,'2026-10-17 00:06:39'),
(263,72,'2026-09-30',67,'15150.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,'Depreciation - Production Machinery (usage-based)',0,NULL,'2026-10-17 00:06:39'),
(264,72,'2026-09-30',23,'0.00','15150.00',NULL,NULL,NULL,NULL,NULL,NULL,'Accumulated depreciation - Production Machinery (usage-based)',0,NULL,'2026-10-17 00:06:39'),
(265,72,'2026-09-30',67,'40000.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,'Depreciation - Transportation Equipment',0,NULL,'2026-10-17 00:06:39'),
(266,72,'2026-09-30',25,'0.00','40000.00',NULL,NULL,NULL,NULL,NULL,NULL,'Accumulated depreciation - Transportation Equipment',0,NULL,'2026-10-17 00:06:39'),
(267,73,'2026-08-31',66,'150.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,'Service charge',0,NULL,'2026-10-17 00:06:39'),
(268,73,'2026-08-31',5,'0.00','150.00',NULL,NULL,NULL,NULL,NULL,NULL,'Service charge',1,1,'2026-10-17 00:06:39'),
(269,74,'2026-10-16',44,'0.00','1198.00',NULL,NULL,4,2,2,NULL,'Wireless Mouse',0,NULL,'2026-10-17 00:06:39'),
(270,74,'2026-10-16',33,'0.00','143.76',NULL,NULL,4,2,2,NULL,'Wireless Mouse',0,NULL,'2026-10-17 00:06:39'),
(271,74,'2026-10-16',54,'700.00','0.00',NULL,NULL,4,2,2,NULL,'Wireless Mouse',0,NULL,'2026-10-17 00:06:39'),
(272,74,'2026-10-16',13,'0.00','700.00',NULL,NULL,4,2,2,NULL,'Wireless Mouse',0,NULL,'2026-10-17 00:06:39'),
(273,74,'2026-10-16',44,'0.00','1050.00',NULL,NULL,5,2,2,NULL,'USB Flash Drive 32GB',0,NULL,'2026-10-17 00:06:39'),
(274,74,'2026-10-16',33,'0.00','126.00',NULL,NULL,5,2,2,NULL,'USB Flash Drive 32GB',0,NULL,'2026-10-17 00:06:40'),
(275,74,'2026-10-16',54,'525.00','0.00',NULL,NULL,5,2,2,NULL,'USB Flash Drive 32GB',0,NULL,'2026-10-17 00:06:40'),
(276,74,'2026-10-16',13,'0.00','525.00',NULL,NULL,5,2,2,NULL,'USB Flash Drive 32GB',0,NULL,'2026-10-17 00:06:40'),
(277,74,'2026-10-16',2,'2517.76','0.00',NULL,NULL,NULL,2,2,NULL,NULL,0,NULL,'2026-10-17 00:06:40'),
(278,75,'2026-10-16',44,'0.00','37990.50',NULL,NULL,1,2,2,NULL,'Laptop 14-inch i5 16GB',0,NULL,'2026-10-17 00:06:40'),
(279,75,'2026-10-16',33,'0.00','4558.86',NULL,NULL,1,2,2,NULL,'Laptop 14-inch i5 16GB',0,NULL,'2026-10-17 00:06:40'),
(280,75,'2026-10-16',54,'32000.00','0.00',NULL,NULL,1,2,2,NULL,'Laptop 14-inch i5 16GB',0,NULL,'2026-10-17 00:06:40'),
(281,75,'2026-10-16',13,'0.00','32000.00',NULL,NULL,1,2,2,NULL,'Laptop 14-inch i5 16GB',0,NULL,'2026-10-17 00:06:40'),
(282,75,'2026-10-16',44,'0.00','899.00',NULL,NULL,6,2,2,NULL,'Laptop Backpack',0,NULL,'2026-10-17 00:06:40'),
(283,75,'2026-10-16',33,'0.00','107.88',NULL,NULL,6,2,2,NULL,'Laptop Backpack',0,NULL,'2026-10-17 00:06:40'),
(284,75,'2026-10-16',54,'500.00','0.00',NULL,NULL,6,2,2,NULL,'Laptop Backpack',0,NULL,'2026-10-17 00:06:40'),
(285,75,'2026-10-16',13,'0.00','500.00',NULL,NULL,6,2,2,NULL,'Laptop Backpack',0,NULL,'2026-10-17 00:06:40'),
(286,75,'2026-10-16',8,'43556.24','0.00',NULL,NULL,NULL,2,2,NULL,NULL,0,NULL,'2026-10-17 00:06:40'),
(287,76,'2026-10-16',44,'0.00','999.00',NULL,NULL,3,2,2,NULL,'Keyboard USB',0,NULL,'2026-10-17 00:06:40'),
(288,76,'2026-10-16',33,'0.00','119.88',NULL,NULL,3,2,2,NULL,'Keyboard USB',0,NULL,'2026-10-17 00:06:40'),
(289,76,'2026-10-16',54,'616.67','0.00',NULL,NULL,3,2,2,NULL,'Keyboard USB',0,NULL,'2026-10-17 00:06:40'),
(290,76,'2026-10-16',13,'0.00','616.67',NULL,NULL,3,2,2,NULL,'Keyboard USB',0,NULL,'2026-10-17 00:06:40'),
(291,76,'2026-10-16',44,'0.00','398.00',NULL,NULL,7,2,2,NULL,'HDMI Cable 1.5m',0,NULL,'2026-10-17 00:06:40'),
(292,76,'2026-10-16',33,'0.00','47.76',NULL,NULL,7,2,2,NULL,'HDMI Cable 1.5m',0,NULL,'2026-10-17 00:06:40'),
(293,76,'2026-10-16',54,'180.00','0.00',NULL,NULL,7,2,2,NULL,'HDMI Cable 1.5m',0,NULL,'2026-10-17 00:06:40'),
(294,76,'2026-10-16',13,'0.00','180.00',NULL,NULL,7,2,2,NULL,'HDMI Cable 1.5m',0,NULL,'2026-10-17 00:06:40'),
(295,76,'2026-10-16',9,'1564.64','0.00',NULL,NULL,NULL,2,2,NULL,NULL,0,NULL,'2026-10-17 00:06:40'),
(301,78,'2026-10-16',44,'0.00','700.00',NULL,NULL,5,2,2,NULL,'USB Flash Drive 32GB',0,NULL,'2026-10-17 00:06:40'),
(302,78,'2026-10-16',33,'0.00','84.00',NULL,NULL,5,2,2,NULL,'USB Flash Drive 32GB',0,NULL,'2026-10-17 00:06:40'),
(303,78,'2026-10-16',54,'350.00','0.00',NULL,NULL,5,2,2,NULL,'USB Flash Drive 32GB',0,NULL,'2026-10-17 00:06:40'),
(304,78,'2026-10-16',13,'0.00','350.00',NULL,NULL,5,2,2,NULL,'USB Flash Drive 32GB',0,NULL,'2026-10-17 00:06:40'),
(305,78,'2026-10-16',2,'784.00','0.00',NULL,NULL,NULL,2,2,NULL,NULL,0,NULL,'2026-10-17 00:06:40'),
(306,79,'2026-10-16',47,'599.00','0.00',NULL,NULL,4,2,NULL,NULL,'Wireless Mouse',0,NULL,'2026-10-17 00:06:40'),
(307,79,'2026-10-16',33,'71.88','0.00',NULL,NULL,4,2,NULL,NULL,'Wireless Mouse',0,NULL,'2026-10-17 00:06:40'),
(308,79,'2026-10-16',13,'350.00','0.00',NULL,NULL,4,2,NULL,NULL,'Wireless Mouse',0,NULL,'2026-10-17 00:06:40'),
(309,79,'2026-10-16',54,'0.00','350.00',NULL,NULL,4,2,NULL,NULL,'Wireless Mouse',0,NULL,'2026-10-17 00:06:40'),
(310,79,'2026-10-16',2,'0.00','670.88',NULL,NULL,NULL,2,NULL,NULL,'Return: defective mouse',0,NULL,'2026-10-17 00:06:40');
INSERT INTO `journal_lines` (`id`,`txn_id`,`txn_date`,`account_id`,`debit`,`credit`,`customer_id`,`vendor_id`,`item_id`,`site_id`,`class_id`,`other_name_id`,`memo`,`cleared`,`reconciliation_id`,`created_at`) VALUES
(311,80,'2026-10-16',2,'0.00','20.00',NULL,NULL,NULL,NULL,NULL,NULL,'Drawer count difference',0,NULL,'2026-10-17 00:06:40'),
(312,80,'2026-10-16',70,'20.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,'Cash over and short',0,NULL,'2026-10-17 00:06:40'),
(313,81,'2026-10-17',44,'0.00','350.00',NULL,NULL,5,2,2,NULL,'USB Flash Drive 32GB',0,NULL,'2026-10-17 00:06:40'),
(314,81,'2026-10-17',33,'0.00','42.00',NULL,NULL,5,2,2,NULL,'USB Flash Drive 32GB',0,NULL,'2026-10-17 00:06:40'),
(315,81,'2026-10-17',54,'175.00','0.00',NULL,NULL,5,2,2,NULL,'USB Flash Drive 32GB',0,NULL,'2026-10-17 00:06:40'),
(316,81,'2026-10-17',13,'0.00','175.00',NULL,NULL,5,2,2,NULL,'USB Flash Drive 32GB',0,NULL,'2026-10-17 00:06:40'),
(317,81,'2026-10-17',44,'0.00','199.00',NULL,NULL,7,2,2,NULL,'HDMI Cable 1.5m',0,NULL,'2026-10-17 00:06:40'),
(318,81,'2026-10-17',33,'0.00','23.88',NULL,NULL,7,2,2,NULL,'HDMI Cable 1.5m',0,NULL,'2026-10-17 00:06:40'),
(319,81,'2026-10-17',54,'90.00','0.00',NULL,NULL,7,2,2,NULL,'HDMI Cable 1.5m',0,NULL,'2026-10-17 00:06:40'),
(320,81,'2026-10-17',13,'0.00','90.00',NULL,NULL,7,2,2,NULL,'HDMI Cable 1.5m',0,NULL,'2026-10-17 00:06:40'),
(321,81,'2026-10-17',2,'614.88','0.00',NULL,NULL,NULL,2,2,NULL,NULL,0,NULL,'2026-10-17 00:06:40'),
(322,82,'2026-10-17',44,'0.00','12990.00',NULL,NULL,11,2,2,NULL,'Office Monitor Set',0,NULL,'2026-10-17 00:06:40'),
(323,82,'2026-10-17',33,'0.00','1558.80',NULL,NULL,11,2,2,NULL,'Office Monitor Set',0,NULL,'2026-10-17 00:06:40'),
(324,82,'2026-10-17',54,'7706.66','0.00',NULL,NULL,11,2,2,NULL,'Office Monitor Set',0,NULL,'2026-10-17 00:06:40'),
(325,82,'2026-10-17',13,'0.00','7706.66',NULL,NULL,11,2,2,NULL,'Office Monitor Set',0,NULL,'2026-10-17 00:06:40'),
(326,82,'2026-10-17',9,'14548.80','0.00',NULL,NULL,NULL,2,2,NULL,NULL,0,NULL,'2026-10-17 00:06:40');

-- inventory_movements (95 rows)
INSERT INTO `inventory_movements` (`id`,`txn_id`,`txn_line_id`,`txn_date`,`item_id`,`site_id`,`qty`,`unit_cost`,`total_cost`,`qty_after`,`avg_after`,`created_at`) VALUES
(1,8,21,'2026-08-06',1,1,'20.0000','32000.0000','640000.00','20.0000','32000.0000','2026-10-17 00:06:39'),
(2,8,22,'2026-08-06',2,1,'40.0000','6500.0000','260000.00','40.0000','6500.0000','2026-10-17 00:06:39'),
(3,8,23,'2026-08-06',3,1,'60.0000','650.0000','39000.00','60.0000','650.0000','2026-10-17 00:06:39'),
(4,8,24,'2026-08-06',4,1,'80.0000','350.0000','28000.00','80.0000','350.0000','2026-10-17 00:06:39'),
(5,8,25,'2026-08-06',5,1,'100.0000','180.0000','18000.00','100.0000','180.0000','2026-10-17 00:06:39'),
(6,8,26,'2026-08-06',6,1,'30.0000','500.0000','15000.00','30.0000','500.0000','2026-10-17 00:06:39'),
(7,8,27,'2026-08-06',7,1,'80.0000','90.0000','7200.00','80.0000','90.0000','2026-10-17 00:06:39'),
(10,9,28,'2026-08-12',8,1,'20.0000','1100.0000','22000.00','20.0000','1100.0000','2026-10-17 00:06:39'),
(11,9,29,'2026-08-12',9,1,'20.0000','2250.0000','45000.00','20.0000','2250.0000','2026-10-17 00:06:39'),
(12,12,33,'2026-09-09',3,1,'120.0000','600.0000','72000.00','180.0000','616.6667','2026-10-17 00:06:39'),
(13,13,34,'2026-08-14',1,1,'-4.0000','32000.0000','-128000.00','16.0000','32000.0000','2026-10-17 00:06:39'),
(14,13,34,'2026-08-14',1,2,'4.0000','32000.0000','128000.00','20.0000','32000.0000','2026-10-17 00:06:39'),
(15,13,35,'2026-08-14',2,1,'-6.0000','6500.0000','-39000.00','34.0000','6500.0000','2026-10-17 00:06:39'),
(16,13,35,'2026-08-14',2,2,'6.0000','6500.0000','39000.00','40.0000','6500.0000','2026-10-17 00:06:39'),
(17,13,36,'2026-08-14',3,1,'-10.0000','616.6667','-6166.67','170.0000','616.6666','2026-10-17 00:06:39'),
(18,13,36,'2026-08-14',3,2,'10.0000','616.6670','6166.67','180.0000','616.6667','2026-10-17 00:06:39'),
(19,13,37,'2026-08-14',4,1,'-20.0000','350.0000','-7000.00','60.0000','350.0000','2026-10-17 00:06:39'),
(20,13,37,'2026-08-14',4,2,'20.0000','350.0000','7000.00','80.0000','350.0000','2026-10-17 00:06:39'),
(21,13,38,'2026-08-14',5,1,'-30.0000','180.0000','-5400.00','70.0000','180.0000','2026-10-17 00:06:39'),
(22,13,38,'2026-08-14',5,2,'30.0000','180.0000','5400.00','100.0000','180.0000','2026-10-17 00:06:39'),
(23,13,39,'2026-08-14',6,1,'-8.0000','500.0000','-4000.00','22.0000','500.0000','2026-10-17 00:06:39'),
(24,13,39,'2026-08-14',6,2,'8.0000','500.0000','4000.00','30.0000','500.0000','2026-10-17 00:06:39'),
(25,13,40,'2026-08-14',7,1,'-15.0000','90.0000','-1350.00','65.0000','90.0000','2026-10-17 00:06:39'),
(26,13,40,'2026-08-14',7,2,'15.0000','90.0000','1350.00','80.0000','90.0000','2026-10-17 00:06:39'),
(27,14,41,'2026-08-15',1,1,'-4.0000','32000.0000','-128000.00','16.0000','32000.0000','2026-10-17 00:06:39'),
(28,14,41,'2026-08-15',1,3,'4.0000','32000.0000','128000.00','20.0000','32000.0000','2026-10-17 00:06:39'),
(29,14,42,'2026-08-15',2,1,'-6.0000','6500.0000','-39000.00','34.0000','6500.0000','2026-10-17 00:06:39'),
(30,14,42,'2026-08-15',2,3,'6.0000','6500.0000','39000.00','40.0000','6500.0000','2026-10-17 00:06:39'),
(31,14,43,'2026-08-15',3,1,'-10.0000','616.6667','-6166.67','170.0000','616.6666','2026-10-17 00:06:39'),
(32,14,43,'2026-08-15',3,3,'10.0000','616.6670','6166.67','180.0000','616.6667','2026-10-17 00:06:39'),
(33,14,44,'2026-08-15',4,1,'-20.0000','350.0000','-7000.00','60.0000','350.0000','2026-10-17 00:06:39'),
(34,14,44,'2026-08-15',4,3,'20.0000','350.0000','7000.00','80.0000','350.0000','2026-10-17 00:06:39'),
(35,14,45,'2026-08-15',5,1,'-30.0000','180.0000','-5400.00','70.0000','180.0000','2026-10-17 00:06:39'),
(36,14,45,'2026-08-15',5,3,'30.0000','180.0000','5400.00','100.0000','180.0000','2026-10-17 00:06:39'),
(37,14,46,'2026-08-15',6,1,'-8.0000','500.0000','-4000.00','22.0000','500.0000','2026-10-17 00:06:39'),
(38,14,46,'2026-08-15',6,3,'8.0000','500.0000','4000.00','30.0000','500.0000','2026-10-17 00:06:39'),
(39,14,47,'2026-08-15',7,1,'-15.0000','90.0000','-1350.00','65.0000','90.0000','2026-10-17 00:06:39'),
(40,14,47,'2026-08-15',7,3,'15.0000','90.0000','1350.00','80.0000','90.0000','2026-10-17 00:06:39'),
(41,15,49,'2026-08-18',2,1,'-5.0000','6500.0000','-32500.00','35.0000','6500.0000','2026-10-17 00:06:39'),
(42,15,50,'2026-08-18',3,1,'-5.0000','616.6667','-3083.33','175.0000','616.6667','2026-10-17 00:06:39'),
(43,15,51,'2026-08-18',4,1,'-5.0000','350.0000','-1750.00','75.0000','350.0000','2026-10-17 00:06:39'),
(44,15,52,'2026-08-18',7,1,'-5.0000','90.0000','-450.00','75.0000','90.0000','2026-10-17 00:06:39'),
(45,15,48,'2026-08-18',11,1,'5.0000','7706.6660','38533.33','5.0000','7706.6660','2026-10-17 00:06:39'),
(46,16,54,'2026-08-19',11,1,'-2.0000','7706.6660','-15413.33','3.0000','7706.6667','2026-10-17 00:06:39'),
(47,16,54,'2026-08-19',11,2,'2.0000','7706.6650','15413.33','5.0000','7706.6660','2026-10-17 00:06:39'),
(48,18,61,'2026-09-01',24,1,'3.0000','8500.0000','25500.00','3.0000','8500.0000','2026-10-17 00:06:39'),
(49,18,62,'2026-09-01',25,1,'6.0000','3000.0000','18000.00','6.0000','3000.0000','2026-10-17 00:06:39'),
(50,19,63,'2026-09-07',24,1,'-2.0000','8500.0000','-17000.00','1.0000','8500.0000','2026-10-17 00:06:39'),
(51,19,64,'2026-09-07',5,1,'100.0000','170.0000','17000.00','200.0000','175.0000','2026-10-17 00:06:39'),
(52,20,65,'2026-09-12',25,1,'-3.0000','3000.0000','-9000.00','3.0000','3000.0000','2026-10-17 00:06:39'),
(53,20,67,'2026-09-12',8,1,'5.0000','853.7640','4268.82','25.0000','1050.7528','2026-10-17 00:06:39'),
(54,20,68,'2026-09-12',9,1,'3.0000','1662.0600','4986.18','23.0000','2173.3122','2026-10-17 00:06:39'),
(55,20,69,'2026-09-12',27,1,'13.0000','15.0000','195.00','13.0000','15.0000','2026-10-17 00:06:39'),
(56,21,70,'2026-09-22',25,1,'-2.0000','3000.0000','-6000.00','1.0000','3000.0000','2026-10-17 00:06:39'),
(57,21,71,'2026-09-22',9,1,'-2.0000','2173.3122','-4346.62','21.0000','2173.3124','2026-10-17 00:06:39'),
(58,21,73,'2026-09-22',26,1,'2.0000','4737.3150','9474.63','2.0000','4737.3150','2026-10-17 00:06:39'),
(59,21,74,'2026-09-22',8,1,'4.0000','417.9975','1671.99','29.0000','963.4762','2026-10-17 00:06:39'),
(60,21,75,'2026-09-22',27,1,'2.0000','0.0000','0.00','15.0000','13.0000','2026-10-17 00:06:39'),
(61,22,76,'2026-10-02',11,2,'-1.0000','7706.6660','-7706.67','4.0000','7706.6650','2026-10-17 00:06:39'),
(62,22,77,'2026-10-02',7,2,'1.0000','90.0000','90.00','76.0000','90.0000','2026-10-17 00:06:39'),
(63,22,78,'2026-10-02',3,2,'1.0000','616.6700','616.67','176.0000','616.6667','2026-10-17 00:06:39'),
(64,22,79,'2026-10-02',2,2,'1.0000','6500.0000','6500.00','36.0000','6500.0000','2026-10-17 00:06:39'),
(65,22,80,'2026-10-02',4,2,'1.0000','350.0000','350.00','76.0000','350.0000','2026-10-17 00:06:39'),
(66,26,94,'2026-08-28',1,1,'-3.0000','32000.0000','-96000.00','17.0000','32000.0000','2026-10-17 00:06:39'),
(67,26,95,'2026-08-28',11,1,'-3.0000','7706.6650','-23120.00','1.0000','7706.6600','2026-10-17 00:06:39'),
(68,30,102,'2026-10-05',1,1,'-2.0000','32000.0000','-64000.00','15.0000','32000.0000','2026-10-17 00:06:39'),
(69,31,103,'2026-08-30',5,1,'-40.0000','175.0000','-7000.00','160.0000','175.0000','2026-10-17 00:06:39'),
(70,31,104,'2026-08-30',3,1,'-15.0000','616.6667','-9250.00','161.0000','616.6667','2026-10-17 00:06:39'),
(71,31,105,'2026-08-30',4,1,'-15.0000','350.0000','-5250.00','61.0000','350.0000','2026-10-17 00:06:39'),
(72,32,108,'2026-09-12',6,1,'-10.0000','500.0000','-5000.00','20.0000','500.0000','2026-10-17 00:06:39'),
(73,32,109,'2026-09-12',7,1,'-20.0000','90.0000','-1800.00','56.0000','90.0000','2026-10-17 00:06:39'),
(74,33,110,'2026-09-17',1,1,'-2.0000','32000.0000','-64000.00','13.0000','32000.0000','2026-10-17 00:06:39'),
(75,33,111,'2026-09-17',8,1,'-4.0000','963.4762','-3853.90','25.0000','963.4764','2026-10-17 00:06:39'),
(76,33,112,'2026-09-17',9,1,'-2.0000','2173.3124','-4346.62','19.0000','2173.3126','2026-10-17 00:06:39'),
(77,40,121,'2026-09-07',1,1,'-1.0000','32000.0000','-32000.00','12.0000','32000.0000','2026-10-17 00:06:39'),
(78,40,122,'2026-09-07',6,1,'-1.0000','500.0000','-500.00','19.0000','500.0000','2026-10-17 00:06:39'),
(79,40,123,'2026-09-07',4,1,'-1.0000','350.0000','-350.00','60.0000','350.0000','2026-10-17 00:06:39'),
(80,41,124,'2026-09-27',3,1,'-36.0000','616.6667','-22200.00','125.0000','616.6667','2026-10-17 00:06:39'),
(81,46,125,'2026-09-13',2,1,'-10.0000','6500.0000','-65000.00','26.0000','6500.0000','2026-10-17 00:06:39'),
(82,48,126,'2026-09-20',3,1,'2.0000','616.6667','1233.33','127.0000','616.6667','2026-10-17 00:06:39'),
(83,58,136,'2026-09-01',4,1,'-2.0000','350.0000','-700.00','58.0000','350.0000','2026-10-17 00:06:39'),
(84,65,139,'2026-09-23',6,1,'-2.0000','500.0000','-1000.00','17.0000','500.0000','2026-10-17 00:06:39'),
(85,66,140,'2026-10-09',5,2,'-1.0000','175.0000','-175.00','159.0000','175.0000','2026-10-17 00:06:39'),
(86,66,141,'2026-10-09',7,2,'1.0000','90.0000','90.00','57.0000','90.0000','2026-10-17 00:06:39'),
(87,74,165,'2026-10-16',4,2,'-2.0000','350.0000','-700.00','56.0000','350.0000','2026-10-17 00:06:39'),
(88,74,166,'2026-10-16',5,2,'-3.0000','175.0000','-525.00','156.0000','175.0000','2026-10-17 00:06:39'),
(89,75,169,'2026-10-16',1,2,'-1.0000','32000.0000','-32000.00','11.0000','32000.0000','2026-10-17 00:06:40'),
(90,75,170,'2026-10-16',6,2,'-1.0000','500.0000','-500.00','16.0000','500.0000','2026-10-17 00:06:40'),
(91,76,173,'2026-10-16',3,2,'-1.0000','616.6667','-616.67','126.0000','616.6667','2026-10-17 00:06:40'),
(92,76,174,'2026-10-16',7,2,'-2.0000','90.0000','-180.00','55.0000','90.0000','2026-10-17 00:06:40'),
(94,78,178,'2026-10-16',5,2,'-2.0000','175.0000','-350.00','154.0000','175.0000','2026-10-17 00:06:40'),
(95,79,179,'2026-10-16',4,2,'1.0000','350.0000','350.00','57.0000','350.0000','2026-10-17 00:06:40'),
(96,81,184,'2026-10-17',5,2,'-1.0000','175.0000','-175.00','153.0000','175.0000','2026-10-17 00:06:40'),
(97,81,185,'2026-10-17',7,2,'-1.0000','90.0000','-90.00','54.0000','90.0000','2026-10-17 00:06:40'),
(98,82,187,'2026-10-17',11,2,'-1.0000','7706.6600','-7706.66','0.0000','7706.6600','2026-10-17 00:06:40');

-- receipt_documents (1 rows)
INSERT INTO `receipt_documents` (`id`,`file_path`,`original_name`,`mime_type`,`source`,`vendor_id`,`receipt_date`,`amount`,`account_id`,`memo`,`status`,`linked_txn_id`,`uploaded_by`,`uploaded_at`,`reviewed_by`,`reviewed_at`) VALUES
(1,'sample_petron.txt','Petron_2026-10-14_2150.00.txt','text/plain','email',5,'2026-10-14','2150.00',63,NULL,'for_review',NULL,1,'2026-10-17 00:06:40',NULL,NULL);

-- asset_categories (6 rows)
INSERT INTO `asset_categories` (`id`,`name`,`asset_account_id`,`accum_dep_account_id`,`dep_expense_account_id`,`default_method`,`default_life_years`,`is_active`) VALUES
(1,'Buildings',20,21,67,'straight_line','25.00',1),
(2,'Machinery and Equipment',22,23,67,'straight_line','5.00',1),
(3,'Production Machinery (usage-based)',22,23,67,'units_of_production','5.00',1),
(4,'Transportation Equipment',24,25,67,'declining_balance','5.00',1),
(5,'Furniture and Fixtures',26,27,67,'straight_line','10.00',1),
(6,'Computer and POS Equipment',28,29,67,'declining_balance','3.00',1);

-- asset_locations (2 rows)
INSERT INTO `asset_locations` (`id`,`name`,`is_active`,`created_at`,`updated_at`) VALUES
(1,'Main Warehouse',1,'2026-10-17 00:06:39',NULL),
(2,'Makati Store',1,'2026-10-17 00:06:39',NULL);

-- fixed_assets (4 rows)
INSERT INTO `fixed_assets` (`id`,`asset_no`,`description`,`category_id`,`location`,`location_id`,`site_id`,`class_id`,`serial_no`,`vendor_id`,`acquisition_date`,`cost`,`salvage_value`,`useful_life_years`,`method`,`db_multiplier`,`total_units`,`unit_label`,`basis_date`,`basis_nbv`,`basis_life_months`,`opening_accum_dep`,`opening_through`,`acquisition_txn_id`,`status`,`disposal_date`,`disposal_proceeds`,`disposal_txn_id`,`notes`,`current_meter`,`meter_unit`,`created_at`,`updated_at`) VALUES
(1,'FA-00001','Packaging Machine PM-500',2,'Main Warehouse',1,NULL,NULL,'PM500-2231',8,'2026-08-01','500000.00','50000.00','5.00','straight_line','2.00',NULL,NULL,NULL,NULL,NULL,'0.00',NULL,2,'active',NULL,NULL,NULL,NULL,NULL,NULL,'2026-10-17 00:06:39',NULL),
(2,'FA-00002','Delivery Van (L300)',4,'Main Warehouse',1,NULL,NULL,'NAB-1234',8,'2026-08-01','1200000.00','200000.00','5.00','declining_balance','2.00',NULL,NULL,NULL,NULL,NULL,'0.00',NULL,3,'active',NULL,NULL,NULL,NULL,'45200.00','km','2026-10-17 00:06:39','2026-10-17 00:06:39'),
(3,'FA-00003','POS Terminal Set (Makati)',6,'Makati Store',2,NULL,NULL,NULL,1,'2026-08-01','60000.00','0.00','3.00','syd','2.00',NULL,NULL,NULL,NULL,NULL,'0.00',NULL,4,'active',NULL,NULL,NULL,NULL,NULL,NULL,'2026-10-17 00:06:39',NULL),
(4,'FA-00004','Printing Machine PR-300',3,'Main Warehouse',1,NULL,NULL,NULL,8,'2026-08-01','500000.00','50000.00','5.00','units_of_production','2.00','300000.00','units',NULL,NULL,NULL,'0.00',NULL,5,'active',NULL,NULL,NULL,NULL,NULL,NULL,'2026-10-17 00:06:39',NULL);

-- asset_depreciation (8 rows)
INSERT INTO `asset_depreciation` (`id`,`asset_id`,`period_year`,`period_month`,`units_used`,`amount`,`txn_id`,`created_at`) VALUES
(1,3,2026,8,NULL,'2500.00',71,'2026-10-17 00:06:39'),
(2,1,2026,8,NULL,'7500.00',71,'2026-10-17 00:06:39'),
(3,4,2026,8,'4200.00','6300.00',71,'2026-10-17 00:06:39'),
(4,2,2026,8,NULL,'40000.00',71,'2026-10-17 00:06:39'),
(5,3,2026,9,NULL,'2500.00',72,'2026-10-17 00:06:39'),
(6,1,2026,9,NULL,'7500.00',72,'2026-10-17 00:06:39'),
(7,4,2026,9,'5100.00','7650.00',72,'2026-10-17 00:06:39'),
(8,2,2026,9,NULL,'40000.00',72,'2026-10-17 00:06:39');

-- asset_meter_readings (2 rows)
INSERT INTO `asset_meter_readings` (`asset_id`,`period_year`,`period_month`,`units`,`entered_by`,`entered_at`) VALUES
(4,2026,8,'4200.00',1,'2026-10-17 00:06:39'),
(4,2026,9,'5100.00',1,'2026-10-17 00:06:39');

-- asset_pm_schedules (3 rows)
INSERT INTO `asset_pm_schedules` (`id`,`asset_id`,`task_name`,`task_type`,`interval_value`,`interval_unit`,`meter_interval`,`next_due_date`,`next_due_meter`,`remind_days`,`last_done_date`,`last_done_meter`,`assigned_to`,`notes`,`is_active`,`created_by`,`created_at`,`updated_at`) VALUES
(1,2,'Vehicle registration renewal (LTO)','registration',1,'years',NULL,'2026-11-06',NULL,30,NULL,NULL,NULL,'Bring the OR/CR and the emission test result',1,1,'2026-10-17 00:06:39',NULL),
(2,2,'Change oil and oil filter','change_oil',3,'months','5000.00','2026-10-14','50000.00',7,NULL,NULL,NULL,NULL,1,1,'2026-10-17 00:06:39',NULL),
(3,3,'Clean the computers and POS units','cleaning',6,'months',NULL,'2026-12-31',NULL,14,NULL,NULL,NULL,NULL,1,1,'2026-10-17 00:06:39',NULL);

-- asset_maintenance (1 rows)
INSERT INTO `asset_maintenance` (`id`,`maint_no`,`asset_id`,`maint_date`,`maint_type`,`status`,`problem`,`description`,`vendor_id`,`performed_by`,`ref_no`,`meter_reading`,`downtime_days`,`parts_total`,`labor_total`,`tax_total`,`total`,`with_vat`,`payment_mode`,`pay_account_id`,`parts_account_id`,`labor_account_id`,`class_id`,`txn_id`,`schedule_id`,`next_service_date`,`notes`,`void_reason`,`created_by`,`created_at`,`updated_at`) VALUES
(1,'MNT-00001',2,'2026-09-27','repair','completed','Engine overheating on long trips','Replaced the radiator assembly and the water pump, flushed the cooling system.',8,'IMC Service Center','IMC-SV-0192','45200.00','2.00','11000.00','1500.00','0.00','12500.00',0,'bill',NULL,61,61,NULL,6,NULL,NULL,NULL,NULL,1,'2026-10-17 00:06:39',NULL);

-- asset_maintenance_parts (2 rows)
INSERT INTO `asset_maintenance_parts` (`id`,`maintenance_id`,`line_no`,`part_no`,`description`,`serial_no`,`model_no`,`size_spec`,`brand`,`qty`,`unit`,`unit_cost`,`amount`,`warranty_until`) VALUES
(1,1,1,'RAD-L300','Radiator assembly','DN-778812','4D56','26 mm, 2-row','Denso','1.0000','pc','8500.0000','8500.00','2027-09-27'),
(2,1,2,'WP-4D56','Water pump',NULL,'4D56',NULL,'GMB','1.0000','pc','2500.0000','2500.00',NULL);

-- asset_maintenance_labor (2 rows)
INSERT INTO `asset_maintenance_labor` (`id`,`maintenance_id`,`line_no`,`description`,`worker`,`charge_type`,`hours`,`rate`,`amount`) VALUES
(1,1,1,'Remove and install radiator and water pump','IMC mechanic','hourly','6.00','150.0000','900.00'),
(2,1,2,'Cooling system flush',NULL,'bulk','0.00','0.0000','600.00');

-- pos_terminals (2 rows)
INSERT INTO `pos_terminals` (`id`,`code`,`name`,`site_id`,`cash_account_id`,`receipt_prefix`,`next_receipt_no`,`next_z_no`,`is_active`,`class_id`) VALUES
(1,'POS-01','Makati Counter 1',2,2,'MK1-',9,2,1,2),
(2,'POS-02','Cebu Counter 1',3,2,'CB1-',1,1,1,3);

-- pos_shifts (2 rows)
INSERT INTO `pos_shifts` (`id`,`terminal_id`,`cashier_id`,`business_date`,`opened_at`,`opening_float`,`closed_at`,`expected_cash`,`counted_cash`,`over_short`,`over_short_txn_id`,`deposit_txn_id`,`status`,`closed_by`,`corrected_by`,`corrected_at`) VALUES
(1,1,7,'2026-10-16','2026-10-16 08:55:00','2000.00','2026-10-16 21:05:00','2630.88','2610.88','-20.00',80,NULL,'closed',8,NULL,NULL),
(2,1,7,'2026-10-17','2026-10-17 00:06:40','2000.00',NULL,NULL,NULL,NULL,NULL,NULL,'open',NULL,NULL,NULL);

-- pos_tenders (8 rows)
INSERT INTO `pos_tenders` (`id`,`txn_id`,`payment_method_id`,`amount`,`reference`) VALUES
(1,74,1,'2517.76',NULL),
(2,75,3,'43556.24','APR6111'),
(3,76,4,'1564.64','APR9085'),
(4,77,1,'10068.80',NULL),
(5,78,1,'784.00',NULL),
(6,79,1,'670.88','Refund'),
(7,81,1,'614.88',NULL),
(8,82,5,'14548.80','APR7044');

-- pos_cash_drops (1 rows)
INSERT INTO `pos_cash_drops` (`id`,`shift_id`,`amount`,`reason`,`created_by`,`approved_by`,`created_at`) VALUES
(1,1,'2000.00','Excess cash to safe',7,NULL,'2026-10-17 00:06:40');

-- pos_readings (2 rows)
INSERT INTO `pos_readings` (`id`,`reading_type`,`terminal_id`,`shift_id`,`z_no`,`business_date`,`first_receipt`,`last_receipt`,`sales_count`,`gross_sales`,`discounts`,`returns`,`voids`,`net_sales`,`tax`,`tenders_json`,`cash_drops`,`expected_cash`,`counted_cash`,`over_short`,`created_by`,`created_at`) VALUES
(1,'X',1,1,NULL,'2026-10-16','MK1-00000001','MK1-00000005',4,'45234.00','1999.50','670.88','10068.80','42635.50','5116.26','{\"Cash\":2630.88,\"Credit\\/Debit Card\":43556.24,\"GCash\":1564.64}','2000.00','2630.88',NULL,NULL,8,'2026-10-17 00:06:40'),
(2,'Z',1,1,1,'2026-10-16','MK1-00000001','MK1-00000005',4,'45234.00','1999.50','670.88','10068.80','42635.50','5116.26','{\"Cash\":2630.88,\"Credit\\/Debit Card\":43556.24,\"GCash\":1564.64}','2000.00','2630.88','2610.88','-20.00',8,'2026-10-17 00:06:40');

-- bank_reconciliations (1 rows)
INSERT INTO `bank_reconciliations` (`id`,`account_id`,`statement_date`,`beginning_balance`,`ending_balance`,`cleared_balance`,`difference`,`service_charge_txn_id`,`interest_txn_id`,`service_charge`,`service_date`,`service_account_id`,`interest_earned`,`interest_date`,`interest_account_id`,`class_id`,`status`,`created_by`,`created_at`,`completed_by`,`completed_at`) VALUES
(1,5,'2026-08-31','0.00','1834185.16','1834185.16','0.00',73,NULL,'0.00',NULL,NULL,'0.00',NULL,NULL,NULL,'completed',1,'2026-10-17 00:06:39',1,'2026-09-05 00:00:00');

-- reconciliation_items (6 rows)
INSERT INTO `reconciliation_items` (`reconciliation_id`,`txn_id`,`amount`,`cleared`) VALUES
(1,1,'2500000.00',1),
(1,2,'-500000.00',1),
(1,4,'-60000.00',1),
(1,51,'-85000.00',1),
(1,60,'-20664.84',1),
(1,73,'-150.00',1);

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
