-- SPDX-License-Identifier: GPL-3.0-only
VehicleShopDatabaseReady = false

MySQL.ready(function()
    local ok, err = pcall(function()
        for _, name in ipairs({
            'cardealer_vehicles',
            'owned_vehicles',
            'rented_vehicles',
            'vehicle_sold',
        }) do
            local engine = MySQL.scalar.await(
                [[SELECT ENGINE FROM information_schema.TABLES
                WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?]],
                { name }
            )

            assert(engine and engine:upper() == 'INNODB', name .. ' must use InnoDB')
        end

        local dateType = MySQL.scalar.await([[SELECT DATA_TYPE FROM information_schema.COLUMNS
            WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'vehicle_sold' AND COLUMN_NAME = 'date']])

        if dateType == 'varchar' then
            local invalid = MySQL.scalar.await([[SELECT COUNT(*) FROM vehicle_sold WHERE
                date NOT REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}(:[0-9]{2})?$'
                OR STR_TO_DATE(CONCAT(LEFT(date, 16), ':00'), '%Y-%m-%d %H:%i:%s') IS NULL
                OR CAST(LEFT(date, 4) AS UNSIGNED) < 1000
                OR CAST(SUBSTRING(date, 6, 2) AS UNSIGNED) NOT BETWEEN 1 AND 12
                OR CAST(SUBSTRING(date, 9, 2) AS UNSIGNED) NOT BETWEEN 1 AND DAY(LAST_DAY(CONCAT(LEFT(date, 7), '-01')))
                OR CAST(SUBSTRING(date, 12, 2) AS UNSIGNED) > 23
                OR CAST(SUBSTRING(date, 15, 2) AS UNSIGNED) > 59
                OR (LENGTH(date) = 19 AND CAST(SUBSTRING(date, 18, 2) AS UNSIGNED) > 59)]])

            if tonumber(invalid) == 0 then
                MySQL.query.await('ALTER TABLE vehicle_sold MODIFY COLUMN date DATETIME NOT NULL')
            else
                print('[esx_vehicleshop] Historical sale dates need manual review; preserving original values.')
            end
        end

        local index = MySQL.scalar.await([[SELECT COUNT(*) FROM information_schema.STATISTICS
            WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'vehicle_sold' AND INDEX_NAME = 'idx_vehicle_sold_date_plate']])

        if tonumber(index) == 0 then
            MySQL.query.await('CREATE INDEX idx_vehicle_sold_date_plate ON vehicle_sold (date, plate)')
        end

        VehicleShopDatabaseReady = true
    end)

    if not ok then
        print('[esx_vehicleshop] Dealer transactions disabled: ' .. tostring(err))
    end
end)
