-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

-- esx_garage schema additions for `owned_vehicles`.
-- Existing servers: the resource auto-migrates on start (server/modules/migration.lua); this file is optional.
-- Fresh installs / manual setup: run it once, or as many times as you like.
-- Every statement below is guarded, so re-running is a no-op instead of an error.

CREATE TABLE IF NOT EXISTS `esx_garage_migrations` (
    `name` VARCHAR(64) NOT NULL,
    `version` VARCHAR(32) NOT NULL DEFAULT '0',
    `applied_at` INT NOT NULL DEFAULT 0,
    PRIMARY KEY (`name`)
);

SET @fix_migration_version_column := (SELECT IF(
    EXISTS(SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'esx_garage_migrations' AND COLUMN_NAME = 'version' AND DATA_TYPE = 'varchar'),
    'SELECT 1',
    'ALTER TABLE `esx_garage_migrations` MODIFY COLUMN `version` VARCHAR(32) NOT NULL DEFAULT ''0'''));
PREPARE s FROM @fix_migration_version_column; EXECUTE s; DEALLOCATE PREPARE s;

SET @add_parking := (SELECT IF(
    EXISTS(SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'owned_vehicles' AND COLUMN_NAME = 'parking'),
    'SELECT 1',
    'ALTER TABLE `owned_vehicles` ADD COLUMN `parking` VARCHAR(60) NULL DEFAULT NULL'));
PREPARE s FROM @add_parking; EXECUTE s; DEALLOCATE PREPARE s;

SET @add_pound := (SELECT IF(
    EXISTS(SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'owned_vehicles' AND COLUMN_NAME = 'pound'),
    'SELECT 1',
    'ALTER TABLE `owned_vehicles` ADD COLUMN `pound` VARCHAR(60) NULL DEFAULT NULL'));
PREPARE s FROM @add_pound; EXECUTE s; DEALLOCATE PREPARE s;

SET @add_custom_name := (SELECT IF(
    EXISTS(SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'owned_vehicles' AND COLUMN_NAME = 'custom_name'),
    'SELECT 1',
    'ALTER TABLE `owned_vehicles` ADD COLUMN `custom_name` VARCHAR(50) NULL DEFAULT NULL'));
PREPARE s FROM @add_custom_name; EXECUTE s; DEALLOCATE PREPARE s;

SET @add_is_favorite := (SELECT IF(
    EXISTS(SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'owned_vehicles' AND COLUMN_NAME = 'is_favorite'),
    'SELECT 1',
    'ALTER TABLE `owned_vehicles` ADD COLUMN `is_favorite` TINYINT(1) NOT NULL DEFAULT 0'));
PREPARE s FROM @add_is_favorite; EXECUTE s; DEALLOCATE PREPARE s;

SET @add_last_used := (SELECT IF(
    EXISTS(SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'owned_vehicles' AND COLUMN_NAME = 'last_used'),
    'SELECT 1',
    'ALTER TABLE `owned_vehicles` ADD COLUMN `last_used` INT NULL DEFAULT NULL'));
PREPARE s FROM @add_last_used; EXECUTE s; DEALLOCATE PREPARE s;

SET @add_mileage := (SELECT IF(
    EXISTS(SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'owned_vehicles' AND COLUMN_NAME = 'mileage'),
    'SELECT 1',
    'ALTER TABLE `owned_vehicles` ADD COLUMN `mileage` DECIMAL(10,2) NOT NULL DEFAULT 0.00'));
PREPARE s FROM @add_mileage; EXECUTE s; DEALLOCATE PREPARE s;

UPDATE `owned_vehicles` SET `mileage` = 0 WHERE `mileage` IS NULL;

SET @fix_mileage_precision := (SELECT IF(
    EXISTS(
        SELECT 1 FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
            AND TABLE_NAME = 'owned_vehicles'
            AND COLUMN_NAME = 'mileage'
            AND (DATA_TYPE <> 'decimal'
                OR NUMERIC_PRECISION <> 10
                OR NUMERIC_SCALE <> 2
                OR IS_NULLABLE <> 'NO'
                OR COLUMN_DEFAULT IS NULL
                OR COLUMN_DEFAULT NOT IN ('0', '0.0', '0.00'))
    ),
    'ALTER TABLE `owned_vehicles` MODIFY COLUMN `mileage` DECIMAL(10,2) NOT NULL DEFAULT 0.00',
    'SELECT 1'));
PREPARE s FROM @fix_mileage_precision; EXECUTE s; DEALLOCATE PREPARE s;

SET @add_owner_plate_index := (SELECT IF(
    EXISTS(SELECT 1 FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'owned_vehicles' AND INDEX_NAME = 'idx_owned_vehicles_owner_plate'),
    'SELECT 1',
    'ALTER TABLE `owned_vehicles` ADD INDEX `idx_owned_vehicles_owner_plate` (`owner`, `plate`)'));
PREPARE s FROM @add_owner_plate_index; EXECUTE s; DEALLOCATE PREPARE s;

SET @add_owner_custom_name_index := (SELECT IF(
    EXISTS(SELECT 1 FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'owned_vehicles' AND INDEX_NAME = 'idx_owned_vehicles_owner_custom_name'),
    'SELECT 1',
    'ALTER TABLE `owned_vehicles` ADD INDEX `idx_owned_vehicles_owner_custom_name` (`owner`, `custom_name`)'));
PREPARE s FROM @add_owner_custom_name_index; EXECUTE s; DEALLOCATE PREPARE s;

SET @add_owner_stored_pound_plate_index := (SELECT IF(
    EXISTS(SELECT 1 FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'owned_vehicles' AND INDEX_NAME = 'idx_owned_vehicles_owner_stored_pound_plate'),
    'SELECT 1',
    'ALTER TABLE `owned_vehicles` ADD INDEX `idx_owned_vehicles_owner_stored_pound_plate` (`owner`, `stored`, `pound`, `plate`)'));
PREPARE s FROM @add_owner_stored_pound_plate_index; EXECUTE s; DEALLOCATE PREPARE s;

SET @add_owner_pound_plate_stored_index := (SELECT IF(
    EXISTS(SELECT 1 FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'owned_vehicles' AND INDEX_NAME = 'idx_owned_vehicles_owner_pound_plate_stored'),
    'SELECT 1',
    'ALTER TABLE `owned_vehicles` ADD INDEX `idx_owned_vehicles_owner_pound_plate_stored` (`owner`, `pound`, `plate`, `stored`)'));
PREPARE s FROM @add_owner_pound_plate_stored_index; EXECUTE s; DEALLOCATE PREPARE s;

SET @add_owner_favorite_plate_index := (SELECT IF(
    EXISTS(SELECT 1 FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'owned_vehicles' AND INDEX_NAME = 'idx_owned_vehicles_owner_favorite_plate'),
    'SELECT 1',
    'ALTER TABLE `owned_vehicles` ADD INDEX `idx_owned_vehicles_owner_favorite_plate` (`owner`, `is_favorite`, `plate`)'));
PREPARE s FROM @add_owner_favorite_plate_index; EXECUTE s; DEALLOCATE PREPARE s;

-- Legacy impound (stored = 2) -> stored = 1 + pound. Set the lot id below to a valid impound id from your config.lua.
-- Idempotent: once converted, no row matches stored = 2 anymore.
UPDATE `owned_vehicles` SET `stored` = 1, `parking` = NULL, `pound` = 'los_santos' WHERE `stored` = 2;

INSERT INTO `esx_garage_migrations` (`name`, `version`, `applied_at`)
VALUES ('schema', '1.14.2', UNIX_TIMESTAMP())
ON DUPLICATE KEY UPDATE `version` = '1.14.2', `applied_at` = UNIX_TIMESTAMP();

INSERT INTO `esx_garage_migrations` (`name`, `version`, `applied_at`)
VALUES ('performance_indexes', '1.14.2', UNIX_TIMESTAMP())
ON DUPLICATE KEY UPDATE `version` = '1.14.2', `applied_at` = UNIX_TIMESTAMP();

INSERT INTO `esx_garage_migrations` (`name`, `version`, `applied_at`)
VALUES ('filter_indexes', '1.14.2', UNIX_TIMESTAMP())
ON DUPLICATE KEY UPDATE `version` = '1.14.2', `applied_at` = UNIX_TIMESTAMP();

INSERT INTO `esx_garage_migrations` (`name`, `version`, `applied_at`)
VALUES ('mileage_precision', '1.14.2', UNIX_TIMESTAMP())
ON DUPLICATE KEY UPDATE `version` = '1.14.2', `applied_at` = UNIX_TIMESTAMP();
