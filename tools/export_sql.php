<?php
declare(strict_types=1);

/**
 * Writes a single importable .sql file (schema + triggers + all data) from the current database.
 *
 *   php tools/export_sql.php                         -> database/accounting_system.sql
 *   php tools/export_sql.php --out=backup.sql        -> any file
 *   php tools/export_sql.php --no-create-db          -> leave out CREATE DATABASE / USE
 *
 * The file can be imported with phpMyAdmin (Import tab) or:  mysql -u root -p < accounting_system.sql
 * Use it for backups too; importing it replaces every table.
 */
if (PHP_SAPI !== 'cli') {
    exit('Run this from the command line.');
}

require __DIR__ . '/../app/bootstrap.php';
require __DIR__ . '/lib.php';

$opts = getopt('', ['out::', 'no-create-db', 'title::']);
$out = $opts['out'] ?? (APP_ROOT . '/database/accounting_system.sql');
$name = $GLOBALS['CONFIG']['db']['name'];
$pdo = DB::pdo();

$schema = file_get_contents(APP_ROOT . '/database/schema.sql');
// the combined file controls foreign key checks itself
$schema = preg_replace('/^SET FOREIGN_KEY_CHECKS\s*=\s*[01];\s*$/mi', '', $schema);
$schema = preg_replace('/^SET NAMES utf8mb4;\s*$/mi', '', $schema);
$triggers = file_get_contents(APP_ROOT . '/database/triggers.sql');

$tables = schema_tables(APP_ROOT . '/database/schema.sql');
$counts = [];
foreach ($tables as $t) {
    $counts[$t] = (int)$pdo->query("SELECT COUNT(*) FROM `$t`")->fetchColumn();
}
$title = $opts['title'] ?? 'G-SMaRT Accounting - complete database';
$txns = $counts['transactions'] ?? 0;

$head = "-- =====================================================================\n"
    . "--  $title\n"
    . '--  Generated ' . date('Y-m-d H:i:s P') . ' from database `' . $name . "`\n"
    . '--  ' . count($tables) . ' tables, ' . array_sum($counts) . " rows ($txns transactions)\n"
    . "--\n"
    . "--  Import:  phpMyAdmin > Import > choose this file > Go\n"
    . "--      or:  mysql -u root -p < accounting_system.sql\n"
    . "--  Works on MySQL 5.5.3 or newer (5.5, 5.6, 5.7, 8.x) and MariaDB 5.5 or newer.\n"
    . "--  Import as root (or a user with CREATE, INSERT, REFERENCES and TRIGGER privileges).\n"
    . "--  WARNING: importing drops and recreates every table in the database below.\n"
    . "--\n"
    . "--  Default login: admin / Admin@12345 (a new password is required at first login)\n"
    . "-- =====================================================================\n\n"
    . "SET NAMES utf8mb4;\n"
    . "SET FOREIGN_KEY_CHECKS = 0;\n"
    . "SET SQL_MODE = 'NO_AUTO_VALUE_ON_ZERO';\n"
    . "SET time_zone = '" . date('P') . "';\n\n";

if (!isset($opts['no-create-db'])) {
    $head .= "CREATE DATABASE IF NOT EXISTS `$name` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;\n"
        . "USE `$name`;\n\n";
}

$sql = $head
    . "-- ---------------------------------------------------------------------\n"
    . "--  1. TABLES\n"
    . "-- ---------------------------------------------------------------------\n"
    . trim($schema) . "\n\n"
    . "-- ---------------------------------------------------------------------\n"
    . "--  2. DATA\n"
    . "-- ---------------------------------------------------------------------\n"
    . export_data($pdo, $tables) . "\n"
    . "-- ---------------------------------------------------------------------\n"
    . "--  3. AUDIT TRAIL PROTECTION (created after the data is loaded)\n"
    . trim($triggers) . "\n\n"
    . "SET FOREIGN_KEY_CHECKS = 1;\n";

file_put_contents($out, $sql);
out(sprintf('Wrote %s (%s KB, %d tables, %d rows).', $out, number_format(strlen($sql) / 1024), count($tables), array_sum($counts)));
