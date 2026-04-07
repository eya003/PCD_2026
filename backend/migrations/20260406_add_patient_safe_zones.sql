-- Safe zone configuration for family admin (phase 1)
-- One row per patient.

CREATE TABLE IF NOT EXISTS patient_safe_zones (
    patient_id INTEGER PRIMARY KEY
        REFERENCES patients(id) ON DELETE CASCADE,
    origin_latitude DOUBLE PRECISION NOT NULL
        CHECK (origin_latitude >= -90 AND origin_latitude <= 90),
    origin_longitude DOUBLE PRECISION NOT NULL
        CHECK (origin_longitude >= -180 AND origin_longitude <= 180),
    radius_meters DOUBLE PRECISION NOT NULL
        CHECK (radius_meters > 0),
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by INTEGER NULL
        REFERENCES users(id) ON DELETE SET NULL
);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'patient_safe_zones_origin_latitude_check'
    ) THEN
        ALTER TABLE patient_safe_zones
            ADD CONSTRAINT patient_safe_zones_origin_latitude_check
            CHECK (origin_latitude >= -90 AND origin_latitude <= 90);
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'patient_safe_zones_origin_longitude_check'
    ) THEN
        ALTER TABLE patient_safe_zones
            ADD CONSTRAINT patient_safe_zones_origin_longitude_check
            CHECK (origin_longitude >= -180 AND origin_longitude <= 180);
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'patient_safe_zones_radius_meters_check'
    ) THEN
        ALTER TABLE patient_safe_zones
            ADD CONSTRAINT patient_safe_zones_radius_meters_check
            CHECK (radius_meters > 0);
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS ix_patient_safe_zones_updated_by
    ON patient_safe_zones(updated_by);
