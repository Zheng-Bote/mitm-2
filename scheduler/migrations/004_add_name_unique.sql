-- 004_add_name_unique.sql

-- Drop the constraint if it exists to avoid errors on duplicate application
ALTER TABLE scheduled_programs DROP CONSTRAINT IF EXISTS scheduled_programs_name_key;

-- Add a unique constraint to the 'name' column in 'scheduled_programs' table
-- to support INSERT ... ON CONFLICT (name) syntax.
ALTER TABLE scheduled_programs ADD CONSTRAINT scheduled_programs_name_key UNIQUE (name);
