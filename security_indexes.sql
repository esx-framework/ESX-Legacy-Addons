-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

-- Recommended indexes for the security hardening pass.

-- Billing: player invoices and safe payment lookups.
CREATE INDEX idx_billing_identifier_id ON billing(identifier, id);
CREATE INDEX idx_billing_sender ON billing(sender);

-- Licenses: prevent duplicates and speed up license checks.
ALTER TABLE user_licenses ADD UNIQUE KEY uq_user_license_owner_type (owner, type);
CREATE INDEX idx_user_licenses_type_owner ON user_licenses(type, owner);

-- Society and employees.
CREATE INDEX idx_users_job_grade_identifier ON users(job, job_grade, identifier);
CREATE INDEX idx_society_moneywash_society_id ON society_moneywash(society, id);

-- Legacy vehicleshop.
CREATE INDEX idx_cardealer_vehicles_vehicle ON cardealer_vehicles(vehicle);
CREATE INDEX idx_rented_vehicles_owner_plate ON rented_vehicles(owner, plate);
CREATE INDEX idx_owned_vehicles_owner_type_job ON owned_vehicles(owner, type, job);
CREATE INDEX idx_owned_vehicles_job_plate ON owned_vehicles(job, plate);
