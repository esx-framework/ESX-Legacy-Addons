-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

SET @esx_death_migration := (SELECT IF(
	EXISTS(SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME = 'is_dead'),
	'SELECT 1',
	'ALTER TABLE `users` ADD COLUMN `is_dead` TINYINT(1) NOT NULL DEFAULT 0'));
PREPARE s FROM @esx_death_migration; EXECUTE s; DEALLOCATE PREPARE s;

SET @esx_death_migration := (SELECT IF(
	EXISTS(SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME = 'death_time'),
	'SELECT 1',
	'ALTER TABLE `users` ADD COLUMN `death_time` BIGINT NULL DEFAULT NULL'));
PREPARE s FROM @esx_death_migration; EXECUTE s; DEALLOCATE PREPARE s;
