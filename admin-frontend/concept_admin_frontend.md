# Admin Frontend Concept: MitM Data Aggregator

The Admin Frontend for the **MitM Data Aggregator** serves as a central "Control Plane" to make the system's decoupling, security, and asynchronous processes manageable. Since the frontend does not process data itself, it focuses on configuration, monitoring, and troubleshooting.

---

## 1. Technology Decision: Go/Fyne vs. C++23/Qt6

Both options have strong arguments, but they suit different orientations:

### Option A: Go with Fyne (Recommended for a Homogeneous Codebase)
*   **Pro:** Massively reusable code (API models, constants, validation logic). The toolchain (`go build`) stays identical across the entire project. It is lightweight.
*   **Con:** Fyne draws its own UI elements (no 100% native Windows look), and integrating with low-level Windows APIs (such as Windows Hello) requires some boilerplate via `golang.org/x/sys/windows` or CGO.

### Option B: C++23 with Qt6 (The "Premium Desktop" Variant)
*   **Pro:** Qt6 (especially Qt Quick/QML or QtWidgets) offers extremely powerful data grids for complex tables (e.g., for mapping rules or DLQ inspections). Integration with the **Windows Biometric Framework (WBF)** or WinRT APIs for Windows Hello is native and trivial in C++.
*   **Con:** Hard context switch for developers (Go backend, C++ frontend), more complex build system (CMake), and all REST API models must be re-implemented in C++.

**Architecture Tip:** If native Windows Hello integration is the absolute killer feature and complex tables are required, **C++23 with Qt6** wins. If maintainability and a homogeneous codebase are the priority, **Go with Fyne** wins.

---

## 2. Architectural Concept & Security

Most important up front: **The frontend never talks directly to the PostgreSQL database!**

1.  **API-Driven:** The frontend communicates exclusively via the `mitm_scheduler`'s REST API (e.g., `/api/v1/jobs`, `/api/v1/dlq`).
2.  **The Windows Hello Handshake (Security Flow):**
    *   The admin launches the desktop app (e.g., `.exe`).
    *   The app triggers **Windows Hello** (facial recognition / fingerprint / PIN).
    *   Only after a successful Hello prompt does the app decrypt a locally stored API token or `MASTER_KEY` (KEK) saved in the **Windows Credential Manager** (vault).
    *   The app uses this token to perform the HELO handshake with the scheduler and establish the session.
3.  **Local Encryption:** When sensitive data (such as new database passwords) is configured in the frontend, the frontend can encrypt it in RAM before sending it to the scheduler via the API.

---

## 3. UI/UX Layout & Navigation (Module Structure)

A modern **Master-Detail layout** (sidebar on the left for navigation, content area on the right) with a dark mode as default is recommended.

Here are the 5 primary modules the frontend should cover:

### A. 📊 Dashboard (System Health)
*   A quick overview: Are the scheduler services running?
*   Small graphs/metrics (e.g., "Successful deliveries today: 14,500", "Failed validations: 12").
*   A red indicator if the Dead Letter Queue (DLQ) is growing.

### B. ⏱️ Job & Scheduler Management
*   **Grid/List:** All configured jobs (PostgreSQL Collector, Oracle Collector, Transformer, Deliverer).
*   **Detail View:** Edit cron expressions (e.g., `0 2 * * *`), adjust JSON arguments (`os.Args[1]`) with syntax highlighting and direct validation (schema check).
*   **Actions:** Buttons for "Force Run Now", "Pause Job", or "View Logs" (real-time tail via WebSockets or polling from the IPC log).

### C. 🧩 Mapping & Rule Editor
*   The most complex UI element: An interface to maintain the dynamic transformation and validation rules (`raw_ingestion` -> `target`).
*   A visual mapping interface could be built here (column A from the source maps to column B in the target, with a function like `to_upper` or `regex_replace` in between).
*   In Qt6, this could be excellently implemented using a node-based editor (QGraphicsScene) or nested tables.

### D. 🚑 Dead Letter Queue (DLQ) & Cursor Inspector
*   **DLQ Viewer:** A table view of failed records from `transformation_errors` and `dead_letter_queue`.
*   An admin can inspect the raw JSON payload, analyze the error ("HTTP 400" or "Regex Mismatch"), edit the payload directly in the frontend, and press a "Requeue / Retry" button.
*   **Cursor Management:** A list of current ingestion cursors (e.g., "Last read Employee ID: 5902") that an admin can manually reset if a full load needs to be enforced.

### E. ⚙️ Settings & Key Vault
*   Management of target adapters (SaaS, APIGEE).
*   Input form for the `MASTER_KEY` or certificates, if they need to be pushed to the scheduler at runtime.
*   This view requires a mandatory re-prompt of Windows Hello before entering (re-authentication).

---

## Conclusion
A frontend in C++23/Qt6 would give the project an absolute "Enterprise Desktop" character, since it is extremely performant and can seamlessly integrate native Windows security features (WBF, Credential Store). The separation between frontend (desktop app) and backend (scheduler API) ensures the frontend remains stateless and secure.
