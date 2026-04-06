BEGIN;

-- Align legacy column names with the ORM model used by FastAPI.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'patient_allergies'
          AND column_name = 'substance_name'
    ) AND NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'patient_allergies'
          AND column_name = 'allergen'
    ) THEN
        ALTER TABLE public.patient_allergies
            RENAME COLUMN substance_name TO allergen;
    END IF;
END $$;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'patient_allergies'
          AND column_name = 'noted_by_doctor_id'
    ) AND NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'patient_allergies'
          AND column_name = 'doctor_id'
    ) THEN
        ALTER TABLE public.patient_allergies
            RENAME COLUMN noted_by_doctor_id TO doctor_id;
    END IF;
END $$;

ALTER TABLE public.patient_allergies
    ADD COLUMN IF NOT EXISTS notes TEXT;

-- Normalize legacy severity values before tightening defaults/constraints.
UPDATE public.patient_allergies
SET severity = CASE
    WHEN severity IS NULL OR BTRIM(severity) = '' THEN 'moderate'
    WHEN LOWER(BTRIM(severity)) IN ('low', 'medium', 'moderate', 'high', 'critical') THEN LOWER(BTRIM(severity))
    ELSE 'moderate'
END;

ALTER TABLE public.patient_allergies
    ALTER COLUMN severity SET DEFAULT 'moderate';

ALTER TABLE public.patient_allergies
    ALTER COLUMN severity SET NOT NULL;

ALTER TABLE public.patient_allergies
    DROP CONSTRAINT IF EXISTS patient_allergies_severity_check;

ALTER TABLE public.patient_allergies
    ADD CONSTRAINT patient_allergies_severity_check
    CHECK (severity IN ('low', 'medium', 'moderate', 'high', 'critical'));

CREATE INDEX IF NOT EXISTS patient_allergies_doctor_id_idx
    ON public.patient_allergies (doctor_id);

COMMIT;
