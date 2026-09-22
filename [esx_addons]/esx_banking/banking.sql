-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

CREATE TABLE IF NOT EXISTS `banking` (
  `identifier` varchar(46) DEFAULT NULL,
  `type` varchar(50) DEFAULT NULL,
  `amount` int(64) DEFAULT NULL,
  `time` bigint(20) DEFAULT NULL,
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `balance` int(11) DEFAULT 0,
  `label` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`ID`),
  KEY `idx_banking_identifier_time` (`identifier`, `time`),
  KEY `idx_banking_time` (`time`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4;

SET @banking_migration := (SELECT IF(
  EXISTS(SELECT 1 FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'banking' AND INDEX_NAME = 'idx_banking_time'),
  'SELECT 1',
  'ALTER TABLE `banking` ADD INDEX `idx_banking_time` (`time`)'));
PREPARE s FROM @banking_migration; EXECUTE s; DEALLOCATE PREPARE s;

SET @banking_migration := (SELECT IF(
  EXISTS(SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME = 'pincode'),
  'SELECT 1',
  'ALTER TABLE `users` ADD COLUMN `pincode` INT NULL'));
PREPARE s FROM @banking_migration; EXECUTE s; DEALLOCATE PREPARE s;
