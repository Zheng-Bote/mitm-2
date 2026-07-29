# Data Flow & Sequences - Go Scheduler

This document visualizes the runtime interactions and sequences of operations in Go Scheduler.

---

## 1. Job Execution & IPC Lifecycle

When the Cron Engine triggers a scheduled program, the following sequence details the process execution, environment injection, and socket communication:

```mermaid
sequenceDiagram
    autonumber
    participant C as Cron Engine (robfig/cron)
    participant S as Scheduler Service
    participant DB as PostgreSQL Database
    participant J as Job Child Process
    participant IPC as IPC Socket Server

    C->>S: Trigger Job (Cron Expression matches)
    activate S
    S->>DB: Create Program Run (CreateProgramRun)
    DB-->>S: Return run_id
    S->>J: Spawn Command with env (RUN_ID=run_id, SCHEDULER_SOCKET_PATH=uds_path)
    S->>DB: Update run record with PID
    deactivate S

    activate J
    J->>IPC: Send Event (Status="started", Progress=0)
    IPC->>DB: Save status event in job_status_events
    
    Note over J, IPC: Custom program work logic
    J->>IPC: Send Event (Type="audit", Message="sensitive op")
    IPC->>DB: Save audit record in job_audit_logs

    J->>IPC: Send Event (Status="finished", Progress=100)
    IPC->>DB: Save status event in job_status_events
    deactivate J

    Note over S, J: Scheduler waits in goroutine for process exit
    S->>DB: Update Program Run exit code & success status (UpdateProgramRun)
```

### Key Stages:
1.  **Trigger**: The `robfig/cron/v3` scheduler fires based on the cron syntax in database.
2.  **Tracking Reservation**: The scheduler registers a run instance prior to launching the binary. This generates a unique `run_id`.
3.  **Process Isolation**: The program starts as a standalone process. It reads `RUN_ID` and `SCHEDULER_SOCKET_PATH` variables from its environment.
4.  **IPC (Unix Socket)**: The program dials the local socket streaming JSON-lines.
5.  **Termination Update**: Regardless of whether the process finishes cleanly or crashes, Go's `cmd.Wait()` detects the exit state, which is stored in the database.

---

## 2. Job Updates & Config Reloading

When an administrator edits, creates, or deletes job schedules via the desktop admin tool, this sequence shows the authentication flow and scheduler rebuild process:

```mermaid
sequenceDiagram
    autonumber
    participant A as Admin User
    participant G as Admin GUI (scheduler-admin)
    participant H as HTTP REST Server
    participant DB as PostgreSQL Database
    participant S as Scheduler Service
    participant C as Cron Engine

    A->>G: Save or Delete Job
    activate G
    Note over G: On Windows: Triggers WinRT Windows Hello prompt
    G->>H: REST Call (HTTP Basic Auth: User + Token)
    activate H
    H->>H: Verify headers against decrypted config
    
    alt Authentication Failed
        H-->>G: HTTP 401 Unauthorized
    else Authentication Success
        H->>DB: Upsert / Delete job configuration in DB
        H->>S: Call Reload(ctx)
        activate S
        S->>C: Stop() Current Scheduler
        S->>C: Initialize Fresh Cron Engine
        S->>DB: GetEnabledPrograms()
        DB-->>S: Return active job array
        S->>C: AddFunc() job schedules
        S->>C: Start() Cron Engine
        deactivate S
        H->>DB: LogAdminAction() (Audit Trail)
        H-->>G: HTTP 200 OK
    end
    deactivate H
    G-->>A: Refresh view & display success/error
    deactivate G
```

### Key Stages:
1.  **Biometric Authorization (Windows-Specific)**: Prior to invoking the network stack, the GUI prompts Windows Hello. It uses `UserConsentVerifier` to execute biometrics locally.
2.  **Basic Authentication**: The HTTP API server authenticates requests against admin records (loaded from `config.json.enc`).
3.  **Hot-Reloading**: The Cron scheduler is stopped, rebuilt, and restarted. Enabled jobs are re-read from the DB. There is no service restart required, ensuring zero disruption to existing running jobs.
4.  **Audit Logs**: The administrative event, who performed it, and what changed are serialized as JSON and written to `admin_audit_logs` for tracking.
