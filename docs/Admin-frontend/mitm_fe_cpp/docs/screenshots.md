# MitM Admin Frontend - Screenshots

This document showcases the graphical user interface of the **MitM Data Aggregator Admin Frontend** when running on a Linux or Windows desktop environment.

> [!NOTE]\
> This page is work in progress, content will be updated.

### 1. Application Startup

The initial prompt asking the user for the master password to decrypt the secure `config.enc` file via libsodium.

![Application Startup](screenshots/linux/01.png)

### 2. Dashboard View

The main dashboard displaying real-time system metrics, scheduler health, and an overview of active jobs.

**startup** (Windows screenshot)

![Dashboard View - startup](screenshots/win11/02.png)

**running** (Linux screenshot)

![Dashboard View - Running](screenshots/linux/05.png)

### 3. Network Proxy Setup

The per-user proxy configuration dialog accessible via the Settings menu, allowing secure HTTP/HTTPS proxy overrides.
![Network Proxy Setup](screenshots/linux/03.png)

### 04. About Dialog

The "About" dialog displaying the current version, copyright information, and automatically checking for updates on GitHub.

![About Dialog](screenshots/linux/04.png)

### 5. Scheduler Overview

The Scheduler tab listing all currently configured jobs, their cron schedules, and their last execution statuses.
![Scheduler Overview](screenshots/linux/06.png)

### 6. Job Editor & Cron

**Editing an existing job**, featuring the interactive Cron Expression editor for precise scheduling.
![Job Editor](screenshots/linux/07.png)

**Add Job**

![Add Job](screenshots/linux/08.png)

### 5. System Logs

The System Logs tab providing real-time log streaming from the backend with filtering capabilities. Columns are sortable. Log can be exported to a CSV file.
![System Logs](screenshots/linux/09.png)

### 6. Audit Logs

Detailed audit logs tracking job execution histories and system changes. Columns are sortable. Log can be exported to a CSV file.
![Audit Logs](screenshots/linux/10.png)

### 7. Rules & Mapping

The interface for defining and managing data transformation rules and field mappings. Columns are sortable.
![Rules and Mapping](screenshots/linux/11.png)

### 8. DLQ & Cursors

Monitoring the Dead Letter Queue (DLQ) for failed messages and managing system cursors.
![DLQ and Cursors](screenshots/linux/12.png)

### 9. Settings & Key Vault

Configuration interface for securely injecting the Envelope Encryption master keys and managing backend connections.
![Settings and Key Vault](screenshots/linux/13.png)
