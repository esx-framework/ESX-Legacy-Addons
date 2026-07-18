-- esx_garage schema additions for `owned_vehicles`.
-- Existing servers: the resource auto-migrates on start (server/modules/migration.lua); this file is optional.
-- Fresh installs / manual setup: run it once, or as many times as you like.
-- Every statement below is guarded, so re-running is a no-op instead of an error.

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
    'ALTER TABLE `owned_vehicles` ADD COLUMN `mileage` INT NOT NULL DEFAULT 0'));
PREPARE s FROM @add_mileage; EXECUTE s; DEALLOCATE PREPARE s;

-- Legacy impound (stored = 2) -> stored = 1 + pound. Set the lot id below to a valid impound id from your config.lua.
-- Idempotent: once converted, no row matches stored = 2 anymore.
UPDATE `owned_vehicles` SET `stored` = 1, `parking` = NULL, `pound` = 'los_santos' WHERE `stored` = 2;
