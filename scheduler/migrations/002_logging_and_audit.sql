-- 002_logging_and_audit.sql

-- Table for core scheduler system logs
CREATE TABLE IF NOT EXISTS system_logs (
    id SERIAL PRIMARY KEY,
    level TEXT NOT NULL, -- DEBUG, INFO, ERROR
    component TEXT NOT NULL, -- Scheduler, HTTP, IPC, etc.
    message TEXT NOT NULL,
    ts TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Table for job audit logs
CREATE TABLE IF NOT EXISTS job_audit_logs (
    id SERIAL PRIMARY KEY,
    run_id INT REFERENCES program_runs(id) ON DELETE CASCADE,
    message TEXT NOT NULL,
    ts TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Add log_level to scheduler_config
ALTER TABLE scheduler_config ADD COLUMN IF NOT EXISTS log_level TEXT DEFAULT 'INFO';
