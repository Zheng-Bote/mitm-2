# Draft Concept: Man-in-the-Middle (MitM) Data Aggregator

## 1. Goal and Context

**Purpose:** Provision of a reliable, secure, and decoupled system (MitM) that collects data from various source systems, buffers it, aggregates it daily into JSON packages, and transmits it via a REST interface to a target SaaS solution.

**Stakeholders:**

- Source System Owners (Data Provision)
- SaaS Providers (Data Acceptance)
- IT Operations / Admins (Deployment & Monitoring)
- Security & Compliance (Data Privacy)

**Non-Functional Requirements:**

- **SLA & Latency:** Daily asynchronous batch processing. Individual event latency is secondary (24h window).
- **Data Privacy:** **All PII (Personally Identifiable Information) data must be encrypted at-rest** (Envelope Encryption).
- **Throughput:** Scalable to handle millions of fragments per day, aggregated into manageable JSON packages.
- **Availability:** Focus on resilience and retry capabilities rather than 99.999% uptime, as the daily window allows sufficient time for automatic retries.

## 2. Bounded Contexts and Components

- **MitM-Scheduler:** Located in [mitm_scheduler](file:///home/zb_bamboo/DEV/__NEW__/Go/mitm-2/scheduler/mitm_scheduler). Controls and triggers the collection and delivery processes.
- **Collector-Layer:** Responsible for connecting heterogeneous sources (CSV, APIs, DBs) via individual collectors (documented in [collector-layer](file:///home/zb_bamboo/DEV/__NEW__/Go/mitm-2/collector-layer)). Retrieves raw data from these sources.
- **Transformation-Layer:** Located in [transformation-layer](file:///home/zb_bamboo/DEV/__NEW__/Go/mitm-2/transformation-layer). Transforms raw data and performs validation.
- **Delivery-Layer:** Builds packages (aggregating fragments into JSON packages) and sends them to the SaaS target platform, handling rate limits, retries, and DLQ (documented in [delivery-layer](file:///home/zb_bamboo/DEV/__NEW__/Go/mitm-2/delivery-layer)).
- **State (Storage):** Persistently and securely stores progress (cursors) and asynchronously buffered fragments (PostgreSQL database + local storage volume/blob storage).
- **Security:** Cross-cutting component for encryption (Envelope Encryption), key management, and audit logging.

## 3. Interfaces

- **Adapter Interface:** Definition of how pollers read data and transform it into fragments (see Go code artifacts).
- **REST Contract to SaaS:** Transmission via POST request including authentication and idempotency keys.
- **DB Schema:** State management via PostgreSQL (see SQL DDL artifacts).
- **DLQ & Audit:** Tables for undeliverable payloads (DLQ) and a write-only audit log for security-relevant events.

## 4. Data Flow and Workflow

1. **Scheduler triggers Collector:** The [MitM-Scheduler](file:///home/zb_bamboo/DEV/__NEW__/Go/mitm-2/scheduler/mitm_scheduler) starts the respective collector in the **Collector-Layer** (e.g., using a cursor to fetch only new records).
2. **Transformation & Validation:** The raw data is passed to the **Transformation-Layer** (documented in [transformation-layer](file:///home/zb_bamboo/DEV/__NEW__/Go/mitm-2/transformation-layer)) for validation, normalization, encryption (via DEK), and persistence as fragments in the `fragments` table.
3. **Packaging & Delivery:** The **Delivery-Layer** (documented in [delivery-layer](file:///home/zb_bamboo/DEV/__NEW__/Go/mitm-2/delivery-layer)) aggregates pending fragments into JSON packages, persists them in the `packages` table, and sends them to the SaaS REST API.
   - **Success:** Package status is set to `delivered`.
   - **Temporary Error (e.g., 429, 503):** Exponential backoff & retry.
   - **Permanent Error (e.g., 400):** Moved to the DLQ for manual review/replay.
5. **Backfill/Replay:** Administrators can reset cursors or re-inject DLQ entries.

## 5. Deployment and Operation

- **Container Image:** Single binary Go app in a distroless or Alpine image (minimal footprint).
- **Runtime:** Docker containers on the Admin Host (AWS EC2). Can be easily migrated to Kubernetes later.
- **CI/CD:** GitHub Enterprise Server (GHES) Actions for automated builds, tests, and container pushes.
- **Backup Strategy:** **Regular backups of the PostgreSQL database and blob volumes**. The backups must be stored encrypted in AWS S3.
- **Monitoring & Logging:** `prometheus_client` exports `/metrics` (queue sizes, errors). Structured logging in JSON format via `zerolog`.
- **Health Checks:** `/healthz` (app status) and `/readyz` (DB connection, key availability).

## 6. Security and Key Management

- **Envelope Encryption:** Each fragment gets a generated DEK (Data Encryption Key). The DEK is stored encrypted with the KEK (Key Encryption Key / MasterKey).
- **MasterKey Handling:** **The KEK must never be persisted**. It is injected into the container via GHES Secrets as an environment variable or at runtime from AWS Secrets Manager/Vault.
- **TLS:** All external connections (SaaS, AWS services) enforce TLS 1.2+.
- **Audit:** An audit log records key rotations, app starts, and failed authentication attempts.
- **Key Rotation:** The KEK is rotated regularly; existing encrypted DEKs can be re-encrypted with the new KEK in a batch process.

## 7. Toolchain and OSS Libraries (MIT / Apache 2.0)

- **Language:** Go (efficient, type-safe, single-binary).
- **DB Driver:** `github.com/jackc/pgx/v5` (PostgreSQL driver).
- **HTTP Client:** `github.com/hashicorp/go-retryablehttp` (robust retries).
- **Logging:** `github.com/rs/zerolog`.
- **Monitoring:** `github.com/prometheus/client_golang`.
- **Encryption / Ops:** Standard Go `crypto/aes` + `crypto/cipher` (AES-GCM). `sops`/`age` for encrypting infrastructure configurations.

## 8. Risks and Mitigation

| Risk | Mitigation |
| :--- | :--- |
| **Data Privacy / Key Leakage** | Envelope Encryption; KEK in RAM only; no PII in logs. |
| **Schema Drift of Sources** | Versioned collectors; robust fallbacks; DLQ on parsing errors. |
| **SaaS Rate Limits** | Politeness delays; `go-retryablehttp` handles 429s and respects `Retry-After`. |
| **PostgreSQL Concurrency** | **Use a connection pool (e.g., pgxpool) and configure appropriate connection limits.** |

## 9. MVP Roadmap

- **Sprint 0: SaaS API.** Evaluation of SaaS API(s) and their runtime behavior using a prototype uploader.py.
- **Sprint 1: Core & Storage.** Go setup, PostgreSQL schema, Envelope Encryption logic.
- **Sprint 2: Ingest / Collector.** First local CSV collector, cursor management, fragment generation.
- **Sprint 3: Delivery.** Packaging logic, mock SaaS REST client, retries, idempotency headers.
- **Sprint 4: Ops & Sec.** CI/CD GitHub Actions, Prometheus metrics, DLQ handling, documentation.

---

### Security Flow Diagram

1. **Start:** Application starts, retrieves `MASTER_KEY` (KEK) via environment from GHES/Vault into RAM.
2. **Collect:** Collector-Layer retrieves new data from sources.
3. **Transform & Validate:** Transformation-Layer validates and normalizes the data.
4. **DEK Gen:** App generates a random 32-byte DEK (Data Encryption Key) for this fragment.
5. **Encrypt Payload:** Data is encrypted via AES-GCM and DEK (`payload_encrypted`).
6. **Encrypt DEK:** DEK is encrypted via AES-GCM and the `MASTER_KEY` (`encrypted_dek`).
7. **Store:** `payload_encrypted` and `encrypted_dek` are stored in PostgreSQL. DEK is deleted from RAM.
8. **Read & Send:** In the Delivery-Layer, the app reads `encrypted_dek`, decrypts it with the `MASTER_KEY` to retrieve the DEK, decrypts `payload_encrypted` using it, packages the cleartext, and discards the DEK immediately.
8. **Rotate (Optional):** A new `MASTER_KEY` is provided; a batch job decrypts all `encrypted_dek` with the old KEK and encrypts them with the new KEK.

---

## Acceptance Criteria (Checklist)

- [ ] Structure corresponds to arc42 and covers all requested areas.
- [ ] PII data protection through envelope encryption is conceptually anchored.
- [ ] Architecture considers asynchronous retry management and Dead Letter Queues for robust SaaS delivery.
- [ ] The chosen tech stack (Go, PostgreSQL, OSS libraries) consists 100% of open, license-free components.
- [ ] All required artifacts (ERD, DDL, Go spec, CI/CD, prototype) are integrated.
- [ ] The prototype is written in Go, builds on OSS, and demonstrates functional KEK/DEK encryption with PostgreSQL.
- [ ] Key security and operational decisions are highlighted in the text.
