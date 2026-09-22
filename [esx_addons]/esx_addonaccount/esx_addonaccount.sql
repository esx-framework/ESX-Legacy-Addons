-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

CREATE TABLE IF NOT EXISTS `addon_account` (
	`name` VARCHAR(60) NOT NULL,
	`label` VARCHAR(100) NOT NULL,
	`shared` INT NOT NULL,

	PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `addon_account_data` (
	`id` INT NOT NULL AUTO_INCREMENT,
	`account_name` VARCHAR(100) DEFAULT NULL,
	`money` INT NOT NULL,
	`owner` VARCHAR(60) DEFAULT NULL,

	PRIMARY KEY (`id`),
	UNIQUE INDEX `index_addon_account_data_account_name_owner` (`account_name`, `owner`),
	INDEX `index_addon_account_data_account_name` (`account_name`),
	INDEX `index_addon_account_data_owner_account_name` (`owner`, `account_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Compatibility for existing databases created before these indexes existed.
SET @addon_account_index := (SELECT IF(
	EXISTS(SELECT 1 FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'addon_account_data' AND INDEX_NAME = 'index_addon_account_data_account_name_owner'),
	'SELECT 1',
	'ALTER TABLE `addon_account_data` ADD UNIQUE INDEX `index_addon_account_data_account_name_owner` (`account_name`, `owner`)'));
PREPARE s FROM @addon_account_index; EXECUTE s; DEALLOCATE PREPARE s;

SET @addon_account_index := (SELECT IF(
	EXISTS(SELECT 1 FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'addon_account_data' AND INDEX_NAME = 'index_addon_account_data_account_name'),
	'SELECT 1',
	'ALTER TABLE `addon_account_data` ADD INDEX `index_addon_account_data_account_name` (`account_name`)'));
PREPARE s FROM @addon_account_index; EXECUTE s; DEALLOCATE PREPARE s;

SET @addon_account_index := (SELECT IF(
	EXISTS(SELECT 1 FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'addon_account_data' AND INDEX_NAME = 'index_addon_account_data_owner_account_name'),
	'SELECT 1',
	'ALTER TABLE `addon_account_data` ADD INDEX `index_addon_account_data_owner_account_name` (`owner`, `account_name`)'));
PREPARE s FROM @addon_account_index; EXECUTE s; DEALLOCATE PREPARE s;
