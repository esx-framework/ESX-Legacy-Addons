CREATE TABLE `second_owners` (
	`id` INT(11) NOT NULL AUTO_INCREMENT,
	`identifier` VARCHAR(60) NOT NULL COLLATE 'utf8mb3_general_ci',
	`plate` VARCHAR(12) NOT NULL COLLATE 'utf8mb3_general_ci',
	`favorite` TINYINT(4) NOT NULL DEFAULT '0',
	`nickname` VARCHAR(50) NULL DEFAULT NULL COLLATE 'utf8mb3_general_ci',
	PRIMARY KEY (`id`) USING BTREE,
	INDEX `identifier` (`identifier`) USING BTREE,
	INDEX `plate_fk` (`plate`) USING BTREE,
	CONSTRAINT `identifier_fk` FOREIGN KEY (`identifier`) REFERENCES `users` (`identifier`) ON UPDATE CASCADE ON DELETE CASCADE,
	CONSTRAINT `plate_fk` FOREIGN KEY (`plate`) REFERENCES `owned_vehicles` (`plate`) ON UPDATE CASCADE ON DELETE CASCADE
)

ALTER TABLE `owned_vehicles`
ADD COLUMN `mileage` DECIMAL(20,6) NULL DEFAULT NULL AFTER `last_used`,
ADD COLUMN `model` VARCHAR(32) NULL DEFAULT NULL COLLATE 'utf8mb3_general_ci' AFTER `trunk`,
ADD COLUMN `last_used` BIGINT(20) NULL DEFAULT NULL AFTER `nickname`,
ADD COLUMN `nickname` VARCHAR(50) NULL DEFAULT NULL COLLATE 'utf8mb3_general_ci' AFTER `favorite`;
