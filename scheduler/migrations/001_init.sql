-- 001_init.sql

-- Table for scheduled programs (jobs)
CREATE TABLE IF NOT EXISTS scheduled_programs (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    command TEXT NOT NULL,
    args JSONB DEFAULT '{}'::jsonb,
    cron_expr TEXT NOT NULL,
    enabled BOOLEAN DEFAULT true,
    restart_on_exit BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Table for tracking program execution runs
CREATE TABLE IF NOT EXISTS program_runs (
    id SERIAL PRIMARY KEY,
    program_id INT REFERENCES scheduled_programs(id) ON DELETE CASCADE,
    pid INT,
    started_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    finished_at TIMESTAMPTZ,
    exit_code INT,
    success BOOLEAN
);

-- Table for IPC status events from jobs
CREATE TABLE IF NOT EXISTS job_status_events (
    id SERIAL PRIMARY KEY,
    run_id INT REFERENCES program_runs(id) ON DELETE CASCADE,
    status TEXT,
    message TEXT,
    progress INT,
    ts TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Table for global scheduler configuration
CREATE TABLE IF NOT EXISTS scheduler_config (
    id SERIAL PRIMARY KEY,
    http_port INT DEFAULT 8080,
    socket_path TEXT DEFAULT '/tmp/scheduler.sock'
);

-- Insert default config if not exists
INSERT INTO scheduler_config (http_port, socket_path)
SELECT 8080, '/tmp/scheduler.sock'
WHERE NOT EXISTS (SELECT 1 FROM scheduler_config);
