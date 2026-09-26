# AI Agent Instructions: SpecDD × GitHub Spec Kit Workflow

This document breaks down the guidelines from `docs/SDD-Howto_en.md` and `docs/SpecDD_SpecKit_Integration_EN.md` into concrete, executable process steps for AI agents. It serves as a practical guide for feature development in the `mitm-2` project.

## 1. Role Distribution & Hierarchy

- **SpecDD (`.sdd`) = The Constitution:** Single Source of Truth for architecture, security (Envelope Encryption, PII), databases, and layering. Changes rarely. Must **not** be violated by features.
- **Spec Kit (Markdown) = The Work Order:** Flow-Forward feature development (e.g., new Collector, new mapping). Iterative, detailed, and focused on a specific goal.

## 2. The Agentic Workflow (Flow-Forward)

AI agents process features sequentially according to the following pattern to prevent code drift:

### Step 1: Specify (Requirements)
*   **Trigger:** `/speckit.specify`
*   **AI Action:**
    *   Create a feature branch (e.g., `feature/ticket-123`).
    *   Determine the storage location for the Spec Kit:
        *   Cross-Layer (affects multiple repos): `specs/features/<name>/` in the root repo.
        *   Isolated (affects one repo): `specs/` in the respective component repo.
    *   **Result:** A Markdown feature spec with clear acceptance criteria (PRD).

### Step 2: Plan (Design & Architecture Check)
*   **Trigger:** `/speckit.plan`
*   **AI Action:**
    *   **Resolve Spec Chain:** Identify the *Target Path* (Scope) of the feature (e.g., `core-layer/mitm_http-server/`).
    *   Read the spec chain hierarchically from root (`mitm-2.sdd`) through the respective layer (including architecture and security specs linked via `References`) down to the local component.
    *   **Architecture Check:** Validate the feature design against all inherited constraints (Are layer boundaries respected? Are inherited `Must not` rules regarding PII or DB pooling violated?).
    *   **Result:** An architecture plan (Technical Spec) that strictly designs the "how" within the inherited SpecDD boundaries (Scope & Authority).

### Step 3: Tasks (Define Work Packages)
*   **Trigger:** `/speckit.tasks`
*   **AI Action:**
    *   Break down the plan into atomic work packages (Tasks).
    *   **Mandatory:** Every task MUST explicitly name the affected repository/module (e.g., code change in `collector-layer/mitm_collector_pg`).
    *   **Mandatory:** Observe ordering: Interfaces & contracts first.
    *   **Result:** An ordered list of sequentially executable Agent Tasks.

### Step 4: Implement (Generate Code)
*   **Trigger:** `/speckit.implement`
*   **AI Action:**
    *   Execute the next open task.
    *   Write code and add tests.
    *   **Code Standard Check (Mandatory Quality Gate for AI):**
        *   [ ] Are documentation and comments in English?
        *   [ ] Does every source code file have the SPDX header (Apache-2.0)?
        *   [ ] Are secrets (Master Key / KEK) kept exclusively in RAM (obtained via IPC) and never written to disk?
        *   [ ] Does the module remain independent (with its own `Cargo.toml`/`go.mod`)?
    *   **Result:** Code deltas for review.

### Step 5: Converge (Review & Iteration)
*   **Trigger:** `/speckit.converge`
*   **AI Action:**
    *   Compare the ACTUAL state (Code) with the TARGET state (Spec Kit Feature Spec + SpecDD `.sdd` rules).
    *   Verification: Is error handling missing? Are edge cases missing? Were security norms forgotten?
    *   If incomplete: Generate new tasks, append to the task list, and return to *Implement*.
    *   If complete: Feature is logically finished.

### Step 6: Release (Completion)
*   **AI Action:**
    *   Update `CHANGELOG.md` in all affected components.
    *   Preparation for Push & Pull Request.

---

## 3. Artifact and Lifecycle Overview

This matrix combines the abstract development cycle with concrete SpecKit commands and artifacts:

| Phase | AI Command | Main Artifact | AI Quality Gate (Check) | Result |
| :--- | :--- | :--- | :--- | :--- |
| **1. Intake & Requirements** | `/speckit.specify` | Feature Spec (Markdown) | Problem, Scope, User & Non-Goals are clearly defined and testable. | AI knows *what* to implement. |
| **2. Design & Architecture** | `/speckit.plan` | Architecture Design | Alignment with `.sdd` (SpecDD) is conflict-free; Layering & Security confirmed. | AI knows *how* to build the system. |
| **3. Tasking** | `/speckit.tasks` | Agent Task Plan | Tasks are small, repo-specific, bounded, and reviewable. | AI has controlled work packages. |
| **4. Implementation** | `/speckit.implement` | Code & Tests | Code strictly fulfills SpecDD baselines (SPDX, English, No-Secrets-on-Disk). | Feature is realized. |
| **5. Testing & Review** | `/speckit.converge` | Delta / Review Report | Code matches Feature Specs and Architecture Rules completely. | Deviations (Drift) eliminated. |
| **6. Release & Learning** | *(Manual / CI)* | Changelog, PR | `CHANGELOG.md` is up to date, CI/CD cross-repo tests are addressed. | Feature is ready to merge. |
