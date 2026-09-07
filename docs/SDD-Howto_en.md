# Developer Guide: SpecDD & GitHub Spec Kit

Welcome to the `mitm-2` project! We use a combination of **SpecDD** (Architectural source of truth) and **GitHub Spec Kit** (Feature development) to keep the system robust while rapidly building new functions.
This guide explains how you, as a developer or AI agent, should work with them on a daily basis.

## Why Two Frameworks?

- **SpecDD (`.sdd` files):** This is the project's "constitution". It defines architectural layers, strict security requirements (like encryption), and module boundaries. It rarely changes.
- **GitHub Spec Kit (Flow-Forward Spec):** This is the structured "work order". When building something new, we use an iterative, agent-driven process (Plan -> Tasks -> Implement -> Converge) to safely guide the feature through all affected repositories/components.

## The Flow-Forward Workflow (Agentic SDD)

Since our system consists of multiple components with their own GitHub repositories (e.g., `mitm_collector_pg`, `mitm_transformation`), we orchestrate feature development centrally from the root repo. This prevents architectural drift and messy pull requests.

We use Agentic commands (e.g., via Antigravity) for this.

### 1. Check Constraints (Read SpecDD)

Before starting, get a rough overview of the `.sdd` files (e.g., `mitm-2.sdd` in the root). They tell you what you **must** do and what is absolutely **forbidden**.

### 2. Specify & Plan (Design Phase)

Before any code or specs are written, the agent creates a **feature branch** (e.g., `feature/issue-42`) in the affected repo.

**Spec Location:**
- **Cross-layer features** are created centrally as a spec directory in the root repo under `specs/features/<feature-name>/`.
- **Isolated features**, which affect only a single component, must remain strictly in the `specs/` folders of their respective component repos (e.g., `delivery-layer/mitm_delivery/specs/...`).

- **`Run /speckit.specify`**: The agent (after creating the branch) creates the new directory for your feature and helps you define the initial requirements (acceptance criteria).
- **`Run /speckit.plan`**: The agent analyzes the requirements against the `.sdd` files (global and local) and formulates an architectural plan. This defines **how** the affected layers will interact (e.g., Collector provides JSON, Transformation maps it).

### 3. Work Breakdown (Tasks)

- **`Run /speckit.tasks`**: The architectural plan is translated into specific subtasks. **Crucial for this monorepo:** The tasks must explicitly define which code needs to be changed in which sub-component / repo (e.g., "Change interface in `collector-layer/mitm_collector_pg`"). The order is binding (interfaces and contracts first).

### 4. Implementation & Converge (The Iterative Loop)

This step replaces the traditional, error-prone "Big Bang" pull request.

- **`Run /speckit.implement`**: The agent works on exactly the next pending task. It modifies the code in the corresponding component, adds tests, and presents the artifact diff.
- **Review:** As a developer, you review the code diff for this single step.
- **`Run /speckit.converge`**: The agent analyzes the current state of the code against the `specs/` and `.sdd` rules. Is anything missing (e.g., error handling)? If so, it generates new tasks and appends them to the list.
- **Repeat:** Repeat `/speckit.implement` and `/speckit.converge` until all tasks are completed and the feature is fully robust.

### 5. Quality Assurance & Completion

- **Changelog:** In the final task of the implementation phase (or in the final converge loop), the agent ensures that the `CHANGELOG.md` of the affected components is updated.
- **Push & PR:** Once the converge loop is successful, the agent (or you) pushes the feature branch to the respective GitHub repo and opens the corresponding Pull Request (PR) there.
- CI/CD pipelines will run final checks on the cross-component integration tests of the PR.
- If all reviewers are satisfied, the changes are merged into the main branches (`main`).

---

## 🛠️ Practical Examples

### Example 1: Adding a New Kafka Collector

You want `mitm-2` to read and encrypt data from a Kafka topic.

1. **Plan & Specify:** You use `/speckit.specify` for `feature_kafka_collector`. Through `mitm-2.sdd`, `/speckit.plan` immediately recognizes: "PII must be AES-GCM encrypted. Master Key via IPC."
2. **Tasks:** `/speckit.tasks` breaks this down: Task 1 (Build Kafka Reader in `collector-layer/mitm_collector_kafka`), Task 2 (Integrate IPC Encryption in the Collector).
3. **Implement:** The agent incrementally builds the code in the correct repos without accidentally hardcoding keys, since the tasks bind it to the spec.

### Example 2: A New JSON Mapping (Cross-Layer)

You need to process new fields from a CSV upload.

1. **Tasks:** `/speckit.tasks` generates: Task 1 for `collector-layer/mitm_collector_csv-xls` (Read data fields), Task 2 for `transformation-layer/mitm_transformation` (Mapping rules without direct database calls).
2. **Converge:** When the agent adapts the output format during Task 1 implementation, `/speckit.converge` immediately detects that Task 2 needs to be updated accordingly. The architecture remains consistent across repo boundaries.

---

With this Flow-Forward approach, the `mitm-2` system remains maintainable, secure, and architecturally clean even for complex, cross-layer features!
