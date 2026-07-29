# Architecture Overview - Go Scheduler

This document provides a high-level overview of the **Go Scheduler** architecture using the C4 model.

Go Scheduler is a Linux system service designed to manage, execute, and monitor external Go programs (or other executables) on a cron-based schedule. It stores configurations, execution histories, and logs in a PostgreSQL database, communicates with jobs via a UNIX Domain Socket (JSON-Lines IPC), and offers a REST API + desktop GUI for remote administration.

---

## 1. C4 System Context Diagram

The System Context diagram shows how the Go Scheduler system interacts with users (Administrators), the host operating system, and the external job binaries it executes.

```mermaid
flowchart TB
    admin["Admin User\n(System Administrator)"]
    os["Linux OS\n(Host Environment)"]

    subgraph system_boundary ["Go Scheduler System Boundary"]
        scheduler_sys["Go Scheduler\n(Core scheduler & API)"]
        gui_app["Scheduler Admin GUI\n(Desktop Application)"]
    end

    jobs["External Job Binaries\n(job1, job2, etc.)"]
    db[("PostgreSQL Database\n(Job configuration, runs, logs)")]

    admin -->|"Manages jobs & views status"| gui_app
    gui_app -->|"REST API / Basic Auth"| scheduler_sys
    os -->|"Launches with encrypted config"| scheduler_sys
    scheduler_sys -->|"Spawns & monitors processes"| jobs
    jobs -->|"IPC events (Unix Socket)"| scheduler_sys
    scheduler_sys -->|"Persists state & reads config"| db

    classDef actor fill:#112233,stroke:#334455,stroke-width:2px,color:#fff;
    classDef system fill:#005599,stroke:#0077cc,stroke-width:2px,color:#fff;
    classDef ext fill:#444444,stroke:#666666,stroke-width:2px,color:#fff;

    class admin,os actor;
    class scheduler_sys,gui_app system;
    class jobs,db ext;
```

---

## 2. C4 Container Diagram

The Container diagram drills down into the Go Scheduler System, showing its internal containers, technology choices, and how they communicate.

```mermaid
flowchart TB
    admin["Admin User\n(System Administrator)"]

    subgraph gui_container ["Scheduler Admin GUI (Desktop Container)"]
        gui["Fyne GUI Application\n[Go / Fyne v2]\nAllows administrators to view runs, add/edit/delete jobs, and authenticate."]
        win_hello["Windows Hello / WinRT Bindings\n[Go / COM / WinRT]\nBiometric local authorization step (Windows-specific)."]
        gui -.->|"Local Biometric Check"| win_hello
    end

    subgraph scheduler_container ["Go Scheduler Service (Backend Container)"]
        config_loader["Config Loader & Decryptor\n[Go / crypto]\nLoads config.json.enc using AES-256-GCM + Argon2id."]
        cron_engine["Cron Scheduler\n[Go / robfig/cron/v3]\nManages and triggers job configurations loaded from the DB."]
        ipc_server["IPC Unix Socket Server\n[Go / net]\nListens on UNIX socket, processes JSON-Lines status/audit events."]
        http_server["REST API Server\n[Go / net/http]\nExposes health check, info, and basic auth admin endpoints."]
    end

    db[("PostgreSQL Database\n[PostgreSQL 14+]\nStores jobs, execution history, logs, and configurations.")]

    jobs["External Job Binaries\n[Any executable / Go]\nProcesses spawned by Cron Engine; send progress/audit via UNIX socket."]

    %% Interactions
    admin -->|"Uses"| gui
    gui -->|"HTTPS/HTTP REST (Basic Auth)"| http_server
    config_loader -->|"Loads DSN details"| db
    cron_engine -->|"Reads enabled jobs"| db
    cron_engine -->|"Creates runs / spawns"| jobs
    jobs -->|"Writes JSON-Lines status & audits"| ipc_server
    ipc_server -->|"Stores logs / runs / status"| db
    http_server -->|"Triggers reload"| cron_engine
    http_server -->|"Reads & modifies configurations"| db

    classDef container fill:#0066cc,stroke:#0088ff,stroke-width:2px,color:#fff;
    classDef component fill:#0088cc,stroke:#00aaff,stroke-width:1px,color:#fff;
    classDef db fill:#004488,stroke:#0055aa,stroke-width:2px,color:#fff;
    classDef ext fill:#444444,stroke:#666666,stroke-width:2px,color:#fff;
    classDef actor fill:#112233,stroke:#334455,stroke-width:2px,color:#fff;

    class gui,http_server,ipc_server,cron_engine container;
    class config_loader,win_hello component;
    class db db;
    class jobs ext;
    class admin actor;
```

---

## 3. Documents Directory Structure

The architectural details are split into specific focus areas:

- [System Components](system_components.md): Deep-dive into each internal package and command implementation.
- [Database Schema](database_schema.md): Details the PostgreSQL schema, table layouts, and relationships.
- [Data Flow & Sequence](data_flow.md): Traces how events flow through the system during job execution, admin reloads, and configurations.
