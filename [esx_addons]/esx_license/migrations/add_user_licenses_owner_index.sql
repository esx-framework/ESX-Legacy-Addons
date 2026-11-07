-- Run in the database containing the existing user_licenses table.
SET @esx_license_owner_index_sql = IF(
	EXISTS (
		SELECT 1
		FROM INFORMATION_SCHEMA.STATISTICS
		WHERE TABLE_SCHEMA = DATABASE()
			AND TABLE_NAME = 'user_licenses'
			AND COLUMN_NAME = 'owner'
			AND SEQ_IN_INDEX = 1
			AND SUB_PART IS NULL
			AND INDEX_TYPE = 'BTREE'
	),
	'SELECT ''user_licenses already has an owner index'' AS migration_status',
	'ALTER TABLE `user_licenses` ADD KEY `esx_user_licenses_owner` (`owner`)'
);

PREPARE esx_license_owner_index FROM @esx_license_owner_index_sql;
EXECUTE esx_license_owner_index;
DEALLOCATE PREPARE esx_license_owner_index;
