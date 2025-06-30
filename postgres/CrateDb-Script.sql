-- =============================================================================
-- Project:      Arandano IRT - Water Stress Monitoring System
-- Author:       G. Martinez (with assistance from Gemini AI)
-- Version:      3.5
-- Date:         2025-06-28
--
-- Description:
-- This script creates the initial database schema for the Arandano IRT project.
-- It defines all tables, custom types (ENUMs), relationships, and indexes
-- required for the application to function.
--
-- Conventions:
--   - All table and column names use snake_case.
--   - All tables are created in the 'public' schema.
--   - All timestamps representing a point in time use TIMESTAMPTZ for timezone safety.
--   - State management is handled by specific ENUM types for type safety.
-- =============================================================================


-- =============================================================================
-- 1. ENUMERATED TYPES (ENUMs) FOR STATE MANAGEMENT
-- =============================================================================
CREATE TYPE device_status AS ENUM ('PENDING_ACTIVATION', 'ACTIVE', 'INACTIVE', 'MAINTENANCE');
CREATE TYPE activation_status AS ENUM ('PENDING', 'COMPLETED', 'EXPIRED');
CREATE TYPE token_status AS ENUM ('ACTIVE', 'REVOKED');


-- =============================================================================
-- 2. CORE TABLES (USERS, CROPS, PLANTS)
-- =============================================================================

CREATE TABLE public.crops (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    address TEXT,
    city_name TEXT NOT NULL,
    admin_user_id INT, -- To be populated after the users table is created.
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
COMMENT ON TABLE public.crops IS 'Stores information about crops. Acts as the main grouping entity (tenant).';

CREATE TABLE public.users (
    id SERIAL PRIMARY KEY,
    first_name VARCHAR(40) NOT NULL,
    last_name VARCHAR(40) NOT NULL,
    email VARCHAR(75) NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    is_admin BOOLEAN DEFAULT FALSE NOT NULL,
    account_settings JSONB NOT NULL DEFAULT '{}'::jsonb,
    crop_id INT REFERENCES public.crops(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_login_at TIMESTAMPTZ
);
COMMENT ON TABLE public.users IS 'Stores web application users and their credentials.';

-- Add the Foreign Key constraint now that the users table exists.
ALTER TABLE public.crops ADD CONSTRAINT fk_crops_admin_user FOREIGN KEY (admin_user_id) REFERENCES public.users(id);

CREATE TABLE public.plants (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    crop_id INT NOT NULL REFERENCES public.crops(id) ON DELETE CASCADE,
    registered_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
COMMENT ON TABLE public.plants IS 'Stores data for each monitored plant.';


-- =============================================================================
-- 3. DEVICE AND AUTHENTICATION TABLES
-- =============================================================================

CREATE TABLE public.devices (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    mac_address TEXT UNIQUE,
    description TEXT,
    plant_id INT REFERENCES public.plants(id) ON DELETE SET NULL,
    crop_id INT NOT NULL REFERENCES public.crops(id) ON DELETE CASCADE,
    status device_status NOT NULL DEFAULT 'PENDING_ACTIVATION',
    data_collection_interval_minutes SMALLINT NOT NULL DEFAULT 15,
    registered_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
COMMENT ON TABLE public.devices IS 'Stores physical monitoring hardware devices.';

CREATE TABLE public.device_activations (
    id SERIAL PRIMARY KEY,
    device_id INT NOT NULL REFERENCES public.devices(id) ON DELETE CASCADE,
    activation_code TEXT NOT NULL UNIQUE,
    status activation_status NOT NULL DEFAULT 'PENDING',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    activated_at TIMESTAMPTZ
);
COMMENT ON TABLE public.device_activations IS 'Stores single-use codes to activate new devices.';

CREATE TABLE public.device_tokens (
    id SERIAL PRIMARY KEY,
    device_id INT NOT NULL REFERENCES public.devices(id) ON DELETE CASCADE,
    access_token TEXT NOT NULL UNIQUE,
    refresh_token TEXT NOT NULL UNIQUE,
    status token_status NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    access_token_expires_at TIMESTAMPTZ NOT NULL,
    refresh_token_expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ
);
COMMENT ON TABLE public.device_tokens IS 'Stores authentication tokens (JWTs) for devices.';


-- =============================================================================
-- 4. DATA COLLECTION TABLES
-- =============================================================================

CREATE TABLE public.environmental_readings (
    id BIGSERIAL PRIMARY KEY,
    device_id INT NOT NULL REFERENCES public.devices(id) ON DELETE CASCADE,
    plant_id INT REFERENCES public.plants(id) ON DELETE SET NULL,
    -- Typed (Core) Columns
    temperature REAL NOT NULL,
    humidity REAL NOT NULL,
    -- External Data Columns
    city_temperature REAL,
    city_humidity REAL,
    city_weather_condition TEXT,
    -- JSONB field for future flexibility
    extra_data JSONB,
    recorded_at_server TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    recorded_at_device TIMESTAMPTZ DEFAULT NOW()
);
COMMENT ON TABLE public.environmental_readings IS 'Stores environmental data collected by device sensors.';

CREATE TABLE public.thermal_captures (
    id BIGSERIAL PRIMARY KEY,
    device_id INT NOT NULL REFERENCES public.devices(id) ON DELETE CASCADE,
    plant_id INT REFERENCES public.plants(id) ON DELETE SET NULL,
    thermal_data_stats JSONB NOT NULL,
    rgb_image_path TEXT,
    recorded_at_server TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    recorded_at_device TIMESTAMPTZ DEFAULT NOW()
);
COMMENT ON TABLE public.thermal_captures IS 'Stores thermographic captures. Statistics are stored in JSONB, the image path in Object Storage.';

CREATE TABLE public.observations (
    id SERIAL PRIMARY KEY,
    plant_id INT NOT NULL REFERENCES public.plants(id) ON DELETE CASCADE,
    user_id INT NOT NULL REFERENCES public.users(id),
    description TEXT NOT NULL,
    subjective_rating SMALLINT, -- e.g., 1 to 5
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
COMMENT ON TABLE public.observations IS 'Stores manual observations made by an agronomist or expert user.';


-- =============================================================================
-- 5 INVITATION CODES
-- =============================================================================
CREATE TABLE public.invitation_codes (
    id SERIAL PRIMARY KEY,
    code VARCHAR(255) UNIQUE NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    is_used BOOLEAN NOT NULL DEFAULT FALSE,
    created_by_user_id INT REFERENCES public.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
COMMENT ON TABLE public.invitation_codes IS 'Stores single-use invitation codes for user registration.';

-- =============================================================================
-- 6. INDEXES
-- =============================================================================
CREATE INDEX idx_users_crop_id ON public.users(crop_id);
CREATE INDEX idx_plants_crop_id ON public.plants(crop_id);
CREATE INDEX idx_devices_plant_id ON public.devices(plant_id);
CREATE INDEX idx_devices_mac_address ON public.devices(mac_address);
CREATE INDEX idx_readings_device_id_recorded_at_server ON public.environmental_readings(device_id, recorded_at_server DESC);
CREATE INDEX idx_readings_plant_id_recorded_at_server ON public.environmental_readings(plant_id, recorded_at_server DESC);
CREATE INDEX idx_captures_device_id_recorded_at_server ON public.thermal_captures(device_id, recorded_at_server DESC);
CREATE INDEX idx_captures_plant_id_recorded_at_server ON public.thermal_captures(plant_id, recorded_at_server DESC);
CREATE INDEX idx_observations_plant_id ON public.observations(plant_id);
CREATE INDEX idx_observations_user_id ON public.observations(user_id);
CREATE INDEX idx_invitation_codes_created_by_user_id ON public.invitation_codes(created_by_user_id);