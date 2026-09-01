# Integration Matrix: SpecDD × GitHub Spec Kit for MitM-2

This document defines how architecture specification (SpecDD) and feature specification (GitHub Spec Kit) work together in the `mitm-2` project.

- **SpecDD** → Architecture-First, System-Intent, large modules (Collector, Transformation, Delivery, Scheduler).
- **Spec Kit** → Feature-First, fast iteration, small changes (e.g., a new Collector, a specific mapping rule).

## 1. System Level (SpecDD) vs. Feature Level (Spec Kit)

| Level                       | Artifact                                  | Tool     | Purpose                                 |
| --------------------------- | ----------------------------------------- | -------- | --------------------------------------- |
| **System Intent**           | `.sdd` Specs (Root & Module Level)        | SpecDD   | Architecture, Domain, Security, Layering|
| **System Architecture**     | `architecture.md`, `concept_mitm_aggregator.md` | SpecDD | Orchestration, Envelope Encryption, DB  |
| **System Governance**       | `.sdd` (Must / Must not / Forbids)        | SpecDD   | Security Norms (PII), Buffer Logic      |
| **Feature Intent**          | Feature Spec (Markdown)                   | SpecKit  | Isolated changes (e.g., new API Collector)|
| **Feature Planning**        | Plan Document / Issue                     | SpecKit  | Tasks, Scope, Acceptance Criteria       |
| **Feature Implementation**  | Tasks                                     | SpecKit  | AI-friendly implementation              |
| **Feature Changes**         | Deltas                                    | SpecKit  | Versioning of individual features       |

## 2. Integration Logic (Who Overrides Whom?)

| Area                     | Source  | Rule                                              |
| ------------------------ | ------- | ------------------------------------------------- |
| **Architecture**         | SpecDD  | SpecDD is the _Single Source of Truth_.           |
| **Security (Encryption)**| SpecDD  | SpecKit must not bypass Envelope Encryption.      |
| **Collectors**           | SpecKit | SpecDD defines interface/layer, SpecKit provides specific Collectors (e.g., Kafka, CSV). |
| **Transformations**      | SpecKit | SpecDD defines the mapping engine, SpecKit provides mapping rules. |
| **Delivery / Retry**     | SpecKit | SpecDD defines delivery, SpecKit defines specific Retry/DLQ features. |
| **Persistence Model**    | SpecDD  | SpecKit may add tables for features but not break the core DB structure. |

## 3. Synchronization Rules (Avoiding Drift)

| Situation                       | Action                                  | Tool     |
| ------------------------------- | --------------------------------------- | -------- |
| New Feature (e.g., Collector)   | SpecKit Spec → Tasks → Implement        | SpecKit  |
| Feature affects Architecture    | SpecKit feature forces `.sdd` update    | SpecDD   |
| Architecture Change             | SpecDD → derive new SpecKit features    | SpecKit  |
| Conflict between Specs          | SpecDD wins                             | SpecDD   |
| New Norms (e.g., Logging)       | Update SpecDD → adjust SpecKit          | Both     |

## 4. Artifact Mapping for MitM-2

| MitM-2 Area     | SpecDD                      | Spec Kit                            |
| --------------- | --------------------------- | ----------------------------------- |
| **Collector**   | ✔ Layer Design, Interfaces  | ✔ New Kafka Collector, ORA Update   |
| **Transform**   | ✔ Validation & Rules Engine | ✔ JSON Mapping, Custom Filter       |
| **Delivery**    | ✔ SaaS REST Integration     | ✔ Payload Assembling Adjustment     |
| **Security**    | ✔ Envelope (AES-GCM) Design | ✔ Feature-Level Security Checks     |
| **Storage**     | ✔ PostgreSQL Pooling & Schema | ✔ Feature-Specific Tables         |
| **Scheduler**   | ✔ Orchestration, IPC        | ✔ New Cron Job Parameter            |

## 5. Integration Matrix

| Category                | SpecDD | Spec Kit |
| ----------------------- | ------ | -------- |
| System Intent           | ✔      | ✖        |
| Architecture            | ✔      | ✖        |
| Governance / Security   | ✔      | ✖        |
| Feature Intent          | ✖      | ✔        |
| Feature Planning        | ✖      | ✔        |
| Feature Implementation  | ✖      | ✔        |
| Drift Control           | ✔      | ✔        |

## 6. Code Quality & Standards Baseline

All Spec Kit features MUST adhere to the strict baseline standards defined in `mitm-2.sdd` and `GEMINI.md`. AI agents and developers must not generate code that violates these:
- **Language:** All code documentation and comments must be in English.
- **Licensing:** Every source file must include the standardized SPDX header (C++ style block comment) with Apache-2.0 license.
- **Modularity:** Each layer component is compiled as an independent Go binary with its own `go.mod`.
- **Secrets:** The Master Key (KEK) is never persisted to disk; child processes dynamically fetch it via the IPC Unix Socket.
