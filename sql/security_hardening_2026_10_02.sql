-- Optional manual alternative: billing, license, addonaccount and banking now
-- apply their own schema migrations automatically on resource startup.
-- For manual execution, apply in a maintenance window after backup and duplicate inspection.
-- MySQL 8 / MariaDB 10.6+. DDL commits implicitly; this is not a rollback transaction.
-- Re-runnable. Duplicate financial rows are never silently merged or deleted.
DELIMITER $$
DROP PROCEDURE IF EXISTS esx_hardening_20261002$$
CREATE PROCEDURE esx_hardening_20261002()
BEGIN
    IF EXISTS (SELECT 1 FROM user_licenses GROUP BY owner, type HAVING COUNT(*) > 1) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Duplicate user_licenses: reconcile before migration';
    END IF;
    IF EXISTS (SELECT 1 FROM addon_account_data GROUP BY account_name, COALESCE(owner, '') HAVING COUNT(*) > 1) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Duplicate addon accounts: reconcile balances before migration';
    END IF;
    IF EXISTS (SELECT 1 FROM addon_account_data WHERE account_name IS NULL OR owner = '') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid addon account name/empty owner: reconcile before migration';
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE()
        AND TABLE_NAME IN ('billing', 'users', 'addon_account_data') AND ENGINE <> 'InnoDB') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Economy tables must use InnoDB';
    END IF;

    CREATE TABLE IF NOT EXISTS billing_payments (
        bill_id INT NOT NULL,
        operation_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
        identifier VARCHAR(60) NOT NULL,
        sender VARCHAR(60) NOT NULL,
        target_type VARCHAR(10) NOT NULL,
        target VARCHAR(100) NOT NULL,
        label VARCHAR(255) NOT NULL,
        amount INT NOT NULL,
        payment_account VARCHAR(20) NOT NULL,
        state ENUM('claimed', 'applied') NOT NULL DEFAULT 'claimed',
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        applied_at TIMESTAMP NULL DEFAULT NULL,
        PRIMARY KEY (bill_id),
        UNIQUE KEY uq_billing_payment_operation (operation_id),
        KEY idx_billing_payment_state_created (state, created_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

    IF NOT EXISTS (SELECT 1 FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = DATABASE()
        AND TABLE_NAME = 'user_licenses' AND NON_UNIQUE = 0 GROUP BY INDEX_NAME
        HAVING COUNT(*) = 2 AND SUM(SUB_PART IS NOT NULL) = 0
        AND GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) IN ('owner,type', 'type,owner')) THEN
        ALTER TABLE user_licenses ADD UNIQUE KEY uq_user_licenses_owner_type (owner, type);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = DATABASE()
        AND TABLE_NAME = 'billing' AND COLUMN_NAME = 'identifier' AND SEQ_IN_INDEX = 1 AND SUB_PART IS NULL) THEN
        ALTER TABLE billing ADD KEY idx_billing_identifier (identifier);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE()
        AND TABLE_NAME = 'addon_account_data' AND COLUMN_NAME = 'owner_key') THEN
        ALTER TABLE addon_account_data ADD COLUMN owner_key VARCHAR(60)
            GENERATED ALWAYS AS (COALESCE(owner, '')) STORED;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = DATABASE()
        AND TABLE_NAME = 'addon_account_data' AND NON_UNIQUE = 0 GROUP BY INDEX_NAME
        HAVING COUNT(*) = 2 AND SUM(SUB_PART IS NOT NULL) = 0
        AND GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) IN ('account_name,owner_key', 'owner_key,account_name')) THEN
        ALTER TABLE addon_account_data ADD UNIQUE KEY uq_addon_account_owner_key (account_name, owner_key);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = DATABASE()
        AND TABLE_NAME = 'banking' AND COLUMN_NAME = 'time' AND SEQ_IN_INDEX = 1 AND SUB_PART IS NULL) THEN
        ALTER TABLE banking ADD KEY idx_banking_time (time);
    END IF;
END$$
CALL esx_hardening_20261002()$$
DROP PROCEDURE esx_hardening_20261002$$
DELIMITER ;

-- Inspection only: do not replay or refund these automatically. RAM wallets and
-- their SQL snapshots are not one database transaction with the billing journal.
SELECT bill_id, operation_id, identifier, target_type, target, amount, payment_account, created_at
FROM billing_payments WHERE state = 'claimed' ORDER BY created_at;
