# SpecDD user-local overrides

# Project: Man-in-the-Middle (MitM) Data Aggregator

## Project Overview

The **MitM Data Aggregator** is a layered system designed to securely and reliably collect data from various source systems (CSV, APIs, SQL), buffer it locally, and aggregate it into JSON packages for daily delivery to a target SaaS platform via REST API.

**Key Technologies:**

- **Language:** Rust: for core-layer
- **Language:** Go: for collector-layer, delivery-layer, maintencance-layer
- **Language:** C++26: for Desktop-Clients
- **Language:** Angular: for Web-Frontends
- **Storage:** PostgreSQL (central database layer for state management and fragment buffering).
- **Security:** Envelope Encryption (AES-GCM) for PII data protection at rest (MasterKey/KEK in RAM, individual DEKs in DB).
- **Security:** Argon2id for passwords
- **Pattern:** Layered architecture (Collector, Transformation, Delivery, Maintenance) orchestrated by Core (HTTP, IAM, Scheduler).

## Building and Running

static Go binaries, static Rust binaries.

### Commands

- **Build:** `go build -o bin/mitm-server ./cmd/server`
- **Test:** `go test ./...`
- **Run Server:** `MASTER_KEY=$(openssl rand -base64 32) ./bin/mitm-server`
- **Monitoring:**
  - Metrics: `curl http://localhost:8080/metrics`
  - Health: `curl http://localhost:8080/healthz`
  - Ready: `curl http://localhost:8080/readyz`

## Key Files & Directories

### Documentation

```tree
docs
├── Admin-frontend
├── Architecture
├── Collector-layer
├── Core-layer
├── Delivery-layer
├── Maintenance-layer
├── Overview
├── Scheduler
├── Storage-layer
└── Transformation-layer
```

### Project Structure: Monorepo with sub-projects (different Githubrepositories):

```tree
mitm-2
├── admin-frontend
│   ├── mitm_fe_cpp
|   |── mitm_fe_web
├── core-layer
│   ├── mitm_core_http
│   ├── mitm_core_iam
│   ├── mitm_core_scheduler
├── collector-layer
│   ├── mitm_collector_csv-xls
│   ├── mitm_collector_employee_ora
│   ├── mitm_collector_employee_pg
|   |── mitm_collector_employee-tmp-assigns_ora
│   ├── mitm_collector_kafka
|   |── mitm_collector_mft
|   |── mitm_collector_ora
│   ├── mitm_collector_pg
├── delivery-layer
│   ├── mitm_delivery_apigee
│   ├── mitm_delivery_cority
├── maintenance-layer
│   ├── mitm_adm-data-debug
│   ├── mitm_maintenance_cleanup
└── transformation-layer
    ├── mitm_transformation_main
```

## Development Conventions

- **Language:** Strictly Go or Rust for the core aggregator.
- **Documentation:** All code documentation and comments must be in **English**.
- **File Headers:** Every source file must include a standardized SPDX header (C++ style).
  Example:

  ```header
  /**
   * SPDX-FileComment: [Component Name]
   * SPDX-FileType: SOURCE
   * SPDX-FileContributor: ZHENG Robert
   * SPDX-FileCopyrightText: [YYYY] ZHENG Robert
   * SPDX-License-Identifier: Apache-2.0
   *
   * @file [filename].go
   * @brief [Brief description]
   * @version [semantic version]
   * @date [YYYY-MM-DD]
   *
   * @author ZHENG Robert (robert @hase-zheng.net)
   * @copyright Copyright (c) [YYYY] ZHENG Robert
   * @LICENSE Apache-2.0
   */
  ```

- **Security First:** Never persist the Master Key (KEK). Use environment variables or Secrets Manager.
- **Resilience:** Implement robust retries with exponential backoff for external API calls.
- **Logging:** Structured JSON logging using `zerolog`.
- **Metrics:** Prometheus exporter for monitoring.
- **PostgreSQL:** Utilize connection pools and transaction boundaries for concurrency and reliability.

## Instructional Guidance

- Follow instructions in the AGENTS.md file.
- Follow the architectural patterns defined in [architecture.md](docs/Architecture/architecture.md).
- Define database migrations inside the respective `migrations/` subfolder of each layer.
