<?php
declare(strict_types=1);

/**
 * Command-line installer.
 *
 *   php tools/install.php            create the database (if missing), tables, triggers and master data
 *   php tools/install.php --demo     ... plus sample transactions
 *   php tools/install.php --drop     drop and recreate the database first (DESTROYS DATA)
 *
 * Database settings come from config/config.php (or DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASS).
 */
if (PHP_SAPI !== 'cli') {
    exit('Run this from the command line.');
}

require __DIR__ . '/../app/bootstrap.php';
require __DIR__ . '/lib.php';
require __DIR__ . '/seed.php';

$opts = getopt('', ['demo', 'drop']);
$name = $GLOBALS['CONFIG']['db']['name'];

$server = server_pdo();
if (isset($opts['drop'])) {
    out("Dropping database `$name` ...");
    $server->exec("DROP DATABASE IF EXISTS `$name`");
}
$server->exec("CREATE DATABASE IF NOT EXISTS `$name` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci");

$pdo = DB::pdo();
$existing = (int)$pdo->query("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'users'")->fetchColumn();
if ($existing && !isset($opts['drop'])) {
    out('The database already has tables. Use --drop to reinstall (this deletes all data).');
    exit(1);
}

out('Creating tables ...');
run_sql_file($pdo, APP_ROOT . '/database/schema.sql');
out('Creating audit trail protection triggers ...');
run_sql_file($pdo, APP_ROOT . '/database/triggers.sql');

out('Loading master data ...');
DB::tx(function () {
    seed_master_data();
});

if (isset($opts['demo'])) {
    require __DIR__ . '/demo_data.php';
    out('Recording sample transactions ...');
    load_demo_data();
}

out('Done. Log in as admin / Admin@12345 (you will be asked to choose a new password).');
