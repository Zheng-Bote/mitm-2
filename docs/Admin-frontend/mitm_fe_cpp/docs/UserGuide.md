# MitM Data Aggregator - Admin Frontend User Guide

Welcome to the **Admin Frontend** for the Man-in-the-Middle (MitM) Data Aggregator pipeline! 

This native desktop application is built with modern **C++23** and **Qt 6**, designed to provide a highly responsive, secure, and user-friendly interface for monitoring and orchestrating the entire MitM data ingestion and delivery pipeline.

---

## 1. Overview & Architecture

The MitM Admin Frontend acts as the control panel for the Go-based Scheduler engine. It does not manipulate the PostgreSQL database directly. Instead, it communicates via secure **HTTP REST APIs** exposed by the Scheduler component.

### Security and Authentication
To ensure zero-trust security, the frontend uses a transparent authentication mechanism:
1. It queries your active Operating System user (`USER` on Linux, `USERNAME` on Windows).
2. It cross-references your username against the `admins` block within the centralized `data/config.json`.
3. If a match is found, the system securely extracts the corresponding authentication token (e.g., Windows Hello or Linux PAM integrated tokens) and passes it via HTTP Basic Authentication to the backend API.

---

## 2. Navigating the Interface

The application is divided into several domain-specific tabs, allowing you to manage different layers of the MitM pipeline.

### 📊 Dashboard
The **Dashboard** provides a high-level, real-time overview of the system's health.
- **System Health**: Indicates whether the backend Scheduler is online and connected to the underlying PostgreSQL database.
- **Engine Info**: Displays the currently running engine name and semantic version.
- **Total Scheduled Jobs**: A quick counter of how many extraction/transformation jobs are registered in the pipeline.
- *Usage:* Click the **Refresh Dashboard** button to poll the latest live data from the backend.

### ⏱️ Scheduler
The **Scheduler** tab is the heart of the orchestration layer. It lists all `ScheduledPrograms` configured in the system.
- **Table View:** See exactly which jobs are configured, their execution command, cron schedules, and whether they are currently enabled or disabled.
- **+ Add Job:** Opens the Job Editor dialog to register a new binary or script for execution. 
- **Edit Selected:** Allows you to modify a selected job.
  - *Cron Editor:* Instead of manually typing complex cron strings (e.g. `*/15 * * * *`), the editor provides 5 dedicated dropdown menus (Minute, Hour, Day, Month, Weekday) making schedule management highly intuitive.
- **Delete Selected:** Removes a job entirely from the pipeline (requires confirmation).

### 📜 System Logs
The **System Logs** tab provides a diagnostic view into the Scheduler's internal operations.
- **Table View:** Displays logs with severity levels (`INFO`, `ERROR`, `DEBUG`), the reporting component (e.g., `HTTP`, `IPC`, `Scheduler`), and the timestamp.
- **Sorting:** Click on any column header (like "Level" or "Timestamp") to sort the data ascending or descending.
- **Export CSV:** Click the "Export CSV" button in the toolbar to save the current log view directly to your disk for external auditing or archiving.

### 🕵️ Audit Logs
The **Audit Logs** tab focuses on security and execution traceability.
- **Traceability:** It maps specific actions and events directly to a `Run ID` (the unique identifier for a single job execution).
- **Admin Actions:** Records all UI-driven configuration changes (add/edit/delete in the Transformation layer), as well as the **frontend_startup** event, capturing the user, OS, and software version.
- **Export CSV:** Similar to system logs, all audit logs can be exported to CSV.

### 🧩 Rules & Mapping
The **Transformation Layer** tab allows you to configure source systems, target fields, and the mapping rules linking them.
- **Purpose:** Allows administrators to define dynamic mapping rules between source column formats (e.g., legacy CSV headers) and target JSON keys without modifying code.
- **✨ Auto-Map (Smart Suggest):** A powerful tool to automatically generate `MappingRules`. By selecting a source and providing a comma-separated list of your raw column headers, the system uses Levenshtein distance (fuzzy string matching) to automatically link them to the most appropriate Target Fields in the database, saving significant manual configuration time.

### 🚑 DLQ & Cursors (Preview Concept)
*Note: This tab is currently a conceptual preview.*
- **Purpose:** Will serve as the primary interface for managing the **Dead Letter Queue**. If a payload fails to deliver to the target SaaS platform (due to validation errors or API downtime), it will appear here. Administrators will be able to inspect the failed payload and click "Requeue Selected" to attempt delivery again.

### ⚙️ Settings & Key Vault (Preview Concept)
*Note: This tab is currently a conceptual preview.*
- **Purpose:** Manages the Envelope Encryption framework. You will use this tab to input the master Key Encryption Key (`MASTER_KEY`) or unlock it via biometrics (Windows Hello) to initialize the secure context for PII data decryption.

---

## 3. Keyboard Shortcuts and Tips

- **Sorting Data:** You can click the column headers in any of the Log tables to easily sort by Date or Error Level.
- **Window Resizing:** The UI is completely responsive. Stretching the window will automatically allocate more space to payload or message columns.
- **Selecting Items:** In the Scheduler tab, you must click a specific row to highlight it before clicking "Edit" or "Delete".

## 4. Troubleshooting
- **API Errors / Red Status:** If the Dashboard shows a red `Offline` or `Auth Error` status, verify that the Go Scheduler backend is currently running on `localhost:8080` and that your exact OS Username is configured within the `data/config.json` admins array.
