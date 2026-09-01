# Developer Guide: SpecDD & GitHub Spec Kit

Welcome to the `mitm-2` project! We use a combination of **SpecDD** (Architecture Truth) and **GitHub Spec Kit** (Feature Development) to keep the system robust while rapidly building new features.
This guide explains how you, as a developer or AI agent, work with them on a daily basis.

## Why two frameworks?

- **SpecDD (`.sdd` files):** This is the "Constitution" of the project. It defines architectural layers, strict security rules (like encryption), and module boundaries. It rarely changes.
- **GitHub Spec Kit (Markdown features):** This is the "Work Order". When you want to build something new (e.g., an API endpoint), you write a Spec Kit document. It changes quickly and is highly iterative.

## The Daily Workflow in 3 Steps

### 1. Check constraints (Read SpecDD)

Before planning a feature, look at the `.sdd` files in your target folder (e.g., `mitm-2.sdd`). They tell you what you **must** do and what is strictly **forbidden** (e.g., `Must not` or `Forbids`).

### 2. Plan the Feature (Write Spec Kit)

You have two options for planning a feature:

**Option A: Via GitHub Issues (Recommended)**
Go to **Issues -> New Issue** in your GitHub repository and select the **"Feature Specification (Spec Kit)"** template. GitHub automatically populates the text box for you. Fill in the details and use the checkboxes to confirm that your feature does not break the SpecDD rules (Drift Control).

**Option B: As a Markdown file in the project**
Copy the template `.github/spec-kit/feature_template.md` into a new `docs/features/` folder (e.g., `docs/features/feature_kafka_collector.md`). Describe what the feature should do and commit the file as part of your feature branch to Git.

Important: Regardless of the method, you must explicitly address the SpecDD architectural constraints!

### 3. Implementation (By AI or Developer)

The issue or markdown file now serves as a binding work order.

- **AI Agents (e.g., Antigravity or Copilot):** Read the Spec Kit, independently verify the linked SpecDD architecture constraints (`.sdd`), and generate the code accordingly (including SPDX headers and unit tests).
- **Human Developers:** Implement the specified tasks from the Spec Kit step by step in a dedicated Git branch (`feature/...`).

### 4. Quality Assurance (QA) & Code Review

Once the code is complete, a Pull Request (PR) is created that links the GitHub Issue (e.g., via `Closes #42`).
During this phase, the following is verified:

- Does the code meet all "Acceptance Criteria" from the Spec Kit?
- Are the CI/CD pipelines green?
- Has no SpecDD rule been violated (e.g., Envelope Encryption bypassed)?

### 5. Acceptance & Closure

If all reviewers and architecture guardians are satisfied, the Pull Request is merged into the `main` branch.
Thanks to the keyword in the PR, the Spec Kit GitHub Issue is automatically **closed**. The feature is thus successfully developed, anchored in the architecture, and live!

---

## 🛠️ Real-world Examples

### Example 1: Adding a new Kafka Collector

You want `mitm-2` to read data from a Kafka topic.

- **What does SpecDD say?**
  The root spec (`mitm-2.sdd`) says: "All PII data must be immediately encrypted using AES-GCM. The Master Key is fetched via IPC socket."
- **What does your Spec Kit look like?**
  You write a document `feature_kafka_collector.md`. It states: "The collector reads Topic X. For the PII fields `email` and `ssn`, it requests the KEK via IPC and encrypts them."
- **Result:** The feature fits perfectly into the architecture. No one accidentally used a hardcoded key.

### Example 2: A new JSON mapping for the Transformation Layer

You need to map new fields from a CSV upload to the internal JSON format.

- **What does SpecDD say?**
  The spec says: "The transformation layer is stateless and must not write directly to the database."
- **What does your Spec Kit look like?**
  You write `feature_employee_mapping_v2.md`. In it, you describe the mapping logic.
- **Result:** The developer / AI agent builds only pure Go functions without database imports. The architecture remains clean.

---

With this approach, the `mitm-2` system remains maintainable, secure, and architecturally clean, even as many new features are added!
